"""
    apply_connection!(
        interaction::AbstractMatrix,
        connection::NetworkConnection,
        source::PhsNode,
        target::PhsNode
    )

Apply a connection between two system ports by updating the interconnection
matrix `J` directly.

The port indices are resolved via `source.ports` and `target.ports`, and the
connection weight determines the magnitude of the skew-symmetric update.
"""
function apply_connection!(
    interaction::AbstractMatrix{T},
    connection,
    source::PhsNodeOld,
    target::PhsNodeOld,
) where {T<:Real}
    source_port = get(source.ports, connection.from.port, nothing)
    target_port = get(target.ports, connection.to.port, nothing)

    if isnothing(source_port)
        error("Unknown source port '$(connection.from.port)' for system '$(source.id)'")
    end
    if isnothing(target_port)
        error("Unknown target port '$(connection.to.port)' for system '$(target.id)'")
    end

    source_idx = source.state_offset + source_port
    target_idx = target.state_offset + target_port
    weight = T(connection.weight)

    interaction[target_idx, source_idx] += weight
    interaction[source_idx, target_idx] -= weight
end
