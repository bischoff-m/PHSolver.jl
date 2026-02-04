using LinearAlgebra
using OrderedCollections
using StructTypes


"""
    PHSNode

Represents a single port-Hamiltonian system within a network.

# Fields
- `id::String`: Unique identifier for the system
- `system::PortHamSystem`: The underlying PHS
- `initial_state::AbstractVector{Float64}`: Initial values for differential variables
- `state_offset::Int`: Starting index in global state vector
- `state_dim::Int`: Dimension of this system's state
"""
struct PHSNode{T<:Real}
    id::String
    system::PortHamSystem{T}
    initial_state::AbstractVector{T}
    state_offset::Int
    state_dim::Int

    function PHSNode(
        id::String,
        system::PortHamSystem{T},
        initial_state::AbstractVector{T},
        state_offset::Int=0,
    ) where {T<:Real}
        new{T}(id, system, initial_state, state_offset, state_dimension(system))
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
- `from_indices::Union{Nothing, AbstractVector{Int}}`: Output indices (nothing = all)
- `to_node::String`: ID of target system
- `to_indices::Union{Nothing, AbstractVector{Int}}`: Input indices (nothing = all)
- `type::Symbol`: Connection type
- `coupling_matrix::Union{Nothing, AbstractMatrix{Float64}}`: Coupling matrix K for skew-symmetric
"""
struct ConnectionEdge{T<:Real}
    source::String
    target::String
    type::Symbol
    coupling_matrix::Union{Nothing,AbstractMatrix{T}}

    function ConnectionEdge{T}(
        source::String,
        target::String,
        type::Symbol;
        coupling_matrix::Union{Nothing,AbstractMatrix{T}}=nothing,
    ) where {T<:Real}
        @assert type in [:direct, :negative_feedback, :skew_symmetric] "Invalid connection type: $type"

        if type == :skew_symmetric
            @assert !isnothing(coupling_matrix) "Skew-symmetric connections require a coupling matrix"
        end

        new{T}(source, target, type, coupling_matrix)
    end
end

"""
    ExternalInput

Represents an external input to a system in the network.

# Fields
- `system::String`: ID of target system
- `indices::Union{Nothing, AbstractVector{Int}}`: Input indices (nothing = all)
- `func::String`: Expression for the input function (e.g., "constant(0.0)")
"""
struct ExternalInput
    system::String
    indices::Union{Nothing,AbstractVector{Int}}
    func::String
end

StructTypes.StructType(::Type{ExternalInput}) = StructTypes.Struct()
StructTypes.omitempties(::Type{ExternalInput}) = (:indices,)

"""
    NetworkGraph

Metadata for a network of interconnected port-Hamiltonian systems.
This is only used during assembly - the assembled result is a PortHamSystem.

# Fields
- `name::String`: Network name
- `nodes::OrderedDict{String, PHSNode}`: All PHS nodes indexed by ID
- `edges::AbstractVector{ConnectionEdge}`: All interconnections
- `external_inputs::AbstractVector{ExternalInput}`: External inputs to the network
- `total_state_dim::Int`: Total dimension of global state vector
"""
struct NetworkGraph{T<:Real}
    name::String
    nodes::OrderedDict{String,PHSNode{T}}
    edges::AbstractVector{ConnectionEdge{T}}
    external_inputs::AbstractVector{ExternalInput}
    total_state_dim::Int

    function NetworkGraph(
        name::String,
        nodes::OrderedDict{String,PHSNode{T}},
        edges::AbstractVector{ConnectionEdge{T}},
        external_inputs::AbstractVector{ExternalInput},
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
