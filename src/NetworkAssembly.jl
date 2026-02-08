using LinearAlgebra
using OrderedCollections
using SparseArrays


"""
    build_block_diagonal(
        nodes::OrderedDict{String, PHSNode},
        matrix_getter::Function
    )

Assemble a sparse block-diagonal matrix from the per-node matrices.

# Arguments
- `nodes`: Ordered dictionary of `PHSNode` objects
- `matrix_getter`: Function that takes a `PortHamSystem` and returns the
  desired matrix (e.g., `sys -> sys.interaction`)

# Returns
- A sparse block-diagonal matrix containing the specified matrices from each
  node, in the order they were defined in the configuration
"""
function build_block_diagonal(
    nodes::OrderedDict{String,PHSNode{T}},
    matrix_getter::Function,
) where {T<:Real}
    # Create block diagonal matrix from node matrices
    matrices = [sparse(matrix_getter(node.system)) for node in values(nodes)]
    return blockdiag(matrices...)
end


"""
    build_initial_state(graph::NetworkGraph)

Build the initial state vector and differential-variable mask.

Differential variables are inferred from the diagonal of each node's mass
matrix (nonzero entries are treated as differential). Algebraic variables are
initialized to zero.

# Arguments
- `graph::NetworkGraph`: Network graph metadata

# Returns
- `x0::Vector`: Initial state vector
- `differential_vars::AbstractVector{Bool}`: `true` for differential variables
"""
function build_initial_state(graph::NetworkGraph{T}) where {T<:Real}
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

    # TODO: Algebraic variables remain zero unless computed elsewhere
    # For now, we initialize algebraic variables to zero
    # A more sophisticated approach would solve the algebraic constraints

    return x0, Vector{Bool}(differential_vars)
end


"""
    build_network(graph::NetworkGraph)

Assemble a port-Hamiltonian network into a single system with dynamics.

Steps:
1. Build block-diagonal `J`, `R`, `Q`, and `B` from per-node matrices.
2. Apply interconnections to the interconnection matrix `J`.
3. Assemble initial conditions and differential-variable indicators.

The assembled system satisfies \$Q \\dot{x} = (J - R) x + B u(t)\$, where
`J` is skew-symmetric, `R` is symmetric PSD, and `Q` is diagonal PSD.

# Arguments
- `graph::NetworkGraph`: Network graph metadata

# Returns
- `SimDynamics`: Assembled network dynamics with initial conditions
"""
function build_network(graph::NetworkGraph{T}) where {T<:Real}
    # Create block diagonal matrices from individual systems
    J = build_block_diagonal(graph.nodes, sys -> sys.interaction)
    R = build_block_diagonal(graph.nodes, sys -> sys.dissipation)
    Q = build_block_diagonal(graph.nodes, sys -> sys.mass)
    B = build_block_diagonal(graph.nodes, sys -> sys.input)

    # Apply interconnections to J
    for connection in graph.connections
        source = graph.nodes[connection.from.system]
        target = graph.nodes[connection.to.system]
        apply_connection!(J, connection, source, target)
    end

    # Create the assembled PortHamSystem
    network_phs = PortHamSystem(J, R, Q, B)
    x0, differential_vars = build_initial_state(graph)
    input_func = build_input_func(graph, B)

    return SimDynamics(network_phs, x0, differential_vars, input_func)
end
