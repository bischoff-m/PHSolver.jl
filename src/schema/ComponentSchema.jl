import StructTypes

"""
    Component

Defines a component (state variable) within a system.

# Fields
- `id::String`: Component identifier
- `dissipation::Real`: Dissipation value (defaults to 0.0)
- `mass::Real`: Mass/energy storage value (defaults to 0.0)
- `x0::Real`: Initial state value (defaults to 0.0)
"""
struct Component
    id::String
    dissipation::Real
    mass::Real
    x0::Real

    function Component(
        id::String,
        dissipation::Union{Nothing,Real},
        mass::Union{Nothing,Real},
        x0::Union{Nothing,Real}
    )
        dissipation = something(dissipation, 0.0)
        mass = something(mass, 0.0)
        x0 = something(x0, 0.0)
        new(id, dissipation, mass, x0)
    end
end
StructTypes.StructType(::Type{Component}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Component}) = (:dissipation, :mass, :x0,)

"""
    ComponentConnection

Defines a directed connection between two components within a system.

# Fields
- `from::String`: Source component id
- `to::String`: Target component id
- `weight::Real`: Connection weight (defaults to 1.0)
"""
struct ComponentConnection
    from::String
    to::String
    weight::Real

    function ComponentConnection(
        from::String,
        to::String,
        weight::Union{Nothing,Real}
    )
        weight = something(weight, 1.0)
        new(from, to, weight)
    end
end
StructTypes.StructType(::Type{ComponentConnection}) = StructTypes.Struct()
StructTypes.omitempties(::Type{ComponentConnection}) = (:weight,)
