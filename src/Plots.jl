using Plots

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
    plot!(plt, sol.t, energy, label="H", lw=2, ls=:dot, title=isnothing(title) ? result.graph.name : title)
    display(plt)
    return plt
end