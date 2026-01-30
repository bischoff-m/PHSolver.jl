using LinearAlgebra


"""
    create_external_input_function(graph::NetworkGraph, B::Matrix)

Create an external input function for the network from YAML configuration.

# Arguments
- `graph::NetworkGraph`: Network graph with external input specifications
- `B::Matrix`: Global input matrix

# Returns
- `Function`: u(t) that returns the input vector at time t
"""
function get_input_function(graph::NetworkGraph{T}, B::AbstractMatrix{T}) where {T<:Real}
    n_inputs = size(B, 2)

    # Parse all input function expressions
    input_funcs = Dict{String,Function}()
    for ext_input in graph.external_inputs
        input_funcs[ext_input.system] = parse_external_function(ext_input.function_expr)
    end

    # Create global input function
    function u_network(t::Real)
        u = zeros(T, n_inputs)

        input_offset = 0
        for (node_id, node) in sort(collect(graph.nodes), by=x -> x[1])
            node_input_dim = input_dimension(node.system)

            # Check if this node has external input
            if haskey(input_funcs, node_id)
                node_u = input_funcs[node_id](t)
                # Handle scalar vs vector input
                if node_u isa Number
                    u[input_offset+1] = node_u
                else
                    u[(input_offset+1):(input_offset+node_input_dim)] .= node_u
                end
            end

            input_offset += node_input_dim
        end

        return u
    end

    return u_network
end


"""
    parse_external_function(expr::String)

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
# NEEDS REFACTORING, AND ALLOWS RCE
function parse_external_function(expr::String)
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
    assemble_network(graph::NetworkGraph)

Assemble a port-Hamiltonian network into a single PortHamSystem.

This function:
1. Creates block diagonal matrices from individual systems
2. Applies interconnections to modify the global J matrix
3. Assembles initial conditions from individual nodes
4. Returns a PortHamSystem representing the entire network

The assembled system satisfies:
    Q * ẋ = (J - R) * x + B * u(t)

where J is skew-symmetric, R is symmetric PSD, and Q is diagonal PSD.

# Arguments
- `graph::NetworkGraph`: Network graph metadata

# Returns
- `PortHamSystem`: Assembled network as a single PHS
- `x0::Vector`: Initial conditions for the network
- `differential_vars::AbstractVector{Bool}`: Which variables are differential (vs algebraic)
"""
function build_network(graph::NetworkGraph{T}) where {T<:Real}
    # Create block diagonal matrices from individual systems
    J = build_block_diagonal(graph.nodes, sys -> sys.interconnection)
    R = build_block_diagonal(graph.nodes, sys -> sys.dissipation)
    Q = build_block_diagonal(graph.nodes, sys -> sys.mass)
    B = build_block_diagonal(graph.nodes, sys -> sys.input)

    # Apply interconnections to J
    for edge in graph.edges
        apply_connection!(J, graph.nodes, edge)
    end

    # Assemble initial state for the network
    x0, differential_vars = build_initial_state(graph)
    # Create the assembled PortHamSystem
    network_phs = PortHamSystem(J, R, Q, B)

    return network_phs, x0, differential_vars
end

"""
    build_initial_state(graph::NetworkGraph)

Compute consistent initial state for the entire network.

This function:
1. Collects initial differential variable values from each node
2. Solves for algebraic variables using the network DAE constraints
3. Returns initial state and differential variable indicators

# Arguments
- `graph::NetworkGraph`: Network graph metadata
# Returns
- `x0::Vector`: Initial state vector
- `differential_vars::AbstractVector{Bool}`: Indicators for differential variables
"""
function build_initial_state(
    graph::NetworkGraph{T},
) where {T<:Real}
    n = graph.total_state_dim

    # Build complete initial state vector
    x0 = zeros(T, n)
    # Identify differential and algebraic variables in global system
    differential_vars = falses(n)

    # Set differential variables from node initial conditions
    for node in values(graph.nodes)
        node_mass = node.system.mass

        # Identify differential variables in this node
        node_diff_vars = [node_mass[i, i] != 0.0 for i in axes(node_mass, 1)]
        diff_idx = 1
        for (i, is_diff) in enumerate(node_diff_vars)
            global_idx = node.state_offset + i
            differential_vars[global_idx] = is_diff
            !is_diff && continue

            if diff_idx <= length(node.initial_state)
                x0[global_idx] = node.initial_state[diff_idx]
            end
            diff_idx += 1
        end
    end

    # Note: Algebraic variables remain zero unless computed elsewhere
    # For now, we initialize algebraic variables to zero
    # A more sophisticated approach would solve the algebraic constraints

    return x0, Vector{Bool}(differential_vars)
end


"""
    build_block_diagonal(
        nodes::Dict{String, PHSNode},
        matrix_getter::Function
    )

Assemble a block diagonal matrix from individual system matrices.

# Arguments
- `nodes`: Dictionary of PHSNode objects
- `matrix_getter`: Function that takes a PortHamSystem and returns the desired matrix
                   (e.g., sys -> sys.interconnection)
"""
function build_block_diagonal(
    nodes::Dict{String,PHSNode{T}},
    matrix_getter::Function,
) where {T<:Real}
    # Sort nodes by state offset to maintain consistent ordering
    sorted_nodes = sort(collect(values(nodes)); by=n -> n.state_offset)

    # Extract matrices in order
    matrices = [sparse(matrix_getter(node.system)) for node in sorted_nodes]

    return blockdiag(matrices...)
end

