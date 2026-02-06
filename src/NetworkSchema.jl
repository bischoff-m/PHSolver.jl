import JSONSchemaGenerator, StructTypes, JSON3

"""
Schema definitions for network configuration YAML files.

These structs define the expected structure and types for validated network
configurations parsed from YAML.
"""

struct SystemComponent
    id::String
    dissipation::Union{Nothing,Real}
    energy::Union{Nothing,Real}
    x0::Union{Nothing,Real}
end
StructTypes.StructType(::Type{SystemComponent}) = StructTypes.Struct()
StructTypes.omitempties(::Type{SystemComponent}) = (:dissipation, :energy, :x0,)

"""
    SystemMatrices

Defines the matrices for a port-Hamiltonian system as parsed from YAML.

Each matrix is represented as a vector of row vectors (as produced by YAML
array parsing), and is later converted to a dense matrix in the loader.

# Fields
- `J::AbstractMatrix{Real}`: Interconnection matrix (skew-symmetric)
- `R::AbstractVector{Real}`: Dissipation matrix rows
- `Q::AbstractVector{Real}`: Mass/energy storage matrix rows
- `B::Union{Nothing, AbstractVector{Real}}`: Input matrix rows (optional)
"""
struct SystemMatrices
    J::AbstractMatrix{Real}
    R::AbstractVector{Real}
    Q::AbstractVector{Real}
    B::Union{Nothing,AbstractVector{Real}}
end
StructTypes.StructType(::Type{SystemMatrices}) = StructTypes.Struct()
StructTypes.omitempties(::Type{SystemMatrices}) = (:B,)

"""
    System

Defines a single port-Hamiltonian system in the network configuration.

# Fields
- `id::String`: Unique identifier for the system
- `matrices::SystemMatrices`: System matrices (J, R, Q, B)
- `initial_state::Union{Nothing, AbstractVector{Real}}`: Initial state values (optional)
"""
struct System
    id::String
    matrices::SystemMatrices
    initial_state::Union{Nothing,AbstractVector{Real}}
end
StructTypes.StructType(::Type{System}) = StructTypes.Struct()
StructTypes.omitempties(::Type{System}) = (:initial_state,)

"""
    Connection

Defines an interconnection between two systems.

# Fields
- `from::String`: Source system id
- `to::String`: Target system id
- `type::Symbol`: Connection type (`:direct`, `:negative_feedback`, `:skew_symmetric`)
- `from_ports::Union{Nothing, AbstractVector{Integer}}`: Optional source ports
- `to_ports::Union{Nothing, AbstractVector{Integer}}`: Optional target ports
- `coupling_matrix::Union{Nothing, AbstractMatrix{Real}}`: Coupling matrix for
    `:skew_symmetric` (optional)
"""
struct Connection
    from::String
    to::String
    type::Symbol
    from_ports::Union{Nothing,AbstractVector{Integer}}
    to_ports::Union{Nothing,AbstractVector{Integer}}
    coupling_matrix::Union{Nothing,AbstractMatrix{Real}}

    function Connection(
        from::String,
        to::String,
        type::Symbol,
        from_ports::Union{Nothing,AbstractVector{Integer}}=nothing,
        to_ports::Union{Nothing,AbstractVector{Integer}}=nothing,
        coupling_matrix::Union{Nothing,AbstractMatrix{Real}}=nothing
    )
        @assert type in [:direct, :negative_feedback, :skew_symmetric] "Invalid connection type: $type"

        if type == :skew_symmetric
            @assert !isnothing(coupling_matrix) "Skew-symmetric connections require a coupling matrix"
        end

        new(from, to, type, from_ports, to_ports, coupling_matrix)
    end
end
StructTypes.StructType(::Type{Connection}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Connection}) = (:from_ports, :to_ports, :coupling_matrix,)

"""
    ExternalInput

Represents an external input to a system in the network.

# Fields
- `system::String`: ID of target system
- `indices::Union{Nothing, AbstractVector{Integer}}`: Input indices (nothing = all)
- `func::String`: Expression for the input function (e.g., "constant(0.0)")
"""
struct ExternalInput
    system::String
    indices::Union{Nothing,AbstractVector{Integer}}
    func::String
end
StructTypes.StructType(::Type{ExternalInput}) = StructTypes.Struct()
StructTypes.omitempties(::Type{ExternalInput}) = (:indices,)

"""
    NetworkConfig

Top-level network configuration block.

# Fields
- `name::Union{Nothing, String}`: Network name (optional)
- `systems::AbstractVector{System}`: List of systems in the network
- `connections::Union{Nothing, AbstractVector{Connection}}`: System interconnections (optional)
- `external_inputs::Union{Nothing, AbstractVector{ExternalInput}}`: External inputs (optional)
"""
struct NetworkConfig
    name::Union{Nothing,String}
    systems::AbstractVector{System}
    connections::Union{Nothing,AbstractVector{Connection}}
    external_inputs::Union{Nothing,AbstractVector{ExternalInput}}
end
StructTypes.StructType(::Type{NetworkConfig}) = StructTypes.Struct()
StructTypes.omitempties(::Type{NetworkConfig}) = (:name, :connections, :external_inputs)

"""
    SimulationConfig

Defines simulation parameters.

# Fields
- `time_span::AbstractVector{Real}`: Start and end time `[t0, tf]`
- `solver::Union{Nothing, String}`: Solver name (optional)
- `timestep::Union{Nothing, Real}`: Fixed timestep (optional)
"""
mutable struct SimulationConfig
    time_span::AbstractVector{Real}
    solver::Union{Nothing,String}
    timestep::Union{Nothing,Real}
end
StructTypes.StructType(::Type{SimulationConfig}) = StructTypes.Struct()
StructTypes.omitempties(::Type{SimulationConfig}) = (:solver, :timestep)
SimulationConfigDefault = SimulationConfig([0.0, 1.0], nothing, nothing)

"""
    RootConfig

Root-level configuration object.

# Fields
- `network::NetworkConfig`: Network configuration
- `simulation::SimulationConfig`: Simulation configuration
"""
struct RootConfig
    network::NetworkConfig
    simulation::SimulationConfig
end
StructTypes.StructType(::Type{RootConfig}) = StructTypes.Struct()
