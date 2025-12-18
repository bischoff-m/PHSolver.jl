#!/usr/bin/env julia
# Network-based simulation example using YAML configuration

include("../src/HamiltonSim.jl")

import .HamiltonSim
using Plots
import Term

config_file = joinpath(@__DIR__, "configs", "sine_oscillator.yaml")
output_dir = joinpath(@__DIR__, "output", "stability_tests")

config = HamiltonSim.read_config(config_file)
config.network.simulation.time_span = [0.0, 10000.0]
config.network.simulation.timestep = 0.1

Term.tprintln("Starting stability tests for different solvers...")

for solver_name in keys(HamiltonSim.supported_solvers)
    solver_name == "default" && continue
    solver_name == "DABDF2" && continue  # Skip DABDF2 due to stability issues

    Term.tprintln("Testing solver: $solver_name")
    config.network.simulation.solver = solver_name

    # Run complete simulation workflow
    result = HamiltonSim.simulate_config(config)
    sol = result.solution
    n = HamiltonSim.state_dimension(result.system)

    # Plot all state variables
    plt = plot(
        sol.t,
        sol[1, :],
        label="x1",
        xlabel="Time [s]",
        ylabel="State",
        lw=2,
        title=result.graph.name,
        xlim=(0, 10000),
    )

    for i in 2:n
        plot!(plt, sol.t, sol[i, :], label="x$i", lw=2)
    end

    energy = HamiltonSim.compute_energy(sol, result.system)
    plot!(plt, sol.t, energy, label="H", lw=2, ls=:dot)

    isdir(output_dir) || mkdir(output_dir)
    savefig(plt, output_dir * "/stability_$(solver_name).png")
    Term.tprintln()
end

Term.tprintln("Stability tests completed. Plots saved in $output_dir.")