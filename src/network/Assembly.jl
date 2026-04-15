using LinearAlgebra
using OrderedCollections
using SparseArrays


"""
    build_block_diagonal(
        nodes::OrderedDict{String, PhsNode},
        matrix_getter::Function
    )

Assemble a sparse block-diagonal matrix from the per-node matrices.

# Arguments
- `nodes`: Ordered dictionary of `PhsNode` objects
- `matrix_getter`: Function that takes a `PortHamSystem` and returns the
  desired matrix (e.g., `sys -> sys.interaction`)

# Returns
- A sparse block-diagonal matrix containing the specified matrices from each
  node, in the order they were defined in the configuration
"""
function build_block_diagonal(
    nodes::OrderedDict{String,PhsNodeOld{T}},
    matrix_getter::Function,
) where {T<:Real}
    # Create block diagonal matrix from node matrices
    matrices = [sparse(matrix_getter(node.system)) for node in values(nodes)]
    return blockdiag(matrices...)
end


"""
    build_initial_state(network::Network{T}) where {T<:Real}

Build the initial state vector. This concatenates the initial states of each
node at the correct offsets to form the full initial state vector for the
assembled system.

# Arguments
- `network::Network{T}`: Network metadata

# Returns
- `x0::Vector`: Initial state vector
"""
function build_initial_state(network) where {T<:Real}
    x0 = zeros(T, network.total_state_dim)

    # Fill in initial states for each node at the correct offsets
    for node in values(network.nodes)
        idx_range = node.state_offset .+ (1:node.state_dim)
        x0[idx_range] .= node.initial_state
    end

    return x0
end


"""
    dynamics_from_network(network) where {T<:Real}

Assemble a port-Hamiltonian network into a single system with dynamics.

Steps:
1. Build block-diagonal `J`, `R`, `Q`, and `B` from per-node matrices.
2. Apply interconnections to the interconnection matrix `J`.
3. Assemble initial conditions and differential-variable indicators.

The assembled system satisfies \$Q \\dot{x} = (J - R) x + B u(t)\$, where
`J` is skew-symmetric, `R` is symmetric PSD, and `Q` is diagonal PSD.

# Arguments
- `network`: Network metadata

# Returns
- `SimDynamics`: Assembled network dynamics with initial conditions
"""
function dynamics_from_network(network) where {T<:Real}
    # Create block diagonal matrices from individual systems
    J = build_block_diagonal(network.nodes, sys -> sys.interaction)
    R = build_block_diagonal(network.nodes, sys -> sys.dissipation)
    Q = build_block_diagonal(network.nodes, sys -> sys.mass)
    B = build_block_diagonal(network.nodes, sys -> sys.input)

    # Apply interconnections to J
    for connection in network.connections
        source = network.nodes[connection.from.system]
        target = network.nodes[connection.to.system]
        apply_connection!(J, connection, source, target)
    end

    # Create the assembled PortHamSystem
    network_phs = PortHamSystem(J, R, Q, B)
    x0 = build_initial_state(network)
    input_func = build_input_func(network, B)

    return SimDynamics(network_phs, x0, input_func)
end
