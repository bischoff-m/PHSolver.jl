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
- `output_interval::Real`: Output interval (defaults to 0.01)
"""
struct SimConfig
    time_span::AbstractVector{<:Real}
    solver::String
    output_interval::Real

    function SimConfig(
        time_span::Union{Nothing,AbstractVector{<:Real}}=nothing,
        solver::Union{Nothing,String}=nothing,
        output_interval::Union{Nothing,Real}=nothing
    )
        time_span = something(time_span, [0.0, 1.0])
        solver = something(solver, "IDA")
        output_interval = something(output_interval, 0.01)
        new(time_span, solver, output_interval)
    end
end
StructTypes.StructType(::Type{SimConfig}) = StructTypes.Struct()
StructTypes.omitempties(::Type{SimConfig}) = (:time_span, :solver, :output_interval)
