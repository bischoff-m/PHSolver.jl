include(joinpath(@__DIR__, "..", "src", "PHSolver.jl"))

function mermaid_escape(value)
    text = string(value)
    return replace(text, "\\" => "\\\\", "\"" => "&quot;", "|" => "&#124;", "\n" => "<br/>")
end

function mermaid_id(path::Vector{String})
    return "n_" * join(replace.(path, r"[^A-Za-z0-9_]" => "_"), "__")
end

function mermaid_diagram(config::PHSolver.SystemConfig; direction::String="LR")
    lines = String["---", "title: $(mermaid_escape(config.id))", "---", "flowchart $direction"]
    node_paths = Dict{String,Vector{String}}()
    system_paths = Set{String}()

    function register_nodes(system::PHSolver.SystemConfig, path::Vector{String})
        key = join(path, ".")
        node_paths[key] = path
        push!(system_paths, key)
        for child in system.systems
            child_path = [path; child.id]
            node_paths[join(child_path, ".")] = child_path
            child isa PHSolver.SystemConfig && register_nodes(child, child_path)
        end
    end

    register_nodes(config, String[])

    function endpoint_path(system_path::Vector{String}, endpoint::String)
        parts = split(endpoint, ".")
        candidates = Vector{String}[]
        isempty(system_path) || push!(candidates, [system_path; parts])
        push!(candidates, String.(parts))
        for candidate in candidates
            key = join(candidate, ".")
            haskey(node_paths, key) && return node_paths[key]
        end
        return [system_path; parts]
    end

    endpoint_node(path::Vector{String}) = mermaid_id(path)

    function render_system(system::PHSolver.SystemConfig, path::Vector{String}, indent::String; include_connections::Bool=true, wrap::Bool=true)
        system_id = mermaid_id(path)
        system_label = isempty(path) ? system.id : path[end]
        println_lines = String[]
        wrap && push!(println_lines, "$indent subgraph $system_id[\"$(mermaid_escape(system_label))\"]")
        node_indent = wrap ? indent * "  " : indent

        for child in system.systems
            child_path = [path; child.id]
            if child isa PHSolver.SystemConfig
                append!(println_lines, render_system(child, child_path, node_indent * "  "))
            else
                node = mermaid_id(child_path)
                label = "$(child.id)<br/>x0=$(mermaid_escape(child.x0))"
                push!(println_lines, "$node_indent $node[\"$(mermaid_escape(label))\"]")
            end
        end

        if include_connections
            for connection in system.connections
                from_path = endpoint_path(path, connection.from)
                to_path = endpoint_path(path, connection.to)
                from_node = endpoint_node(from_path)
                to_node = endpoint_node(to_path)
                weight = mermaid_escape(connection.weight)
                push!(println_lines, "$node_indent $from_node -->|\"$weight\"| $to_node")
            end
        end

        wrap && push!(println_lines, "$indent end")
        return println_lines
    end

    append!(lines, render_system(config, String[], ""; include_connections=false, wrap=false))
    for connection in config.connections
        from_path = endpoint_path(String[], connection.from)
        to_path = endpoint_path(String[], connection.to)
        from_node = endpoint_node(from_path)
        to_node = endpoint_node(to_path)
        weight = mermaid_escape(connection.weight)
        push!(lines, "$from_node -->|\"$weight\"| $to_node")
    end
    return join(lines, "\n") * "\n"
end

function render_mermaid_config(config_path::String; output_path::Union{Nothing,String}=nothing)
    diagram = mermaid_diagram(PHSolver.read_config(config_path))
    if isnothing(output_path)
        print(diagram)
    else
        write(output_path, diagram)
        println("Saved Mermaid diagram to $output_path")
    end
    return diagram
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) in (1, 2) || error("Usage: julia scripts/mermaid_graph.jl CONFIG.yaml [OUTPUT.mmd]")
    render_mermaid_config(ARGS[1]; output_path=length(ARGS) == 2 ? ARGS[2] : nothing)
end
