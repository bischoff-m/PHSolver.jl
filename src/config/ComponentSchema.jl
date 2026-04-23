import StructTypes


# Use Float64 rather than abstract Number; JSON3 cannot deserialize into an
# abstract `Number` because it lacks field info. Float64 covers all numeric
# literals we expect from YAML.
SymbolType = Union{String,Float64}

"""
    Component

Defines a component (state variable) within a system.

# Fields
- `id::String`: Component identifier
- `dissipation::String`: Dissipation value (defaults to "0.0")
- `mass::String`: Mass value (reciprocal of energy storage value in Q) (defaults to "0.0")
- `input::String`: Input coefficient (defaults to "1.0")
- `x0::String`: Initial state value (defaults to "0.0")
"""
struct Component
    id::String
    x0::SymbolType
    dissipation::SymbolType
    mass::SymbolType
    input::SymbolType

    function Component(
        id::String,
        # Need at least one required field to avoid ambiguity with SystemConfig
        x0::SymbolType,
        dissipation::Union{Nothing,SymbolType}=nothing,
        mass::Union{Nothing,SymbolType}=nothing,
        input::Union{Nothing,SymbolType}=nothing
    )
        dissipation = something(dissipation, 0.0)
        mass = something(mass, 0.0)
        input = something(input, 1.0)
        new(id, x0, dissipation, mass, input)
    end
end
StructTypes.StructType(::Type{Component}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Component}) = (:dissipation, :mass, :input)

"""
    Connection

Defines a directed connection between two components within a system.

# Fields
- `from::String`: Source component id
- `to::String`: Target component id
- `weight::String`: Connection weight (defaults to "1.0")
"""
struct Connection
    from::String
    to::String
    weight::SymbolType

    function Connection(
        from::String,
        to::String,
        weight::Union{Nothing,SymbolType}
    )
        weight = something(weight, 1.0)
        new(from, to, weight)
    end
end
StructTypes.StructType(::Type{Connection}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Connection}) = (:weight,)
