using LinearAlgebra
using SparseArrays
using OrderedCollections

"""
    apply_direct_connection!(
        J_global::Matrix,
        node_source::PHSNode,
        node_target::PHSNode,
        edge::Connection
    )

Apply a direct connection: u_target = y_source
This modifies the global interconnection matrix J.

For a direct connection from output of source to input of target,
we add coupling terms in J_global that implement the power-conserving
interconnection.
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
        J_global::Matrix,
        node_source::PHSNode,
        node_target::PHSNode,
        edge::Connection
    )

Apply a negative feedback connection: u_target = -y_source
This is the standard feedback interconnection for control.
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
        J_global::Matrix,
        node1::PHSNode,
        node2::PHSNode,
        edge::Connection
    )

Apply a skew-symmetric power-conserving connection between two systems.

This implements the interconnection:
    [u_1]   [  0    -K ] [y_1]
    [u_2] = [ K^T    0 ] [y_2]

where K is the coupling matrix specified in the edge.
"""
function apply_skew_symmetric_connection!(
    J::AbstractMatrix{T},
    B1::AbstractMatrix{T},
    B2::AbstractMatrix{T},
    range1::UnitRange{Int},
    range2::UnitRange{Int},
    edge::Connection,
) where {T<:Real}
    K = edge.coupling_matrix
    @assert !isnothing(K) "Skew-symmetric connection requires coupling matrix"

    J[range1, range2] .-= B1 * K * B2'
    J[range2, range1] .+= B2 * K' * B1'
end

"""
    apply_connection!(
        J_global::Matrix,
        nodes::OrderedDict{String, PHSNode},
        edge::Connection
    )

Apply a connection to the global interconnection matrix based on connection type.
"""
function apply_connection!(
    interaction::AbstractMatrix{T},
    edge::Connection,
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
