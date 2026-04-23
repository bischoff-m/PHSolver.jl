using Plots

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
        args...
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
        args...
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