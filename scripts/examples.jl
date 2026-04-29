include("../src/PHSolver.jl")

using Plots
import Term

examples_dir = normpath(@__DIR__, "../examples")
output_dir = joinpath(examples_dir, "output.local")
isdir(output_dir) || mkdir(output_dir)

function run_example(example::String)
    config_file = joinpath(examples_dir, "configs", "$(example).yaml")
    Term.tprintln("Running example:", Term.highlight(example, :emphasis))

    PHSolver.init_simulation(config_file; verbose=false)
end

run_example("testing")
# run_example("dc_power_network")
# run_example("dc_power_network_controlled")
# run_example("dc_power_network_nonlinear_resistance")
# run_example("DGU")
nothing
