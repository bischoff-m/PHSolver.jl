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

    system = result.system
    sol = result.solution
    graph = result.graph

    # Plot all state variables
    n = HamiltonSim.state_dimension(system)
    plt = plot(
        sol.t,
        sol[1, :],
        label="x₁",
        xlabel="Time [s]",
        ylabel="State",
        lw=2,
        title=graph.name,
    )

    for i in 2:n
        plot!(plt, sol.t, sol[i, :], label="x$i", lw=2)
    end

    isdir(output_dir) || mkdir(output_dir)
    savefig(plt, output_dir * "/$(example)_states.png")

    # Plot network energy
    energy = HamiltonSim.compute_energy(sol, system)
    plt_energy = plot(
        sol.t,
        energy,
        label="Total Energy",
        xlabel="Time [s]",
        ylabel="Energy [J]",
        lw=2,
        title="$(graph.name) - Energy",
    )

    savefig(plt_energy, output_dir * "/$(example)_energy.png")
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_example("dc_power_network")
    run_example("coupled_masses")
end