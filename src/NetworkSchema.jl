import JSONSchemaGenerator, StructTypes, JSON3

"""
Schema definitions for network configuration YAML files.
These structs define the expected structure and types for network configurations.
"""

"""
    SystemMatricesSchema

Defines the matrices for a port-Hamiltonian system.

# Fields
- `J::Vector{Vector{Float64}}`: Interconnection matrix (skew-symmetric)
- `R::Vector{Vector{Float64}}`: Dissipation matrix (symmetric, PSD)
- `Q::Vector{Vector{Float64}}`: Mass/storage matrix (symmetric, PSD)
- `B::Union{Nothing, Vector{Vector{Float64}}}`: Input matrix (optional)
"""
struct SystemMatricesSchema
    J::Vector{Vector{Float64}}
    R::Vector{Vector{Float64}}
    Q::Vector{Vector{Float64}}
    B::Union{Nothing,Vector{Vector{Float64}}}
end
StructTypes.StructType(::Type{SystemMatricesSchema}) = StructTypes.Struct()
StructTypes.omitempties(::Type{SystemMatricesSchema}) = (:B,)

"""
    SystemSchema

Defines a single port-Hamiltonian system in the network.

# Fields
- `id::String`: Unique identifier for the system
- `matrices::SystemMatricesSchema`: System matrices (J, R, Q, B)
- `initial_state::Union{Nothing, Vector{Float64}}`: Initial state values (optional)
"""
struct SystemSchema
    id::String
    matrices::SystemMatricesSchema
    initial_state::Union{Nothing,Vector{Float64}}
end
StructTypes.StructType(::Type{SystemSchema}) = StructTypes.Struct()
StructTypes.omitempties(::Type{SystemSchema}) = (:initial_state,)

"""
    ConnectionEndpointSchema

Defines one endpoint of a connection.

# Fields
- `system::String`: ID of the system
- `port::Union{Nothing, String}`: Port name (optional, e.g., "input", "output")
- `indices::Union{Nothing, Vector{Int}}`: Specific port indices (optional)
"""
struct ConnectionEndpointSchema
    system::String
    port::Union{Nothing,String}
    indices::Union{Nothing,Vector{Int}}
end
StructTypes.StructType(::Type{ConnectionEndpointSchema}) = StructTypes.Struct()
StructTypes.omitempties(::Type{ConnectionEndpointSchema}) = (:port, :indices)

"""
    ConnectionSchema

Defines an interconnection between two systems.

# Fields
- `from::ConnectionEndpointSchema`: Source system endpoint
- `to::ConnectionEndpointSchema`: Target system endpoint
- `type::String`: Connection type ("direct", "negative_feedback", "skew_symmetric")
- `coupling_matrix::Union{Nothing, Vector{Vector{Float64}}}`: Coupling matrix for skew_symmetric (optional)
"""
struct ConnectionSchema
    from::ConnectionEndpointSchema
    to::ConnectionEndpointSchema
    type::String
    coupling_matrix::Union{Nothing,Vector{Vector{Float64}}}
end
StructTypes.StructType(::Type{ConnectionSchema}) = StructTypes.Struct()
StructTypes.omitempties(::Type{ConnectionSchema}) = (:coupling_matrix,)

"""
    SimulationConfigSchema

Defines simulation parameters.

# Fields
- `time_span::Vector{Float64}`: Start and end time [t0, tf]
- `solver::Union{Nothing, String}`: Solver name (optional, default: "IDA")
- `timestep::Union{Nothing, Float64}`: Fixed timestep (optional)
"""
mutable struct SimulationConfigSchema
    time_span::Vector{Float64}
    solver::Union{Nothing,String}
    timestep::Union{Nothing,Float64}
end
StructTypes.StructType(::Type{SimulationConfigSchema}) = StructTypes.Struct()
StructTypes.omitempties(::Type{SimulationConfigSchema}) = (:solver, :timestep)
SimulationConfigDefault = SimulationConfigSchema([0.0, 1.0], nothing, nothing)

"""
    NetworkConfigSchema

Top-level network configuration.

# Fields
- `name::Union{Nothing, String}`: Network name (optional)
- `systems::Vector{SystemSchema}`: List of systems in the network
- `connections::Union{Nothing, Vector{ConnectionSchema}}`: System interconnections (optional)
- `external_inputs::Union{Nothing, Vector{ExternalInputSchema}}`: External inputs (optional)
- `simulation::Union{Nothing, SimulationConfigSchema}`: Simulation configuration (optional)
"""
struct NetworkConfigSchema
    name::Union{Nothing,String}
    systems::Vector{SystemSchema}
    connections::Union{Nothing,Vector{ConnectionSchema}}
    external_inputs::Union{Nothing,Vector{ExternalInput}}
end
StructTypes.StructType(::Type{NetworkConfigSchema}) = StructTypes.Struct()
StructTypes.omitempties(::Type{NetworkConfigSchema}) = (:name, :connections, :external_inputs)

"""
    RootConfigSchema

Root-level configuration object.

# Fields
- `network::NetworkConfigSchema`: The network configuration
"""
struct RootConfigSchema
    network::NetworkConfigSchema
    simulation::SimulationConfigSchema
end
StructTypes.StructType(::Type{RootConfigSchema}) = StructTypes.Struct()
