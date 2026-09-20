using Plots
using Measures

struct SimulationResult
    network::PhsSystem
    system::PhsSystem
    solution::Any
    input::Matrix{Float64}
    signal::Matrix{Float64}
    ids::Vector{String}
end

"""
    plot_result(result::SimulationResult; tmax=nothing, title=nothing)

Plot all state trajectories and the Hamiltonian over time.

The Hamiltonian is plotted as a dotted line labeled `H`.

# Arguments
- `result::SimulationResult`: Simulation result to plot
- `tmax`: Optional maximum time to display
- `title`: Optional plot title (defaults to `result.network.name`)

# Returns
- The `Plots.jl` plot object
"""
# TODO: Remove
function plot_result(result::SimulationResult; tmax::Union{Nothing,Float64}=nothing, title::Union{Nothing,String}=nothing)
    sol = result.solution
    n = state_dimension(result.system)
    args = isnothing(tmax) ? () : (xlim=(0, tmax),)

    # Plot all state variables
    plt = plot(
        sol.t,
        sol[1, :],
        label="x1",
        lw=2,
        xlabel="Time [s]",
        ylabel="State",
        ; args...
    )

    for i in 2:n
        plot!(plt, sol.t, sol[i, :], label="x$i", lw=2)
    end

    energy = compute_energy(sol, result.system)
    plot!(plt, sol.t, energy, label="H", lw=2, ls=:dot, title=isnothing(title) ? result.network.name : title)
    display(plt)
    return plt
end

function plot_result(
    sol,
    system::PhsSystem,
    sim_config::SimConfig;
    title::Union{Nothing,String}=nothing,
    args...
)
    n = length(system.ids)
    plt = plot(
        sol.t,
        sol[1, :],
        label=system.ids[1],
        lw=2,
        xlabel="Time [s]",
        ylabel="State",
        ; args...
    )

    for i in 2:n
        plot!(plt, sol.t, sol[i, :], label=system.ids[i], lw=2)
    end

    # energy = compute_energy(sol, system)
    # plot!(
    #     plt,
    #     sol.t,
    #     energy,
    #     label="H",
    #     lw=2,
    #     ls=:dot,
    #     title=isnothing(title) ? "Simulation Result" : title
    # )

    display(plt)
    return plt
end

function plot_figure54(
    sol,
    system::PhsSystem;
    nominal_voltage::Real=20000.0,
    setpoint_voltage::Union{Nothing,Real}=nothing,
    voltage_setpoints::AbstractDict=Dict(
        "dgu1" => 21000.0,
        "dgu2" => 20998.0,
        "dgu4" => 20996.0,
    ),
    q_voltage_setpoints::AbstractDict=Dict(
        "dgu1" => 1000.0,
        "dgu2" => 998.0,
        "dgu4" => 996.0,
    ),
    controlled_nodes::AbstractVector{<:AbstractString}=["dgu1", "dgu2", "dgu4"],
    title::String="Scenario A: node voltages"
)
    voltage_ids = filter(id -> endswith(id, ".V.d"), system.ids)
    isempty(voltage_ids) && error("System contains no V.d node-voltage states")

    voltage_index(id) = get_index(system, id)
    q_id(id) = replace(id, ".V.d" => ".V.q")
    label(id) = replace(id, ".V.d" => "")
    node_colors = Dict(
        "dgu1" => :dodgerblue,
        "dgu2" => :red,
        "dgu3" => :gold,
        "dgu4" => :purple,
        "dgu5" => :turquoise,
        "dgu6" => :black,
    )
    color_for(id) = get(node_colors, label(id), :grey)
    d_setpoints = Dict(string(node) => Float64(value) for (node, value) in voltage_setpoints)
    q_setpoints = Dict(string(node) => Float64(value) for (node, value) in q_voltage_setpoints)
    if !isnothing(setpoint_voltage)
        for node in controlled_nodes
            d_setpoints[string(node)] = Float64(setpoint_voltage)
        end
    end

    d_plot = plot(title=title, xlabel="Time [s]", ylabel="V.d [kV]", margin=10mm)
    q_plot = plot(title="q-axis node voltages", xlabel="Time [s]", ylabel="V.q [kV]", margin=10mm)
    d_error_plot = plot(title="d-axis deviations", xlabel="Time [s]", ylabel="Deviation [%]", margin=10mm)
    q_error_plot = plot(title="q-axis deviations", xlabel="Time [s]", ylabel="Deviation [%]", margin=10mm)
    d_zoom_plot = plot(title="d-axis deviations (zoom)", xlabel="Time [s]", ylabel="Deviation [%]", ylims=(-0.5, 0.5), margin=10mm)
    q_zoom_plot = plot(title="q-axis deviations (zoom)", xlabel="Time [s]", ylabel="Deviation [%]", ylims=(-0.5, 0.5), margin=10mm)

    for id in voltage_ids
        node = label(id)
        color = color_for(id)
        plot!(d_plot, sol.t, sol[voltage_index(id), :] ./ 1000;
            label=node, color=color, lw=1.5)
        plot!(q_plot, sol.t, sol[voltage_index(q_id(id)), :] ./ 1000;
            label=node, color=color, lw=1.5)
    end

    for node in controlled_nodes
        node = string(node)
        d_id = "$node.V.d"
        q_id_value = "$node.V.q"
        d_index = voltage_index(d_id)
        q_index = voltage_index(q_id_value)
        d_setpoint = get(d_setpoints, node, nominal_voltage)
        q_setpoint = get(q_setpoints, node, 0.0)
        color = get(node_colors, node, :grey)
        d_error = 100 .* (sol[d_index, :] .- d_setpoint) ./ nominal_voltage
        q_error = 100 .* (sol[q_index, :] .- q_setpoint) ./ nominal_voltage
        plot!(d_plot, sol.t, fill(d_setpoint / 1000, length(sol.t)); label="$node ref", color=color, ls=:dash, lw=1)
        plot!(q_plot, sol.t, fill(q_setpoint / 1000, length(sol.t)); label="$node ref", color=color, ls=:dash, lw=1)
        plot!(d_error_plot, sol.t, d_error; label=node, color=color, lw=1.5)
        plot!(q_error_plot, sol.t, q_error; label=node, color=color, lw=1.5)
        plot!(d_zoom_plot, sol.t, d_error; label=node, color=color, lw=1.5)
        plot!(q_zoom_plot, sol.t, q_error; label=node, color=color, lw=1.5)
    end

    return plot(
        d_plot,
        q_plot,
        d_error_plot,
        q_error_plot,
        d_zoom_plot,
        q_zoom_plot;
        layout=(3, 2),
        size=(1400, 1200),
        margin=10mm,
    )
end