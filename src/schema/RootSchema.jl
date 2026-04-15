import StructTypes

"""
Schema definitions for configuration YAML files.

These structs define the expected structure and types for validated
configurations parsed from YAML.
"""


"""
    SimulationConfig

Defines simulation parameters.

# Fields
- `time_span::AbstractVector{Real}`: Start and end time `[t0, tf]`
- `solver::String`: Solver name (defaults to "IDA")
- `timestep::Real`: Fixed timestep (defaults to 0.01)
"""
struct SimulationConfig
    time_span::AbstractVector{Real}
    solver::String
    timestep::Real

    function SimulationConfig(
        time_span::Union{Nothing,AbstractVector{Real}},
        solver::Union{Nothing,String},
        timestep::Union{Nothing,Real}
    )
        time_span = something(time_span, [0.0, 1.0])
        solver = something(solver, "IDA")
        timestep = something(timestep, 0.01)
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
    definitions::String
    network::NetworkConfig
    simulation::SimulationConfig
end
StructTypes.StructType(::Type{RootConfig}) = StructTypes.Struct()
