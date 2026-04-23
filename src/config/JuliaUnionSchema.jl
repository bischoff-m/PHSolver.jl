# work around JSONSchemaGenerator's lack of Union support
import JSONSchemaGenerator

# TODO: Regenerate schema to test if this can be deleted
# map a union value (its runtime type is `Union`) to a custom keyword
# so we can generate a combined schema instead of treating it as an object.
# function JSONSchemaGenerator._json_type(julia_type::Union)
#     return :union
# end

JSONSchemaGenerator._json_type(::Type{<:Union}) = :union

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