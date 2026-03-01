using OrderedCollections

"""
    network_from_config(config::NetworkConfig, ::Type{T}) where {T<:Real}

Create network nodes from validated configuration objects.

# Arguments
- `config::NetworkConfig`: Validated network configuration
- `T::Type`: Element type for matrices

# Returns
- `Network{T}`: Network metadata ready for assembly
"""
function network_from_config(config::NetworkConfig, ::Type{T}) where {T<:Real}
    nodes = OrderedDict{String,PHSNode{T}}()
    offset = 0

    for sys_schema in config.systems
        n = length(sys_schema.components)
        comp_map = Dict(c.id => i for (i, c) in enumerate(sys_schema.components))

        # Build interconnection matrix
        J = zeros(T, n, n)
        for conn in sys_schema.connections
            from_idx = comp_map[conn.from]
            to_idx = comp_map[conn.to]
            J[from_idx, to_idx] += conn.weight
            J[to_idx, from_idx] -= conn.weight
        end

        # Build input matrix
        B = zeros(T, n, n)
        for (_, comp_id) in sys_schema.ports
            comp_idx = comp_map[comp_id]
            B[comp_idx, comp_idx] = 1.0
        end

        R = Diagonal([c.dissipation for c in sys_schema.components])
        Q = Diagonal([c.mass for c in sys_schema.components])
        initial_state = [c.x0 for c in sys_schema.components]

        system = PortHamSystem(J, R, Q, B)
        ports = Dict(port => comp_map[comp_id] for (port, comp_id) in sys_schema.ports)
        node = PHSNode(sys_schema.id, system, initial_state, ports, offset)
        nodes[sys_schema.id] = node
        offset += node.state_dim
    end

    return Network(config.name, nodes, config.connections)
end
