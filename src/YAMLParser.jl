import YAML, JSONSchema, JSON3
include("NetworkSchema.jl")

"""
    parse_input_function(expr::String)

Parse a string expression into a Julia function.

Supported expressions:
- "constant(value)": Returns constant value
- "sin(freq*t)" or similar: Evaluates Julia expression with variable t
- "step(t0, value)": Step function at time t0

# Arguments
- `expr::String`: Function expression

# Returns
- Function that takes time `t` and returns the value
"""
function parse_input_function(expr::String)
    # Remove whitespace
    expr = strip(expr)

    # Match constant(value) pattern
    const_match = match(r"constant\(([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)\)", expr)
    if !isnothing(const_match)
        value = parse(Float64, const_match.captures[1])
        return t -> value
    end

    # Match step(t0, value) pattern
    step_match = match(r"step\(([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?),\s*([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)\)", expr)
    if !isnothing(step_match)
        t0 = parse(Float64, step_match.captures[1])
        value = parse(Float64, step_match.captures[2])
        return t -> t >= t0 ? value : 0.0
    end

    # Otherwise, try to evaluate as Julia expression with variable 't'
    # This is potentially unsafe - in production, use a safer parser
    try
        return eval(Meta.parse("t -> $expr"))
    catch e
        error("Failed to parse input function expression '$expr': $e")
    end
end

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

function read_config(filepath::String)::RootConfigSchema
    # Load YAML file
    yaml_dict = YAML.load_file(filepath)

    # Validate against schema
    validate_config(yaml_dict)

    # Parse into typed structs
    json_str = JSON3.write(yaml_dict)
    config = JSON3.read(json_str, RootConfigSchema)
    return config
end

"""
    load_network_from_yaml(filepath::String)

Load a port-Hamiltonian network configuration from a YAML file.

# Arguments
- `filepath::String`: Path to YAML configuration file

# Returns
- `NetworkGraph`: Network graph metadata ready for assembly
"""
function load_network_from_yaml(config::RootConfigSchema, ::Type{T}=Float64) where {T<:Real}
    network_config = config.network

    # Parse network name
    name = something(network_config.name, "Unnamed Network")

    # Parse systems and create nodes
    nodes = create_network_nodes_from_schema(network_config.systems, T)

    # Parse connections
    edges = ConnectionEdge{T}[]
    if !isnothing(network_config.connections)
        for conn_schema in network_config.connections
            from_node = conn_schema.from.system
            to_node = conn_schema.to.system

            # Get optional indices
            from_indices = conn_schema.from.indices
            to_indices = conn_schema.to.indices

            # Parse connection type
            type = Symbol(conn_schema.type)

            # Get coupling matrix for skew_symmetric
            coupling_matrix = nothing
            if type == :skew_symmetric && !isnothing(conn_schema.coupling_matrix)
                K = conn_schema.coupling_matrix
                coupling_matrix = Matrix{T}(hcat(K...)')
            end

            edge = ConnectionEdge(
                from_node,
                to_node,
                type;
                from_indices=from_indices,
                to_indices=to_indices,
                coupling_matrix=coupling_matrix,
            )

            push!(edges, edge)
        end
    end

    # Parse external inputs
    external_inputs = ExternalInput[]
    if !isnothing(network_config.external_inputs)
        for input_schema in network_config.external_inputs
            system = input_schema.system
            indices = input_schema.indices
            function_expr = input_schema.func

            ext_input = ExternalInput(system, indices, function_expr)
            push!(external_inputs, ext_input)
        end
    end

    # Create network graph
    graph = NetworkGraph(name, nodes, edges, external_inputs)

    return graph
end

"""
    create_network_nodes_from_schema(systems_schema::Vector{SystemSchema}, ::Type{T})

Create network nodes from validated schema objects.

# Arguments
- `systems_schema::Vector{SystemSchema}`: Vector of system schema objects
- `T::Type`: Element type for matrices

# Returns
- `Dict{String, PHSNode{T}}`: Dictionary of network nodes
"""
function create_network_nodes_from_schema(systems_schema::Vector{SystemSchema}, ::Type{T}) where {T<:Real}
    nodes = Dict{String,PHSNode{T}}()
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
