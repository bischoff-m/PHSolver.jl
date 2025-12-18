#!/usr/bin/env julia
# Network-based simulation example using YAML configuration

include("../src/HamiltonSim.jl")

import .HamiltonSim
using Plots

function run_example(example::String)
    config_file = joinpath(@__DIR__, "configs", "$(example).yaml")
    output_dir = joinpath(@__DIR__, "output")

    # Run complete simulation workflow
    result = HamiltonSim.simulate_file(config_file)
    sol = result.solution

    # Plot all state variables
    n = HamiltonSim.state_dimension(result.system)
    plt = plot(
        sol.t,
        sol[1, :],
        label="x1",
        xlabel="Time [s]",
        ylabel="State",
        lw=2,
        title=result.graph.name,
    )

    for i in 2:n
        plot!(plt, sol.t, sol[i, :], label="x$i", lw=2)
    end

    energy = HamiltonSim.compute_energy(sol, result.system)
    plot!(plt, sol.t, energy, label="H", lw=2, ls=:dot)

    isdir(output_dir) || mkdir(output_dir)
    savefig(plt, output_dir * "/$(example).png")
end

# run_example("pendulum")
# run_example("dc_power_network")
# run_example("coupled_masses")
run_example("sine_oscillator")
