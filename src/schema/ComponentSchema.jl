import StructTypes

# work around JSONSchemaGenerator's lack of Union support
import JSONSchemaGenerator

# when generating schemas we want to allow unions such as Union{String,Number}
# to translate into a JSON Schema with multiple allowed types.  the package
# currently tries to collect DataType values which fails for a bare Union,
# so we add a more specific method that recurses into the union members.
function JSONSchemaGenerator._gather_data_types!(data_types::Set{DataType}, julia_type::Union)
    # drill into each branch of the union instead of pushing the union itself
    # only recurse for concrete struct-like types; the package's helper already
    # knows how to skip everything else, so mirror that guard here to avoid
    # calling `fieldtypes` on abstract types like Number or String.
    for t in Base.uniontypes(julia_type)
        # skip abstract types (Number, etc.) since the base helper cannot
        # handle them; concrete types such as String are safe to recurse into
        isconcretetype(t) || continue
        JSONSchemaGenerator._gather_data_types!(data_types, t)
    end
    return nothing
end

# map a union value (its runtime type is `Union`) to a custom keyword
# so we can generate a combined schema instead of treating it as an object.
function JSONSchemaGenerator._json_type(julia_type::Union)
    return :union
end

function JSONSchemaGenerator._generate_json_type_def(::Val{:union},
    julia_type::Union,
    settings::JSONSchemaGenerator.SchemaSettings)
    # only unions of primitive JSON types are supported; the resulting schema
    # simply lists the allowed types.  if any member is non-primitive we raise
    # an error so the caller knows to handle it separately.
    types = String[]
    for arg in Base.uniontypes(julia_type)
        arg_type = JSONSchemaGenerator._json_type(arg)
        if arg_type in (:string, :integer, :number, :boolean, :array, :null)
            push!(types, String(arg_type))
        elseif arg_type == :object && arg <: Number
            push!(types, "number")
        else
            error("Unsupported union member type $arg; " *
                  "JSONSchemaGenerator cannot handle union types and this " *
                  "only covers primitive types (so far).")
        end
    end
    return settings.dict_type{String,Any}("type" => types)
end


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
- `mass::String`: Mass/energy storage value (defaults to "0.0")
- `x0::String`: Initial state value (defaults to "0.0")
"""
struct Component
    id::String
    dissipation::SymbolType
    mass::SymbolType
    x0::SymbolType

    function Component(
        id::String,
        dissipation::Union{Nothing,SymbolType},
        mass::Union{Nothing,SymbolType},
        x0::Union{Nothing,SymbolType}
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
