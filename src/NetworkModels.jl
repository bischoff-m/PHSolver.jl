using LinearAlgebra
using OrderedCollections
using StructTypes
import OrdinaryDiffEq as Eq

"""
    PHSNode

Represents a single port-Hamiltonian system within a network.

# Fields
- `id::String`: Unique identifier for the system
- `system::PortHamSystem{T}`: The underlying PHS
- `initial_state::AbstractVector{T}`: Initial values for differential variables
- `state_offset::Int`: Starting index in global state vector
- `state_dim::Int`: Dimension of this system's state
"""
struct PHSNode{T<:Real}
    id::String
    system::PortHamSystem{T}
    initial_state::AbstractVector{T}
    ports::Dict{String,Int}
    state_offset::Int
    state_dim::Int

    function PHSNode(
        id::String,
        system::PortHamSystem{T},
        initial_state::AbstractVector{T},
        ports::Dict{String,Int},
        state_offset::Int=0,
    ) where {T<:Real}
        new{T}(id, system, initial_state, ports, state_offset, state_dimension(system))
    end
end


"""
    NetworkGraph

Metadata for a network of interconnected port-Hamiltonian systems.
This is used during assembly; the assembled result is a single `PortHamSystem`.

# Fields
- `name::String`: Network name
- `nodes::OrderedDict{String, PHSNode}`: All PHS nodes indexed by ID
- `connections::AbstractVector{NetworkConnection}`: All interconnections
- `total_state_dim::Int`: Total dimension of the global state vector
"""
struct NetworkGraph{T<:Real}
    name::String
    nodes::OrderedDict{String,PHSNode{T}}
    connections::AbstractVector{NetworkConnection}
    total_state_dim::Int

    function NetworkGraph(
        name::String,
        nodes::OrderedDict{String,PHSNode{T}},
        connections::AbstractVector{NetworkConnection},
    ) where {T<:Real}
        # Calculate total state dimension
        total_state_dim = sum((node.state_dim for node in values(nodes)); init=0)

        new{T}(
            name,
            nodes,
            connections,
            total_state_dim,
        )
    end
end


"""
    SimulationResult

Container for a simulation solution and its associated model metadata.

# Fields
- `solution::Eq.SciMLBase.AbstractSolution`: Solution object from the solver
- `system::PortHamSystem{T}`: Assembled system that was simulated
- `graph::NetworkGraph{T}`: Network metadata used for assembly
"""
struct SimulationResult{T,S<:Eq.SciMLBase.AbstractSolution}
    solution::S
    system::PortHamSystem{T}
    graph::NetworkGraph{T}
end
