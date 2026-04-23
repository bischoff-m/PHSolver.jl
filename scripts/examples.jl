include("../src/PHSolver.jl")

using Plots
import Term

examples_dir = normpath(@__DIR__, "../examples")
output_dir = joinpath(examples_dir, "output.local")
isdir(output_dir) || mkdir(output_dir)

function run_example(example::String)
    config_file = joinpath(examples_dir, "configs", "$(example).yaml")
    Term.tprintln("Running example:", Term.highlight(example, :emphasis))

    sim = PHSolver.init_simulation(config_file; verbose=false)

    # plt = PHSolver.plot_result(result, title=result.network.name)

    # image_path = joinpath(output_dir, "$(example).png")
    # savefig(plt, image_path)
    # Term.tprintln("Saved plot to {cyan}$(image_path){/cyan}")
    # Term.tprintln()
end

# run_example("testing")
# run_example("dc_power_network")
run_example("dc_power_network_controlled")
# run_example("DGU")
nothing
