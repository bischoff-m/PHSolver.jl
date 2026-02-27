include("../src/PHSolver.jl")

import .PHSolver
using Plots
import Term

config_file = joinpath(@__DIR__, "configs", "sine_oscillator.yaml")
output_dir = joinpath(@__DIR__, "output.local", "stability_tests")

tmax = 10000.0
config = PHSolver.read_config(config_file)
config.simulation.time_span = [0.0, tmax]

Term.tprintln("Starting stability tests for different solvers...")

for solver_name in keys(PHSolver.supported_solvers)
    solver_name == "default" && continue
    solver_name == "DABDF2" && continue  # Skip DABDF2 due to stability issues

    Term.tprintln("Testing solver: $solver_name")
    config.simulation.solver = solver_name

    # Run complete simulation workflow
    result = PHSolver.simulate_config(config)
    plt = PHSolver.plot_result(result, tmax=tmax, title="Stability Test - Solver: $solver_name")

    isdir(output_dir) || mkdir(output_dir)
    savefig(plt, output_dir * "/stability_$(solver_name).png")
    Term.tprintln()
end

Term.tprintln("Stability tests completed. Plots saved in $output_dir.")