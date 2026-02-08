import StructTypes

"""
    NetworkConnection

Defines an interconnection between two systems via their ports.

# Fields
- `from::SystemPort`: Source system/port
- `to::SystemPort`: Target system/port
- `weight::Real`: Connection weight (defaults to 1.0)
"""
struct NetworkConnection
    from::SystemPort
    to::SystemPort
    weight::Real

    function NetworkConnection(
        from::SystemPort,
        to::SystemPort,
        weight::Union{Nothing,Real}
    )
        weight = something(weight, 1.0)
        new(from, to, weight)
    end
end
StructTypes.StructType(::Type{NetworkConnection}) = StructTypes.Struct()
StructTypes.omitempties(::Type{NetworkConnection}) = (:weight,)


"""
    NetworkConfig

Top-level network configuration block.

# Fields
- `name::String`: Network name
- `systems::AbstractVector{System}`: Systems in the network
- `connections::AbstractVector{NetworkConnection}`: System interconnections (optional)
- `ports::Dict{String,SystemPort}`: Named network-level ports (optional)
"""
struct NetworkConfig
    name::String
    systems::AbstractVector{System}
    connections::AbstractVector{NetworkConnection}
    ports::Dict{String,SystemPort}

    function NetworkConfig(
        name::String,
        systems::AbstractVector{System},
        connections::Union{Nothing,AbstractVector{NetworkConnection}},
        ports::Union{Nothing,Dict{String,SystemPort}}
    )
        connections = something(connections, NetworkConnection[])
        ports = something(ports, Dict{String,SystemPort}())
        new(name, systems, connections, ports)
    end
end
StructTypes.StructType(::Type{NetworkConfig}) = StructTypes.Struct()
StructTypes.omitempties(::Type{NetworkConfig}) = (:connections, :ports,)
