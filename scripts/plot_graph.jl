
include("../src/PHSolver.jl")

using ShowGraphviz

function plot_network(example::String)
    config = PHSolver.read_config("examples/configs/$example.yaml")
    dot = PHSolver.graphviz_network(config)
    display(ShowGraphviz.DOT(dot))

    examples_dir = joinpath(@__DIR__, "../examples")
    output_dir = joinpath(examples_dir, "output.local")
    isdir(output_dir) || mkdir(output_dir)

    svg = sprint(show, "image/svg+xml", ShowGraphviz.DOT(dot))
    out_path = joinpath(output_dir, "$example.svg")
    write(out_path, svg)
    println("Saved network graph to ", out_path)
end

plot_network("DGU")
nothing