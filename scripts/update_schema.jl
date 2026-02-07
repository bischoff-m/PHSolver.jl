include("../src/PHSim.jl")

import .PHSim
import JSONSchemaGenerator, JSON3

"""
    generate_schema(output_file::String="schemas/network.schema.json")

Generate and write the JSON schema to a file.

# Arguments
- `output_file::String`: Path to output JSON schema file
"""
function generate_schema(output_file::String="schemas/network.schema.json")
    # Generate schema with references for cleaner structure
    schema_dict = JSONSchemaGenerator.schema(PHSim.RootConfig, use_references=true)

    # Write to file with pretty formatting
    open(output_file, "w") do io
        JSON3.pretty(io, schema_dict)
    end

    println("Schema written to: $output_file")
    return schema_dict
end

# Generate schema when script is run directly
generate_schema()
nothing
