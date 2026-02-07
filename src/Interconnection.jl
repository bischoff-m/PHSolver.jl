using LinearAlgebra
using SparseArrays
using OrderedCollections

"""
    apply_direct_connection!(
        J::AbstractMatrix,
        B1::AbstractMatrix,
        B2::AbstractMatrix,
        range1::UnitRange{Int},
        range2::UnitRange{Int}
    )

Apply a direct connection \$u_2 = y_1\$ between two subsystems.

This updates the interconnection matrix `J` using the input matrices `B1` and
`B2` for the source and target subsystems, respectively. The ranges select the
state slices for each subsystem in the state vector.
"""
function apply_direct_connection!(
    J::AbstractMatrix{T},
    B1::AbstractMatrix{T},
    B2::AbstractMatrix{T},
    range1::UnitRange{Int},
    range2::UnitRange{Int},
) where {T<:Real}
    J[range2, range1] .+= B2 * B1'
    J[range1, range2] .-= B1 * B2'
end

"""
    apply_negative_feedback_connection!(
        J::AbstractMatrix,
        B1::AbstractMatrix,
        B2::AbstractMatrix,
        range1::UnitRange{Int},
        range2::UnitRange{Int}
    )

Apply a negative feedback connection \$u_2 = -y_1\$.

This is the standard control interconnection that preserves passivity by
updating the skew-symmetric structure in `J`.
"""
function apply_negative_feedback_connection!(
    J::AbstractMatrix{T},
    B1::AbstractMatrix{T},
    B2::AbstractMatrix{T},
    range1::UnitRange{Int},
    range2::UnitRange{Int},
) where {T<:Real}
    J[range2, range1] .-= B2 * B1'
    J[range1, range2] .+= B1 * B2'
end

"""
    apply_skew_symmetric_connection!(
        J::AbstractMatrix,
        B1::AbstractMatrix,
        B2::AbstractMatrix,
        range1::UnitRange{Int},
        range2::UnitRange{Int},
        edge::Connection
    )

Apply a skew-symmetric power-conserving connection between two systems.

The interconnection is:
    [u_1]   [  0    -K ] [y_1]
    [u_2] = [ K^T    0 ] [y_2]

where `K` comes from `edge.coupling_matrix`.
"""
function apply_skew_symmetric_connection!(
    J::AbstractMatrix{T},
    B1::AbstractMatrix{T},
    B2::AbstractMatrix{T},
    range1::UnitRange{Int},
    range2::UnitRange{Int},
    edge::NetworkConnection,
) where {T<:Real}
    K = edge.coupling_matrix
    @assert !isnothing(K) "Skew-symmetric connection requires coupling matrix"

    J[range1, range2] .-= B1 * K * B2'
    J[range2, range1] .+= B2 * K' * B1'
end

"""
    apply_connection!(
        interaction::AbstractMatrix,
        edge::Connection,
        source::PHSNode,
        target::PHSNode
    )

Apply a connection to the interconnection matrix based on `edge.type`.

Supported types: `:direct`, `:negative_feedback`, `:skew_symmetric`.
"""
function apply_connection!(
    interaction::AbstractMatrix{T},
    edge::NetworkConnection,
    source::PHSNode,
    target::PHSNode,
) where {T<:Real}
    # Get state ranges
    range1 = (source.state_offset+1):(source.state_offset+source.state_dim)
    range2 = (target.state_offset+1):(target.state_offset+target.state_dim)

    # Get input/output matrices
    input1 = source.system.input
    input2 = target.system.input

    # Apply based on connection type
    if edge.type == :direct
        apply_direct_connection!(interaction, input1, input2, range1, range2)
    elseif edge.type == :negative_feedback
        apply_negative_feedback_connection!(interaction, input1, input2, range1, range2)
    elseif edge.type == :skew_symmetric
        # For skew-symmetric, we need both nodes symmetrically
        apply_skew_symmetric_connection!(interaction, input1, input2, range1, range2, edge)
    else
        error("Unknown connection type: $(edge.type)")
    end
end
