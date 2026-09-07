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
    setpoint_voltage::Real=21000.0,
    controlled_nodes::AbstractVector{<:AbstractString}=["dgu1", "dgu2", "dgu4"],
    title::String="Scenario A: node voltages"
)
    voltage_ids = filter(id -> endswith(id, ".V.d"), system.ids)
    isempty(voltage_ids) && error("System contains no V.d node-voltage states")

    voltage_index(id) = get_index(system, id)
    q_id(id) = replace(id, ".V.d" => ".V.q")
    label(id) = replace(id, ".V.d" => "")
    controlled_colors = Dict(node => color for (node, color) in zip(
        controlled_nodes,
        (:dodgerblue, :darkorange, :seagreen),
    ))
    color_for(id) = get(controlled_colors, label(id), :grey)

    d_plot = plot(title=title, xlabel="Time [s]", ylabel="V.d [kV]", margin=10mm)
    q_plot = plot(title="q-axis node voltages", xlabel="Time [s]", ylabel="V.q [kV]", margin=10mm)
    d_error_plot = plot(title="controlled d-axis deviations", xlabel="Time [s]", ylabel="Deviation [%]", margin=10mm)
    q_error_plot = plot(title="controlled q-axis deviations", xlabel="Time [s]", ylabel="Deviation [%]", margin=10mm)

    for id in voltage_ids
        node = label(id)
        color = color_for(id)
        plot!(d_plot, sol.t, sol[voltage_index(id), :] ./ 1000;
            label=node, color=color, lw=1.5)
        plot!(q_plot, sol.t, sol[voltage_index(q_id(id)), :] ./ 1000;
            label=node, color=color, lw=1.5)
    end

    for node in controlled_nodes
        d_id = "$node.V.d"
        q_id_value = "$node.V.q"
        d_index = voltage_index(d_id)
        q_index = voltage_index(q_id_value)
        d_error = 100 .* (sol[d_index, :] .- setpoint_voltage) ./ nominal_voltage
        q_error = 100 .* sol[q_index, :] ./ nominal_voltage
        plot!(d_error_plot, sol.t, d_error; label=node, lw=1.5)
        plot!(q_error_plot, sol.t, q_error; label=node, lw=1.5)
    end

    return plot(d_plot, q_plot, d_error_plot, q_error_plot; layout=(2, 2), size=(1400, 900), margin=10mm)
end