"""
	graphviz_network(config::RootConfig; rankdir="LR")

Generate a Graphviz DOT representation of a network configuration.

Each system is rendered as a cluster containing component nodes. Components
are boxes labeled with their id and values for R (dissipation), E (mass), and x0.
Connections are shown as directed edges labeled with the connection weight.

# Arguments
- `config::RootConfig`: Parsed YAML configuration
- `rankdir`: Graphviz rank direction (default "LR")

# Returns
- `String`: Graphviz DOT graph
"""
function graphviz_network(config::SystemConfig; rankdir::String="LR")
    io = IOBuffer()
    systems = Dict{String,SystemConfig}()
    components = Dict{String,Component}()

    function collect_system(system::SystemConfig, path::Vector{String})
        systems[join(path, ".")] = system
        for child in system.systems
            child_path = [path; child.id]
            if child isa SystemConfig
                collect_system(child, child_path)
            else
                components[join(child_path, ".")] = child
            end
        end
    end

    collect_system(config, [config.id])

    function endpoint_path(system_path::Vector{String}, endpoint::String)
        parts = split(endpoint, ".")
        for start in length(system_path):-1:1
            candidate = join([system_path[1:start]; parts], ".")
            haskey(components, candidate) && return candidate
            haskey(systems, candidate) && return candidate
        end
        return nothing
    end

    function resolve_endpoint(system_path::Vector{String}, endpoint::String)
        path = endpoint_path(system_path, endpoint)
        isnothing(path) && return nothing

        parts = split(path, ".")
        for count in length(parts):-1:1
            system = get(systems, join(parts[1:count], "."), nothing)
            isnothing(system) && continue
            remainder = count == length(parts) ? "" : join(parts[(count+1):end], ".")
            target = get(system.ports, remainder, nothing)
            isnothing(target) || return resolve_endpoint(parts[1:count], target)
        end

        return path
    end

    node_id(path::AbstractString) = gv_id(replace(path, "." => "::"))
    reverse_weight(value) = value isa Number ? -value : "-(" * string(value) * ")"

    println(io, "digraph ", gv_id(config.id), " {")
    println(io, "  graph [compound=true, rankdir=", rankdir, "];")

    function render_system(system::SystemConfig, path::Vector{String}, indent::String)
        path_key = join(path, ".")
        cluster_id = "cluster_" * replace(path_key, "." => "__")
        println(io, indent, "subgraph ", gv_id(cluster_id), " {")
        println(io, indent, "  label=", gv_label("System: " * path_key), ";")
        println(io, indent, "  style=\"rounded\";")

        for child in system.systems
            child_path = [path; child.id]
            if child isa SystemConfig
                render_system(child, child_path, indent * "  ")
            else
                component_path = join(child_path, ".")
                label = string(child.id, "\nR=", child.dissipation, "\nQ=", child.mass, "\nx0=", child.x0)
                println(io, indent, "  ", node_id(component_path), " [shape=box, label=", gv_label(label), "];")
            end
        end

        println(io, indent, "}")
    end

    render_system(config, [config.id], "  ")

    for (system_path, system) in systems
        path = String.(split(system_path, "."))
        for conn in system.connections
            from_path = resolve_endpoint(path, conn.from)
            to_path = resolve_endpoint(path, conn.to)
            if isnothing(from_path) || isnothing(to_path)
                continue
            end

            println(io, "  ", node_id(from_path), " -> ", node_id(to_path), " [label=", gv_label(string(conn.weight)), "];")
            if system_path != config.id
                println(io, "  ", node_id(to_path), " -> ", node_id(from_path), " [label=", gv_label(string(reverse_weight(conn.weight))), "];")
            end
        end
    end

    println(io, "}")
    return String(take!(io))
end

function gv_escape(value::AbstractString)
    return replace(value, "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n")
end

function gv_id(value::AbstractString)
    return "\"" * gv_escape(value) * "\""
end

function gv_label(value::AbstractString)
    return gv_id(value)
end
