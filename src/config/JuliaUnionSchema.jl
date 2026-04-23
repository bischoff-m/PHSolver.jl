# Work around JSONSchemaGenerator's lack of Union support
import JSONSchemaGenerator

# Map union field types to a custom keyword so JSONSchemaGenerator does not
# treat them as objects.
JSONSchemaGenerator._json_type(::Union) = :union

# Recurse into union members when gathering reference-able data types.
function JSONSchemaGenerator._gather_data_types!(
    data_types::Set{DataType},
    julia_type::Union,
)
    for t in Base.uniontypes(julia_type)
        isconcretetype(t) || continue
        JSONSchemaGenerator._gather_data_types!(data_types, t)
    end
    return nothing
end

function JSONSchemaGenerator._generate_json_type_def(
    ::Val{:union},
    julia_type::Union,
    settings::JSONSchemaGenerator.SchemaSettings,
)
    # Only unions of primitive JSON types are supported; the resulting schema
    # lists all allowed primitive kinds.
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
                  "only covers primitive types.")
        end
    end
    return settings.dict_type{String,Any}("type" => unique(types))
end
