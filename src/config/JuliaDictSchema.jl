"""
    DictSchema

Defines how to generate JSON Schema for `AbstractDict` types. This is used for
the `components` and `connections` fields of `SystemConfig`, which are
dictionaries mapping component/connection IDs to their definitions.
"""

import JSONSchemaGenerator

JSONSchemaGenerator._json_type(::Type{<:AbstractDict}) = :dict

function JSONSchemaGenerator._generate_json_type_def(
    ::Val{:dict},
    julia_type::Type{<:AbstractDict},
    settings::JSONSchemaGenerator.SchemaSettings,
)
    value_type = Base.valtype(julia_type)
    item_type = if settings.use_references && value_type in settings.reference_types
        JSONSchemaGenerator._json_reference(value_type, settings)
    else
        JSONSchemaGenerator._generate_json_type_def(value_type, settings)
    end
    return settings.dict_type{String,Any}(
        "type" => "object",
        "additionalProperties" => item_type,
    )
end
