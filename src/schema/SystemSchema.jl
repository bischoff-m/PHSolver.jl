import StructTypes

"""
    System

Defines a system composed of components, their internal connections, and optional ports.

# Fields
- `id::String`: System identifier
- `components::AbstractVector{Component}`: Components in the system
- `connections::AbstractVector{ComponentConnection}`: Internal connections
- `ports::Dict{String,String}`: Mapping from port name to component id (optional)
"""
struct System
    id::String
    components::AbstractVector{Component}
    connections::AbstractVector{ComponentConnection}
    ports::Dict{String,String}

    function System(
        id::String,
        components::AbstractVector{Component},
        connections::AbstractVector{ComponentConnection},
        ports::Union{Nothing,Dict{String,String}}
    )
        ports = something(ports, Dict{String,String}())
        new(id, components, connections, ports)
    end
end
StructTypes.StructType(::Type{System}) = StructTypes.Struct()
StructTypes.omitempties(::Type{System}) = (:ports,)

"""
    SystemPort

References a named port on a specific system.

# Fields
- `system::String`: System identifier
- `port::String`: Port name within the system
"""
struct SystemPort
    system::String
    port::String
end
StructTypes.StructType(::Type{SystemPort}) = StructTypes.Struct()
