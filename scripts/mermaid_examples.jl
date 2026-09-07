include(joinpath(@__DIR__, "mermaid_graph.jl"))

function render_examples()
    examples_dir = normpath(@__DIR__, "..", "examples")
    configs_dir = joinpath(examples_dir, "configs")
    output_dir = joinpath(examples_dir, "output.local", "mermaid")
    mkpath(output_dir)

    local_cli = joinpath(@__DIR__, "..", "node_modules", "@mermaid-js", "mermaid-cli", "src", "cli.js")
    node = Sys.which("node")
    if isfile(local_cli) && !isnothing(node)
        mmdc = `$node $local_cli`
    else
        mmdc_candidates = String[]
        for executable in ("mmdc", "mmdc.cmd")
            path = Sys.which(executable)
            isnothing(path) || push!(mmdc_candidates, path)
        end
        isempty(mmdc_candidates) && error("Could not find mmdc on PATH or a local Mermaid CLI")
        mmdc = `$(first(mmdc_candidates))`
    end

    config_paths = sort(filter(path -> endswith(lowercase(path), ".yaml"), readdir(configs_dir; join=true)))
    for config_path in config_paths
        example = splitext(basename(config_path))[1]
        diagram = mermaid_diagram(PHSolver.read_config(config_path))
        md_path = joinpath(output_dir, "$example.md")
        output_path = joinpath(output_dir, "$example.svg")
        write(md_path, "```mermaid\n$diagram```\n")
        open(`$mmdc -i - -o $output_path`, "w") do input
            write(input, diagram)
        end
        println("Saved Mermaid graph files to $output_dir for $example")
    end

    return nothing
end

render_examples()