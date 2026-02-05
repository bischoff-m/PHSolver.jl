using LinearAlgebra
using OrderedCollections


"""
    build_block_diagonal(
        nodes::OrderedDict{String, PHSNode},
        matrix_getter::Function
    )

Assemble a block diagonal matrix from individual system matrices.

# Arguments
- `nodes`: Ordered dictionary of PHSNode objects
- `matrix_getter`: Function that takes a PortHamSystem and returns the desired matrix
                (e.g., sys -> sys.interaction)
"""
function build_block_diagonal(
    nodes::OrderedDict{String,PHSNode{T}},
    matrix_getter::Function,
) where {T<:Real}
    # Extract matrices in insertion order
    matrices = [sparse(matrix_getter(node.system)) for node in values(nodes)]

    return blockdiag(matrices...)
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
    J = build_block_diagonal(graph.nodes, sys -> sys.interaction)
    R = build_block_diagonal(graph.nodes, sys -> sys.dissipation)
    Q = build_block_diagonal(graph.nodes, sys -> sys.mass)
    B = build_block_diagonal(graph.nodes, sys -> sys.input)

    # Apply interconnections to J
    for edge in graph.edges
        source = graph.nodes[edge.from]
        target = graph.nodes[edge.to]
        apply_connection!(J, edge, source, target)
    end

    # Assemble initial state for the network
    x0, differential_vars = build_initial_state(graph)
    # Create the assembled PortHamSystem
    network_phs = PortHamSystem(J, R, Q, B)

    return network_phs, x0, differential_vars
end
