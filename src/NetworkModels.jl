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
    NetworkGraph

Metadata for a network of interconnected port-Hamiltonian systems.
This is only used during assembly - the assembled result is a PortHamSystem.

# Fields
- `name::String`: Network name
- `nodes::OrderedDict{String, PHSNode}`: All PHS nodes indexed by ID
- `edges::AbstractVector{Connection}`: All interconnections
- `external_inputs::AbstractVector{ExternalInput}`: External inputs to the network
- `total_state_dim::Int`: Total dimension of global state vector
"""
struct NetworkGraph{T<:Real}
    name::String
    nodes::OrderedDict{String,PHSNode{T}}
    edges::AbstractVector{Connection}
    external_inputs::AbstractVector{ExternalInput}
    total_state_dim::Int

    function NetworkGraph(
        name::String,
        nodes::OrderedDict{String,PHSNode{T}},
        edges::AbstractVector{Connection},
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
