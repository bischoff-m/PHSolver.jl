using LinearAlgebra

"""
    PHSNode

Represents a single port-Hamiltonian system within a network.

# Fields
- `id::String`: Unique identifier for the system
- `system::PortHamSystem`: The underlying PHS
- `initial_conditions::Vector{Float64}`: Initial values for differential variables
- `state_offset::Int`: Starting index in global state vector
- `state_dim::Int`: Dimension of this system's state
- `input_dim::Int`: Dimension of this system's input
- `output_dim::Int`: Dimension of this system's output
"""
struct PHSNode{T<:Real}
    id::String
    system::PortHamSystem{T}
    initial_conditions::Vector{T}
    state_offset::Int
    state_dim::Int
    input_dim::Int
    output_dim::Int

    function PHSNode(
        id::String,
        system::PortHamSystem{T},
        initial_conditions::Vector{T},
        state_offset::Int=0,
    ) where {T<:Real}
        state_dim = state_dimension(system)
        input_dim = input_dimension(system)
        output_dim = input_dim  # For PHS, output_dim = input_dim (from y = B^T * ∇H)

        new{T}(id, system, initial_conditions, state_offset, state_dim, input_dim, output_dim)
    end
end

"""
    ConnectionEdge

Represents an interconnection between two port-Hamiltonian systems.

# Connection Types
- `:direct`: u_target = y_source + external
- `:negative_feedback`: u_target = -y_source + external
- `:skew_symmetric`: Power-conserving skew-symmetric coupling

# Fields
- `from_node::String`: ID of source system
- `from_indices::Union{Nothing, Vector{Int}}`: Output indices (nothing = all)
- `to_node::String`: ID of target system
- `to_indices::Union{Nothing, Vector{Int}}`: Input indices (nothing = all)
- `type::Symbol`: Connection type
- `coupling_matrix::Union{Nothing, Matrix{Float64}}`: Coupling matrix K for skew-symmetric
"""
struct ConnectionEdge{T<:Real}
    from_node::String
    from_indices::Union{Nothing,Vector{Int}}
    to_node::String
    to_indices::Union{Nothing,Vector{Int}}
    type::Symbol
    coupling_matrix::Union{Nothing,Matrix{T}}

    function ConnectionEdge{T}(
        from_node::String,
        to_node::String,
        type::Symbol;
        from_indices::Union{Nothing,Vector{Int}}=nothing,
        to_indices::Union{Nothing,Vector{Int}}=nothing,
        coupling_matrix::Union{Nothing,Matrix{T}}=nothing,
    ) where {T<:Real}
        @assert type in [:direct, :negative_feedback, :skew_symmetric] "Invalid connection type: $type"

        if type == :skew_symmetric
            @assert !isnothing(coupling_matrix) "Skew-symmetric connections require a coupling matrix"
        end

        new{T}(from_node, from_indices, to_node, to_indices, type, coupling_matrix)
    end
end

# Convenience constructor with default Float64
function ConnectionEdge(
    from_node::String,
    to_node::String,
    type::Symbol;
    from_indices::Union{Nothing,Vector{Int}}=nothing,
    to_indices::Union{Nothing,Vector{Int}}=nothing,
    coupling_matrix::Union{Nothing,Matrix{<:Real}}=nothing,
)
    T = isnothing(coupling_matrix) ? Float64 : eltype(coupling_matrix)
    ConnectionEdge{T}(
        from_node,
        to_node,
        type;
        from_indices=from_indices,
        to_indices=to_indices,
        coupling_matrix=coupling_matrix,
    )
end

"""
    ExternalInput

Represents an external input to a system in the network.

# Fields
- `system::String`: ID of target system
- `indices::Union{Nothing, Vector{Int}}`: Input indices (nothing = all)
- `function_expr::String`: Expression for the input function (e.g., "constant(0.0)")
"""
struct ExternalInput
    system::String
    indices::Union{Nothing,Vector{Int}}
    function_expr::String
end

"""
    NetworkGraph

Metadata for a network of interconnected port-Hamiltonian systems.
This is only used during assembly - the assembled result is a PortHamSystem.

# Fields
- `name::String`: Network name
- `nodes::Dict{String, PHSNode}`: All PHS nodes indexed by ID
- `edges::Vector{ConnectionEdge}`: All interconnections
- `external_inputs::Vector{ExternalInput}`: External inputs to the network
- `total_state_dim::Int`: Total dimension of global state vector
"""
struct NetworkGraph{T<:Real}
    name::String
    nodes::Dict{String,PHSNode{T}}
    edges::Vector{ConnectionEdge{T}}
    external_inputs::Vector{ExternalInput}
    total_state_dim::Int

    function NetworkGraph(
        name::String,
        nodes::Dict{String,PHSNode{T}},
        edges::Vector{ConnectionEdge{T}},
        external_inputs::Vector{ExternalInput},
    ) where {T<:Real}
        # Calculate total state dimension
        total_state_dim = sum(node.state_dim for node in values(nodes))

        new{T}(
            name,
            nodes,
            edges,
            external_inputs,
            total_state_dim,
        )
    end
end

"""
    get_node(network::NetworkGraph, id::String)

Get a node from the network by ID.
"""
function get_node(network::NetworkGraph, id::String)::PHSNode
    if !haskey(network.nodes, id)
        error("Node '$id' not found in network '$(network.name)'")
    end
    return network.nodes[id]
end

"""
    create_network_nodes(systems_config::Vector)

Create PHSNode objects from system configurations.
Assigns state offsets for positioning in global state vector.
"""
function create_network_nodes(
    systems_config::Vector,
    ::Type{T}=Float64,
) where {T<:Real}
    nodes = Dict{String,PHSNode{T}}()
    state_offset = 0

    for sys_config in systems_config
        id = sys_config["id"]
        matrices = sys_config["matrices"]

        # Create matrices
        J = Matrix{T}(hcat(matrices["J"]...)')
        R = Matrix{T}(hcat(matrices["R"]...)')
        Q = Matrix{T}(hcat(matrices["Q"]...)')
        B = Matrix{T}(hcat(matrices["B"]...)')

        # Create PHS
        system = PortHamSystem(J, R, Q, B)

        # Get initial conditions (default to zeros)
        initial_conditions = if haskey(sys_config, "initial_conditions") &&
           haskey(sys_config["initial_conditions"], "differential")
            Vector{T}(sys_config["initial_conditions"]["differential"])
        else
            # Count differential variables (non-zero diagonal in Q)
            n_diff = sum(Q[i, i] != 0 for i in 1:size(Q, 1))
            zeros(T, n_diff)
        end

        # Create node
        node = PHSNode(id, system, initial_conditions, state_offset)
        nodes[id] = node

        # Update offset for next node
        state_offset += node.state_dim
    end

    return nodes
end

"""
    get_node_state_range(node::PHSNode)

Get the range of indices for a node's state in the global state vector.
"""
function get_node_state_range(node::PHSNode)
    return (node.state_offset+1):(node.state_offset+node.state_dim)
end
