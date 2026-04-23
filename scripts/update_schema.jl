include("../src/PHSolver.jl")

import JSONSchemaGenerator, JSON3
"""
    write_schema(to::String)

Generate and write the JSON schema to a file.

# Arguments
- `to::String`: Path to output JSON schema file
"""
function write_schema(to=normpath(joinpath(@__DIR__, "..", "schemas", "system.schema.json")))
    schema = PHSolver.make_system_schema()

    # Write to file with pretty formatting
    mkpath(dirname(to))
    open(to, "w") do io
        JSON3.pretty(io, schema)
    end

    println("Schema written to: $to")
end

# Generate schema when script is run directly
write_schema()
