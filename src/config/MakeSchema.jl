import JSONSchemaGenerator
import StructTypes

struct DummySchema
    systemSchema::SystemConfigSchema
    componentSchema::Component
end
StructTypes.StructType(::Type{DummySchema}) = StructTypes.Struct()


function forbid_extras!(node)
    if node isa AbstractDict
        if get(node, "type", nothing) == "object" &&
           !haskey(node, "additionalProperties")
            node["additionalProperties"] = false
        end
        for v in values(node)
            forbid_extras!(v)
        end
    end
    return node
end

function make_system_schema()
    schema_dict = JSONSchemaGenerator.schema(DummySchema; use_references=true)

    # Recursively add "additionalProperties": false to all object nodes
    forbid_extras!(schema_dict)

    # Replace the dummy schema with the actual SystemConfigSchema
    new_schema = Dict{String,Any}(
        "\$ref" => "#/\$defs/Main.PHSolver.SystemConfigSchema",
        "\$defs" => schema_dict["\$defs"],
    )

    # Set the "systems" field to allow either SystemConfigSchema or Component
    new_schema["\$defs"]["Main.PHSolver.SystemConfigSchema"]["properties"]["systems"] = Dict(
        "type" => "array",
        "items" => Dict("oneOf" => [
            Dict("\$ref" => "#/\$defs/Main.PHSolver.SystemConfigSchema"),
            Dict("\$ref" => "#/\$defs/Main.PHSolver.Component"),
        ]),
    )

    return new_schema
end