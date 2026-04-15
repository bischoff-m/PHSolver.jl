include("../src/PHSolver.jl")

import JSONSchemaGenerator, JSON3
"""
    write_schema(output_file::String="schemas/system.schema.json")

Generate and write the JSON schema to a file.

# Arguments
- `output_file::String`: Path to output JSON schema file
"""
function write_schema(output_file="schemas/system.schema.json")
    schema = PHSolver.make_system_schema()

    # Write to file with pretty formatting
    open(output_file, "w") do io
        JSON3.pretty(io, schema)
    end

    println("Schema written to: $output_file")
end

# Generate schema when script is run directly
write_schema()
