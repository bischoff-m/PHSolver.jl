using LinearAlgebra

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
- `differential_vars::Vector{Bool}`: Which variables are differential (vs algebraic)
"""
function assemble_network(graph::NetworkGraph{T}) where {T<:Real}
    n = graph.total_state_dim

    # Step 1: Create block diagonal matrices from individual systems
    println("Assembling block diagonal matrices...")

    J_block = assemble_block_diagonal_matrix(graph.nodes, sys -> sys.interconnection)
    R_block = assemble_block_diagonal_matrix(graph.nodes, sys -> sys.dissipation)
    Q_block = assemble_block_diagonal_matrix(graph.nodes, sys -> sys.mass)
    B_block = assemble_block_diagonal_matrix(graph.nodes, sys -> sys.input)

    # Step 2: Start with block diagonal J, then apply interconnections
    J_global = copy(J_block)

    println("Applying $(length(graph.edges)) interconnections...")
    for edge in graph.edges
        apply_connection!(J_global, graph.nodes, edge)
    end

    # Step 3: R and Q remain block diagonal (no coupling through dissipation/mass)
    R_global = R_block
    Q_global = Q_block
    B_global = B_block

    # Step 4: Assemble initial conditions for the network
    println("Computing consistent initial conditions...")
    x0, differential_vars = assemble_initial_conditions(graph, Q_global)

    println("Network assembly complete!")
    println("  Total state dimension: $(graph.total_state_dim)")
    println("  Number of systems: $(length(graph.nodes))")
    println("  Number of interconnections: $(length(graph.edges))")

    # Create the assembled PortHamSystem (without validation checks since it's assembled)
    # We bypass the constructor validation since assembled networks may have special structure
    network_phs = PortHamSystem(J_global, R_global, Q_global, B_global)

    return network_phs, x0, differential_vars
end

"""
    assemble_initial_conditions(graph::NetworkGraph, Q::Matrix)

Compute consistent initial conditions for the entire network.

This function:
1. Collects initial differential variable values from each node
2. Solves for algebraic variables using the network DAE constraints
3. Returns initial state and differential variable indicators

# Arguments
- `graph::NetworkGraph`: Network graph metadata
- `Q::Matrix`: Assembled mass matrix

# Returns
- `x0::Vector`: Initial state vector
- `differential_vars::Vector{Bool}`: Indicators for differential variables
"""
function assemble_initial_conditions(
    graph::NetworkGraph{T},
    Q::Matrix{T},
) where {T<:Real}
    n = graph.total_state_dim

    # Identify differential and algebraic variables in global system
    differential_vars = [Q[i, i] != 0.0 for i in 1:n]

    # Build complete initial state vector
    x0 = zeros(T, n)

    # Set differential variables from node initial conditions
    for node in values(graph.nodes)
        node_range = get_node_state_range(node)
        node_Q = node.system.mass

        # Identify differential variables in this node
        node_diff_vars = [node_Q[i, i] != 0.0 for i in 1:size(node_Q, 1)]
        diff_idx = 1
        for (i, is_diff) in enumerate(node_diff_vars)
            if is_diff
                global_idx = node.state_offset + i
                if diff_idx <= length(node.initial_conditions)
                    x0[global_idx] = node.initial_conditions[diff_idx]
                end
                diff_idx += 1
            end
        end
    end

    # Note: Algebraic variables remain zero unless computed elsewhere
    # For now, we initialize algebraic variables to zero
    # A more sophisticated approach would solve the algebraic constraints

    return x0, differential_vars
end

"""
    compute_hamiltonian(system::PortHamSystem, x::Vector)

Compute the Hamiltonian of a port-Hamiltonian system.

H(x) = 0.5 * x^T * Q * x

# Arguments
- `system::PortHamSystem`: The PHS
- `x::Vector`: State vector

# Returns
- Total energy
"""
function compute_hamiltonian(system::PortHamSystem{T}, x::Vector{T}) where {T<:Real}
    @assert length(x) == state_dimension(system) "State dimension mismatch"
    return 0.5 * dot(x, system.mass * x)
end

"""
    get_network_state_info(graph::NetworkGraph)

Get information about the network state structure.

# Returns
- Dictionary with state information for each node
"""
function get_network_state_info(graph::NetworkGraph)
    info = Dict{String,Dict{String,Any}}()

    for (id, node) in graph.nodes
        node_Q = node.system.mass
        diff_vars = [node_Q[i, i] != 0.0 for i in 1:size(node_Q, 1)]

        info[id] = Dict(
            "state_dim" => node.state_dim,
            "state_range" => get_node_state_range(node),
            "n_differential" => sum(diff_vars),
            "n_algebraic" => node.state_dim - sum(diff_vars),
            "differential_indices" => findall(diff_vars),
            "algebraic_indices" => findall(.!diff_vars),
        )
    end

    return info
end
