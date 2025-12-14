using YAML, JSON3, JSONSchema, StructTypes, JSONSchemaGenerator

# Define a simple schema for testing
struct PersonSchema
    name::String
    age::Int
    email::Union{Nothing,String}
end
StructTypes.StructType(::Type{PersonSchema}) = StructTypes.Struct()
StructTypes.omitempties(::Type{PersonSchema}) = (:email,)

struct ConfigSchema
    version::String
    people::Vector{PersonSchema}
end
StructTypes.StructType(::Type{ConfigSchema}) = StructTypes.Struct()

# Generate JSON schema
schema_dict = JSONSchemaGenerator.schema(ConfigSchema, use_references=true)

# Create example YAML content
yaml_content = """
version: "1.0"
people:
  - name: "Alice"
    age: 30
    email: "alice@example.com"
  - name: "Bob"
    age: 25
"""

# Load and validate
yaml_dict = YAML.load(yaml_content)
println("YAML loaded as: $(typeof(yaml_dict))")
println("Keys: $(keys(yaml_dict))")
println()

# Validate against schema
println("Validating against schema...")
schema = JSONSchema.Schema(schema_dict)
result = JSONSchema.validate(schema, yaml_dict)

if result !== nothing
    println("❌ Validation failed:", result)
else
    println("✅ Validation passed!")
end

# Debug: Check the actual dict content
println("Dict content:")
for (k, v) in yaml_dict
    println("  $k ($(typeof(k))) => $v ($(typeof(v)))")
end
println()

# Try using JSON3 for parsing instead (it works better with StructTypes)
println("Trying JSON3 approach (convert to JSON and back)...")
using JSON3
try
    # Convert to JSON string and parse with JSON3
    json_str = JSON3.write(yaml_dict)
    println("JSON representation:")
    println(json_str)
    println()

    # Parse with JSON3 which integrates well with StructTypes
    obj = JSON3.read(json_str, ConfigSchema)
    println("✅ Parsed object type: $(typeof(obj))")
    println("   version: $(obj.version)")
    println("   people[1].name: $(obj.people[1].name)")
    println("   people[1].age: $(obj.people[1].age)")
    println("   people[2].email: $(obj.people[2].email)")
catch e
    println("❌ Failed: $e")
    showerror(stdout, e, catch_backtrace())
    println()
end
println()

println("Test complete!")
