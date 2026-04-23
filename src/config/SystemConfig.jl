import StructTypes

"""
    System

Defines a system composed of components, their internal connections, and
optional ports.

# Fields
- `id::String`: System identifier
- `components::AbstractVector{Component}`: Components in the system
- `connections::AbstractVector{ComponentConnection}`: Internal connections
- `ports::Dict{String,String}`: Mapping from port name to component id
  (optional)
- `subsystems::AbstractVector{System}`: Subsystems contained within this system
  (optional)
- `definitions::Union{Nothing,String}`: Optional string for user-defined
  functions or definitions that can be referenced in the configuration.
"""
struct SystemConfig
    id::String
    connections::AbstractVector{Connection}
    ports::Dict{String,String}
    systems::AbstractVector{Union{SystemConfig,Component}}
    definitions::String
    signals::Dict{String,String}

    function SystemConfig(
        id::String,
        connections::Union{Nothing,AbstractVector{Connection}},
        ports::Union{Nothing,Dict{String,String}},
        systems::Union{Nothing,AbstractVector{Union{SystemConfig,Component}}},
        definitions::Union{Nothing,String},
        signals::Union{Nothing,Dict{String,String}}
    )
        systems = something(systems, Union{SystemConfig,Component}[])
        connections = something(connections, Connection[])
        ports = something(ports, Dict{String,String}())
        signals = something(signals, Dict{String,String}())
        definitions = something(definitions, "")
        new(id, connections, ports, systems, definitions, signals)
    end
end


"""    SystemConfigSchema

Defines the schema for a system configuration, used for JSON schema generation.
SystemConfig is recursive and uses a union type for subsystems, which is not
supported by JSONSchemaGenerator. Instead, we set systems: "null" in the schema
and serialize a dummy struct that includes the objects of the union type in the
"\$defs" section. In post-processing, we then replace the dummy with a "\$ref"
to SystemConfigSchema and set the "systems" to "oneOf" with references to both
SystemConfigSchema and Component.
"""
struct SystemConfigSchema
    id::String
    connections::AbstractVector{Connection}
    ports::Dict{String,String}
    systems::Nothing
    definitions::String
    signals::Union{Nothing,Dict{String,String}}

    function SystemConfigSchema(
        id::String,
        connections::AbstractVector{Connection},
        ports::Union{Nothing,Dict{String,String}},
        systems::Nothing,
        definitions::Union{Nothing,String},
        signals::Union{Nothing,Dict{String,String}}
    )
        connections = something(connections, Connection[])
        ports = something(ports, Dict{String,String}())
        signals = something(signals, Dict{String,String}())
        definitions = something(definitions, "")
        new(id, connections, ports, systems, definitions, signals)
    end
end
StructTypes.StructType(::Type{SystemConfigSchema}) = StructTypes.Struct()
StructTypes.omitempties(::Type{SystemConfigSchema}) = (:connections, :ports, :systems, :definitions, :signals,)
