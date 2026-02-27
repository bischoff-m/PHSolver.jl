include("../src/PHSolver.jl")

import .PHSolver
using Plots
import Term

examples_dir = normpath(@__DIR__, "../examples")
output_dir = joinpath(examples_dir, "output.local")
isdir(output_dir) || mkdir(output_dir)

function run_example(example::String)
    config_file = joinpath(examples_dir, "configs", "$(example).yaml")
    Term.tprintln("Running example: {cyan}$(example){/cyan}")

    # Run complete simulation workflow
    result = PHSolver.simulate_file(config_file)
    plt = PHSolver.plot_result(result, title=result.network.name)

    image_path = joinpath(output_dir, "$(example).png")
    savefig(plt, image_path)
    Term.tprintln("Saved plot to {cyan}$(image_path){/cyan}")
    Term.tprintln()
end

run_example("pendulum")
run_example("coupled_masses")
run_example("sine_oscillator")
run_example("dc_power_network")
