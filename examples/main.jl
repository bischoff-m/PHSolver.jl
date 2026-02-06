include("../src/PHSim.jl")

import .PHSim
using Plots
import Term

output_dir = joinpath(@__DIR__, "output.local")
isdir(output_dir) || mkdir(output_dir)

function run_example(example::String)
    Term.tprintln("Running example: {cyan}$(example){/cyan}")
    config_file = joinpath(@__DIR__, "configs", "$(example).yaml")

    # Run complete simulation workflow
    result = PHSim.simulate_file(config_file)
    plt = PHSim.plot_result(result, title=result.graph.name)

    savefig(plt, output_dir * "/$(example).png")
    Term.tprintln()
end

# run_example("pendulum")
# run_example("coupled_masses")
# run_example("sine_oscillator")
run_example("dc_power_network")
