include("../src/HamiltonSim.jl")

import .HamiltonSim
using Plots
import Term

config_file = joinpath(@__DIR__, "configs", "sine_oscillator.yaml")
output_dir = joinpath(@__DIR__, "output.local", "stability_tests")

tmax = 10000.0
config = HamiltonSim.read_config(config_file)
config.simulation.time_span = [0.0, tmax]

Term.tprintln("Starting stability tests for different solvers...")

for solver_name in keys(HamiltonSim.supported_solvers)
    solver_name == "default" && continue
    solver_name == "DABDF2" && continue  # Skip DABDF2 due to stability issues

    Term.tprintln("Testing solver: $solver_name")
    config.simulation.solver = solver_name

    # Run complete simulation workflow
    result = HamiltonSim.simulate_config(config)
    plt = HamiltonSim.plot_result(result, tmax=tmax, title="Stability Test - Solver: $solver_name")

    isdir(output_dir) || mkdir(output_dir)
    savefig(plt, output_dir * "/stability_$(solver_name).png")
    Term.tprintln()
end

Term.tprintln("Stability tests completed. Plots saved in $output_dir.")