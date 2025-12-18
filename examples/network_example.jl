include("../src/HamiltonSim.jl")

import .HamiltonSim
using Plots

function run_example(example::String)
    config_file = joinpath(@__DIR__, "configs", "$(example).yaml")
    output_dir = joinpath(@__DIR__, "output")

    # Run complete simulation workflow
    result = HamiltonSim.simulate_file(config_file)
    plt = HamiltonSim.plot_simulation_result(result)

    isdir(output_dir) || mkdir(output_dir)
    savefig(plt, output_dir * "/$(example).png")
end

# run_example("pendulum")
# run_example("dc_power_network")
# run_example("coupled_masses")
run_example("sine_oscillator")
