"""
	graphviz_network(config::RootConfig; rankdir="LR")

Generate a Graphviz DOT representation of a network configuration.

Each system is rendered as a cluster containing component nodes. Components
are boxes labeled with their id and values for R (dissipation), Q (mass), and x0.
Connections are shown as directed edges labeled with the connection weight.

# Arguments
- `config::RootConfig`: Parsed YAML configuration
- `rankdir`: Graphviz rank direction (default "LR")

# Returns
- `String`: Graphviz DOT graph
"""
function graphviz_network(config::RootConfig; rankdir::String="LR")
    network = config.network
    io = IOBuffer()

    systems_by_id = Dict{String,System}()
    component_ids_by_system = Dict{String,Set{String}}()
    for sys in network.systems
        systems_by_id[sys.id] = sys
        component_ids_by_system[sys.id] = Set(comp.id for comp in sys.components)
    end

    extra_ports = Dict{String,Set{String}}()
    for conn in network.connections
        for (sys_id, port_name) in ((conn.from.system, conn.from.port), (conn.to.system, conn.to.port))
            sys = get(systems_by_id, sys_id, nothing)
            if sys === nothing
                continue
            end
            comp_id = get(sys.ports, port_name, nothing)
            if comp_id === nothing || !(comp_id in component_ids_by_system[sys_id])
                if !haskey(extra_ports, sys_id)
                    extra_ports[sys_id] = Set{String}()
                end
                push!(extra_ports[sys_id], port_name)
            end
        end
    end

    println(io, "digraph ", gv_id(network.name), " {")
    println(io, "  graph [compound=true, rankdir=", rankdir, "];")

    for sys in network.systems
        cluster_id = "cluster_" * sys.id
        println(io, "  subgraph ", gv_id(cluster_id), " {")
        println(io, "    label=", gv_label("System: " * sys.id), ";")
        println(io, "    style=\"rounded\";")

        for comp in sys.components
            node_id = gv_id(component_node_key(sys.id, comp.id))
            label = string(comp.id, "\nR=", comp.dissipation, "\nQ=", comp.mass, "\nx0=", comp.x0)
            println(io, "    ", node_id, " [shape=box, label=", gv_label(label), "];")
        end

        if haskey(extra_ports, sys.id)
            for port_name in sort(collect(extra_ports[sys.id]))
                node_id = gv_id(port_node_key(sys.id, port_name))
                label = "port: " * port_name
                println(io, "    ", node_id, " [shape=ellipse, label=", gv_label(label), "];")
            end
        end

        println(io, "  }")
    end

    for sys in network.systems
        for conn in sys.connections
            from_id = gv_id(component_node_key(sys.id, conn.from))
            to_id = gv_id(component_node_key(sys.id, conn.to))
            println(io, "  ", from_id, " -> ", to_id, " [label=", gv_label(string(conn.weight)), "];")
            println(io, "  ", to_id, " -> ", from_id, " [label=", gv_label(string(-conn.weight)), "];")
        end
    end

    for conn in network.connections
        from_sys = get(systems_by_id, conn.from.system, nothing)
        to_sys = get(systems_by_id, conn.to.system, nothing)
        if from_sys === nothing || to_sys === nothing
            continue
        end

        from_id = resolve_port_node_id(from_sys, conn.from.port, component_ids_by_system, extra_ports)
        to_id = resolve_port_node_id(to_sys, conn.to.port, component_ids_by_system, extra_ports)

        attrs = String[]
        push!(attrs, "label=" * gv_label(string(conn.weight)))
        push!(attrs, "ltail=" * gv_id("cluster_" * from_sys.id))
        push!(attrs, "lhead=" * gv_id("cluster_" * to_sys.id))

        println(io, "  ", from_id, " -> ", to_id, " [", join(attrs, ", "), "];")
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

function component_node_key(system_id::AbstractString, component_id::AbstractString)
    return string(system_id, "::", component_id)
end

function port_node_key(system_id::AbstractString, port_name::AbstractString)
    return string(system_id, "::port::", port_name)
end

function resolve_port_node_id(
    system::System,
    port_name::AbstractString,
    component_ids_by_system::Dict{String,Set{String}},
    extra_ports::Dict{String,Set{String}}
)
    comp_id = get(system.ports, String(port_name), nothing)
    if comp_id !== nothing && comp_id in component_ids_by_system[system.id]
        return gv_id(component_node_key(system.id, comp_id))
    end

    if haskey(extra_ports, system.id) && (String(port_name) in extra_ports[system.id])
        return gv_id(port_node_key(system.id, String(port_name)))
    end

    return gv_id(port_node_key(system.id, String(port_name)))
end
