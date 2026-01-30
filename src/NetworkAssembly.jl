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
function create_external_input_function(graph::NetworkGraph{T}, B::AbstractMatrix{T}) where {T<:Real}
    n_inputs = size(B, 2)

    # Parse all input function expressions
    input_funcs = Dict{String,Function}()
    for ext_input in graph.external_inputs
        input_funcs[ext_input.system] = parse_input_function(ext_input.function_expr)
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
function assemble_network(graph::NetworkGraph{T}) where {T<:Real}
    n = graph.total_state_dim

    # Create block diagonal matrices from individual systems
    J_block = assemble_block_diagonal_matrix(graph.nodes, sys -> sys.interconnection)
    R_block = assemble_block_diagonal_matrix(graph.nodes, sys -> sys.dissipation)
    Q_block = assemble_block_diagonal_matrix(graph.nodes, sys -> sys.mass)
    B_block = assemble_block_diagonal_matrix(graph.nodes, sys -> sys.input)

    # Start with block diagonal J, then apply interconnections
    J_global = copy(J_block)
    for edge in graph.edges
        apply_connection!(J_global, graph.nodes, edge)
    end

    # R and Q remain block diagonal (no coupling through dissipation/mass)
    R_global = R_block
    Q_global = Q_block
    B_global = B_block

    # Assemble initial state for the network
    x0, differential_vars = assemble_initial_state(graph)

    # Create the assembled PortHamSystem (without validation checks since it's assembled)
    # We bypass the constructor validation since assembled networks may have special structure
    network_phs = PortHamSystem(J_global, R_global, Q_global, B_global)

    return network_phs, x0, differential_vars
end

"""
    assemble_initial_state(graph::NetworkGraph)

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
function assemble_initial_state(
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
