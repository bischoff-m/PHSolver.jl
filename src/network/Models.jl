using LinearAlgebra
using OrderedCollections
import OrdinaryDiffEq as Eq
import Graphs

"""
    PhsNode

Represents a single port-Hamiltonian system within a network.

# Fields
- `id::String`: Unique identifier for the system
- `system::PortHamSystem{T}`: The underlying PHS
- `initial_state::AbstractVector{T}`: Initial values for differential variables
- `state_offset::Int`: Starting index in global state vector
- `state_dim::Int`: Dimension of this system's state
"""
struct PhsNodeOld{T<:Real}
    id::String
    system::PortHamSystem{T}
    initial_state::AbstractVector{T}
    ports::Dict{String,Int}
    state_offset::Int
    state_dim::Int

    function PhsNodeOld(
        id::String,
        system::PortHamSystem{T},
        initial_state::AbstractVector{T},
        ports::Dict{String,Int},
        state_offset::Int=0,
    ) where {T<:Real}
        new{T}(id, system, initial_state, ports, state_offset, state_dimension(system))
    end
end

# struct PhsNode{T<:Real}
#     id::String




"""
    Network

Metadata for a network of interconnected port-Hamiltonian systems.
This is used during assembly; the assembled result is a single `PortHamSystem`.

# Fields
- `name::String`: Network name
- `nodes::OrderedDict{String, PhsNode}`: All PHS nodes indexed by ID
- `connections::AbstractVector{NetworkConnection}`: All interconnections
- `total_state_dim::Int`: Total dimension of the global state vector
"""
# TODO: Use a DiGraph for connections
struct PhsGraph{T<:Real}
    graph::Graphs.DiGraph
    nodes::OrderedDict{String,PhsNodeOld{T}}

    function PhsGraph(
        nodes::OrderedDict{String,PhsNodeOld{T}},
    ) where {T<:Real}
        new{T}(
            nodes
        )
    end
end


"""
    SimulationResult

Container for a simulation solution and its associated model metadata.

# Fields
- `solution::Eq.SciMLBase.AbstractSolution`: Solution object from the solver
- `system::PortHamSystem{T}`: Assembled system that was simulated
- `graph::PhsGraph{T}`: Network metadata used for assembly
"""
struct SimulationResult{T,S<:Eq.SciMLBase.AbstractSolution}
    solution::S
    system::PortHamSystem{T}
    graph::PhsGraph{T}
end

# struct PhsNetwork{T<:Real}

