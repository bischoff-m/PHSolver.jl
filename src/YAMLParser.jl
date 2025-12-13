using YAML

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
    load_network_from_yaml(filepath::String)

Load a port-Hamiltonian network configuration from a YAML file.

# Arguments
- `filepath::String`: Path to YAML configuration file

# Returns
- `NetworkGraph`: Network graph metadata ready for assembly
"""
function load_network_from_yaml(filepath::String, ::Type{T}=Float64) where {T<:Real}
    # Load YAML file
    config = YAML.load_file(filepath)

    if !haskey(config, "network")
        error("YAML file must contain 'network' key at root level")
    end

    network_config = config["network"]

    # Parse network name
    name = get(network_config, "name", "Unnamed Network")

    # Parse systems and create nodes
    if !haskey(network_config, "systems")
        error("Network configuration must contain 'systems' key")
    end

    nodes = create_network_nodes(network_config["systems"], T)

    # Parse connections
    edges = ConnectionEdge{T}[]
    if haskey(network_config, "connections")
        for conn_config in network_config["connections"]
            from_node = conn_config["from"]["system"]
            to_node = conn_config["to"]["system"]

            # Get optional indices
            from_indices = get(conn_config["from"], "indices", nothing)
            to_indices = get(conn_config["to"], "indices", nothing)

            # Parse connection type
            type_str = conn_config["type"]
            type = Symbol(type_str)

            # Get coupling matrix for skew_symmetric
            coupling_matrix = nothing
            if type == :skew_symmetric && haskey(conn_config, "coupling_matrix")
                K = conn_config["coupling_matrix"]
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
    if haskey(network_config, "external_inputs")
        for input_config in network_config["external_inputs"]
            system = input_config["system"]
            indices = get(input_config, "indices", nothing)
            function_expr = input_config["function"]

            ext_input = ExternalInput(system, indices, function_expr)
            push!(external_inputs, ext_input)
        end
    end

    # Create network graph
    graph = NetworkGraph(name, nodes, edges, external_inputs)

    return graph
end

"""
    get_simulation_config(filepath::String)

Extract simulation configuration from YAML file.

# Returns
- `Dict`: Simulation configuration containing time_span, solver, timestep, etc.
"""
function get_simulation_config(filepath::String)
    config = YAML.load_file(filepath)

    if !haskey(config, "network")
        error("YAML file must contain 'network' key at root level")
    end

    network_config = config["network"]

    # Get simulation config with defaults
    sim_config = get(network_config, "simulation", Dict())

    # Set defaults
    time_span = get(sim_config, "time_span", [0.0, 1.0])
    solver = get(sim_config, "solver", "IDA")
    timestep = get(sim_config, "timestep", nothing)

    return Dict(
        "time_span" => Tuple(time_span),
        "solver" => solver,
        "timestep" => timestep,
    )
end

