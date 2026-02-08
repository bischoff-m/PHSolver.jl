import YAML, JSONSchema, JSON3

"""
    validate_config(config_dict::Dict)

Validate a YAML configuration against the JSON schema.

# Arguments
- `config_dict::Dict`: Configuration dictionary from YAML file

# Throws
- Error if validation fails
"""
function validate_config(config_dict::Dict)
    # Load schema
    schema_path = joinpath(dirname(@__DIR__), "../schemas/network.schema.json")
    schema_dict = JSON3.read(schema_path)
    schema = JSONSchema.Schema(schema_dict)

    # Validate (JSONSchema.jl works with Dict directly)
    result = JSONSchema.validate(schema, config_dict)

    if result !== nothing
        error("Configuration validation failed:", result)
    end
end

"""
    read_config(filepath::String)

Read a YAML configuration file and parse it into typed structs.

The file is validated against the JSON schema before parsing.
"""
function read_config(filepath::String)
    # Load YAML file
    yaml_dict = YAML.load_file(filepath)

    # Validate against schema
    validate_config(yaml_dict)

    # Parse into typed structs
    json_str = JSON3.write(yaml_dict)
    return JSON3.read(json_str, RootConfig)
end