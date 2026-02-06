import YAML, JSONSchema, JSON3
using OrderedCollections

"""
    validate_config(config_dict::Dict)

Validate YAML configuration against JSON schema.

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

function read_config(filepath::String)::RootConfig
    # Load YAML file
    yaml_dict = YAML.load_file(filepath)

    # Validate against schema
    validate_config(yaml_dict)

    # Parse into typed structs
    json_str = JSON3.write(yaml_dict)
    return JSON3.read(json_str, RootConfig)
end

"""
    load_network_from_yaml(filepath::String)

Load a port-Hamiltonian network configuration from a YAML file.

# Arguments
- `filepath::String`: Path to YAML configuration file

# Returns
- `NetworkGraph`: Network graph metadata ready for assembly
"""
function load_network(config::NetworkConfig, ::Type{T}=Float64) where {T<:Real}
    # Parse network name
    name = something(config.name, "Unnamed Network")

    # Parse systems and create nodes
    nodes = create_network_nodes_from_schema(config.systems, T)

    edges = if !isnothing(config.connections)
        config.connections
    else
        Connection[]
    end

    # Parse external inputs
    external_inputs = ExternalInput[]
    if !isnothing(config.external_inputs)
        for input_schema in config.external_inputs
            system = input_schema.system
            indices = input_schema.indices
            function_expr = input_schema.func

            ext_input = ExternalInput(system, indices, function_expr)
            push!(external_inputs, ext_input)
        end
    end

    # Create network graph
    return NetworkGraph(name, nodes, edges, external_inputs)
end

"""
    create_network_nodes_from_schema(systems_schema::AbstractVector{SystemSchema}, ::Type{T})

Create network nodes from validated schema objects.

# Arguments
- `systems_schema::AbstractVector{SystemSchema}`: Vector of system schema objects
- `T::Type`: Element type for matrices

# Returns
- `OrderedDict{String, PHSNode{T}}`: Dictionary of network nodes
"""
function create_network_nodes_from_schema(systems_schema::AbstractVector{System}, ::Type{T}) where {T<:Real}
    nodes = OrderedDict{String,PHSNode{T}}()
    offset = 0

    for sys_schema in systems_schema
        # Extract matrices
        matrices = sys_schema.matrices
        J = Matrix{T}(hcat(matrices.J...)')
        R = Matrix{T}(hcat(matrices.R...)')
        Q = Matrix{T}(hcat(matrices.Q...)')

        # Extract optional B matrix
        B = if !isnothing(matrices.B)
            Matrix{T}(hcat(matrices.B...)')
        else
            zeros(T, size(J, 1), 0)
        end

        # Create PHS
        system = PortHamSystem(J, R, Q, B)

        # Get initial state
        initial_state = if !isnothing(sys_schema.initial_state)
            Vector{T}(sys_schema.initial_state)
        else
            zeros(T, state_dimension(system))
        end

        # Create node
        node = PHSNode(sys_schema.id, system, initial_state, offset)
        nodes[sys_schema.id] = node

        # Update offset
        offset += node.state_dim
    end

    return nodes
end
