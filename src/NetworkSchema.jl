import JSONSchemaGenerator, StructTypes, JSON3

"""
Schema definitions for network configuration YAML files.

These structs define the expected structure and types for validated network
configurations parsed from YAML.
"""

struct Component
    id::String
    dissipation::Real
    mass::Real
    x0::Real

    function Component(
        id::String,
        dissipation::Union{Nothing,Real}=0.0,
        mass::Union{Nothing,Real}=0.0,
        x0::Union{Nothing,Real}=0.0
    )
        new(id, dissipation, mass, x0)
    end
end
StructTypes.StructType(::Type{Component}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Component}) = (:dissipation, :mass, :x0,)

struct ComponentConnection
    from::String
    to::String
    weight::Real

    function ComponentConnection(
        from::String,
        to::String,
        weight::Union{Nothing,Real}=1.0
    )
        new(from, to, weight)
    end
end
StructTypes.StructType(::Type{ComponentConnection}) = StructTypes.Struct()
StructTypes.omitempties(::Type{ComponentConnection}) = (:weight,)

"""
    PhsMatrices

Defines the matrices for a port-Hamiltonian system as parsed from YAML.

Each matrix is represented as a vector of row vectors (as produced by YAML
array parsing), and is later converted to a dense matrix in the loader.

# Fields
- `J::AbstractVector{AbstractVector{Real}}`: Interconnection matrix (skew-symmetric)
- `R::AbstractVector{Real}`: Dissipation matrix rows
- `Q::AbstractVector{Real}`: Mass/energy storage matrix rows
- `B::Union{Nothing, AbstractVector{Real}}`: Input matrix rows (optional)
- `x0::Union{Nothing, AbstractVector{Real}}`: Initial state values (optional)
"""
struct PhsMatrices
    J::AbstractVector{AbstractVector{Real}}
    R::AbstractVector{Real}
    Q::AbstractVector{Real}
    B::AbstractVector{Real}
    x0::AbstractVector{Real}

    function PhsMatrices(
        J::AbstractVector{AbstractVector{Real}},
        R::AbstractVector{Real},
        Q::AbstractVector{Real},
        B::Union{Nothing,AbstractVector{Real}}=zeros(Real, length(J)),
        x0::Union{Nothing,AbstractVector{Real}}=zeros(Real, length(J))
    )
        # Preconditions are checked in the PortHamSystem constructor because the
        # types are not yet converted.
        new(J, R, Q, B, x0)
    end
end
StructTypes.StructType(::Type{PhsMatrices}) = StructTypes.Struct()
StructTypes.omitempties(::Type{PhsMatrices}) = (:B, :x0,)

"""
    MatrixSystem

Defines a single port-Hamiltonian system in the network configuration.

# Fields
- `id::String`: Unique identifier for the system
- `matrices::PhsMatrices`: System matrices (J, R, Q, B)
- `ports::Dict{String,Integer}`: Optional mapping of port names to indices
"""
struct MatrixSystem
    id::String
    matrices::PhsMatrices
    ports::Dict{String,Integer}

    function MatrixSystem(
        id::String,
        matrices::PhsMatrices,
        ports::Union{Nothing,Dict{String,Integer}}=Dict{String,Integer}()
    )
        new(id, matrices, ports)
    end
end
StructTypes.StructType(::Type{MatrixSystem}) = StructTypes.Struct()
StructTypes.omitempties(::Type{MatrixSystem}) = (:ports,)

struct ComponentSystem
    id::String
    components::AbstractVector{Component}
    connections::AbstractVector{ComponentConnection}
    ports::Dict{String,String}

    function ComponentSystem(
        id::String,
        components::AbstractVector{Component},
        connections::AbstractVector{ComponentConnection},
        ports::Union{Nothing,Dict{String,String}}=Dict{String,String}()
    )
        new(id, components, connections, ports)
    end
end
StructTypes.StructType(::Type{ComponentSystem}) = StructTypes.Struct()
StructTypes.omitempties(::Type{ComponentSystem}) = (:ports,)


struct SystemPort
    system::String
    port::String
end
StructTypes.StructType(::Type{SystemPort}) = StructTypes.Struct()


"""
    Connection

Defines an interconnection between two systems.

# Fields
- `from::String`: Source system id
- `to::String`: Target system id
- `type::Symbol`: Edge type (`:direct`, `:negative_feedback`, `:skew_symmetric`)
- `from_ports::Union{Nothing, AbstractVector{Integer}}`: Optional source ports
- `to_ports::Union{Nothing, AbstractVector{Integer}}`: Optional target ports
- `coupling_matrix::Union{Nothing, AbstractVector{AbstractVector{Real}}}`: Coupling matrix for
    `:skew_symmetric` (optional)
"""
struct NetworkConnection
    from::SystemPort
    to::SystemPort
    weight::Real

    function NetworkConnection(
        from::SystemPort,
        to::SystemPort,
        weight::Union{Nothing,Real}=1.0
    )
        new(from, to, weight)
    end
end
StructTypes.StructType(::Type{NetworkConnection}) = StructTypes.Struct()
StructTypes.omitempties(::Type{NetworkConnection}) = (:weight,)


"""
    NetworkConfig

Top-level network configuration block.

# Fields
- `name::Union{Nothing, String}`: Network name (optional)
- `systems::AbstractVector{Union{MatrixSystem,ComponentSystem}}`: List of systems in the network
- `connections::Union{Nothing, AbstractVector{NetworkConnection}}`: System interconnections (optional)
- `external_inputs::Union{Nothing, AbstractVector{ExternalInput}}`: External inputs (optional)
"""
struct NetworkConfig
    name::String
    systems::AbstractVector{MatrixSystem}
    # systems::AbstractVector{Union{MatrixSystem,ComponentSystem}}
    connections::AbstractVector{NetworkConnection}
    ports::Dict{String,SystemPort}

    function NetworkConfig(
        name::String,
        systems::AbstractVector{MatrixSystem},
        connections::Union{Nothing,AbstractVector{NetworkConnection}}=NetworkConnection[],
        ports::Union{Nothing,Dict{String,SystemPort}}=Dict{String,SystemPort}()
    )
        new(name, systems, connections, ports)
    end
end
StructTypes.StructType(::Type{NetworkConfig}) = StructTypes.Struct()
StructTypes.omitempties(::Type{NetworkConfig}) = (:connections, :ports,)

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
    solver::String
    timestep::Real

    function SimulationConfig(
        time_span::AbstractVector{Real}=[0.0, 1.0],
        solver::Union{Nothing,String}="IDA",
        timestep::Union{Nothing,Real}=0.01
    )
        new(time_span, solver, timestep)
    end
end
StructTypes.StructType(::Type{SimulationConfig}) = StructTypes.Struct()
StructTypes.omitempties(::Type{SimulationConfig}) = (:solver, :timestep)

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
