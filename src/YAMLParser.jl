import YAML, JSONSchema, JSON3
using OrderedCollections

"""
    validate_config(config_dict::Dict)

Validate a YAML configuration against the JSON schema.

# Arguments
- `config_dict::Dict`: Configuration dictionary from YAML file

# Throws
- Error if validation fails
"""
function validate_config(config_dict::Dict)
    # Load schema
    schema_path = joinpath(dirname(@__DIR__), "schemas", "network.schema.json")
    schema_dict = JSON3.read(schema_path)
    schema = JSONSchema.Schema(schema_dict)

    # Validate (JSONSchema.jl works with Dict directly)
    result = JSONSchema.validate(schema, config_dict)

    if result !== nothing
        error("Configuration validation failed:", result)
    end
end

"""
    read_config(filepath::String)

Read a YAML configuration file and parse it into typed structs.

The file is validated against the JSON schema before parsing.
"""
function read_config(filepath::String)
    # Load YAML file
    yaml_dict = YAML.load_file(filepath)

    # Validate against schema
    validate_config(yaml_dict)

    # Parse into typed structs
    json_str = JSON3.write(yaml_dict)
    return JSON3.read(json_str, RootConfig)
end

"""
    network_from_config(config::NetworkConfig, ::Type{T}) where {T<:Real}

Create network nodes from validated configuration objects.

# Arguments
- `config::NetworkConfig`: Validated network configuration
- `T::Type`: Element type for matrices

# Returns
- `NetworkGraph{T}`: Network graph metadata ready for assembly
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
        B = zeros(T, n, 1)
        for (_, comp_id) in sys_schema.ports
            comp_idx = comp_map[comp_id]
            B[comp_idx, 1] = 1.0
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

    return NetworkGraph(config.name, nodes, config.connections)
end
