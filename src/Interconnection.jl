using LinearAlgebra
using SparseArrays

"""
    apply_direct_connection!(
        J_global::Matrix,
        node_source::PHSNode,
        node_target::PHSNode,
        edge::ConnectionEdge
    )

Apply a direct connection: u_target = y_source
This modifies the global interconnection matrix J.

For a direct connection from output of source to input of target,
we add coupling terms in J_global that implement the power-conserving
interconnection.
"""
function apply_direct_connection!(
    J_global::AbstractMatrix{T},
    node_source::PHSNode{T},
    node_target::PHSNode{T},
    edge::ConnectionEdge{T},
) where {T<:Real}
    # Get state ranges
    source_range = get_node_state_range(node_source)
    target_range = get_node_state_range(node_target)

    # Get input/output matrices
    B_source = node_source.system.input
    B_target = node_target.system.input

    # For direct connection, we couple the systems through their ports
    # The coupling must maintain skew-symmetry of J_global

    # Add coupling term: J[target, source] = B_target * B_source^T
    # Add coupling term: J[source, target] = -B_source * B_target^T (for skew-symmetry)

    J_global[target_range, source_range] .+= B_target * B_source'
    J_global[source_range, target_range] .-= B_source * B_target'
end

"""
    apply_negative_feedback_connection!(
        J_global::Matrix,
        node_source::PHSNode,
        node_target::PHSNode,
        edge::ConnectionEdge
    )

Apply a negative feedback connection: u_target = -y_source
This is the standard feedback interconnection for control.
"""
function apply_negative_feedback_connection!(
    J_global::AbstractMatrix{T},
    node_source::PHSNode{T},
    node_target::PHSNode{T},
    edge::ConnectionEdge{T},
) where {T<:Real}
    # Get state ranges
    source_range = get_node_state_range(node_source)
    target_range = get_node_state_range(node_target)

    # Get input/output matrices
    B_source = node_source.system.input
    B_target = node_target.system.input

    # For negative feedback: u_target = -y_source
    # This creates: J[target, source] = -B_target * B_source^T
    #               J[source, target] = B_source * B_target^T (for skew-symmetry)

    J_global[target_range, source_range] .-= B_target * B_source'
    J_global[source_range, target_range] .+= B_source * B_target'
end

"""
    apply_skew_symmetric_connection!(
        J_global::Matrix,
        node1::PHSNode,
        node2::PHSNode,
        edge::ConnectionEdge
    )

Apply a skew-symmetric power-conserving connection between two systems.

This implements the interconnection:
    [u_1]   [  0    -K ] [y_1]
    [u_2] = [ K^T    0 ] [y_2]

where K is the coupling matrix specified in the edge.
"""
function apply_skew_symmetric_connection!(
    J_global::AbstractMatrix{T},
    node1::PHSNode{T},
    node2::PHSNode{T},
    edge::ConnectionEdge{T},
) where {T<:Real}
    @assert !isnothing(edge.coupling_matrix) "Skew-symmetric connection requires coupling matrix"

    K = edge.coupling_matrix

    # Get state ranges
    range1 = get_node_state_range(node1)
    range2 = get_node_state_range(node2)

    # Get input matrices
    B1 = node1.system.input
    B2 = node2.system.input

    # Apply skew-symmetric coupling
    # J[1,2] adds -B1 * K * B2^T
    # J[2,1] adds B2 * K^T * B1^T

    J_global[range1, range2] .-= B1 * K * B2'
    J_global[range2, range1] .+= B2 * K' * B1'
end

"""
    apply_connection!(
        J_global::Matrix,
        nodes::Dict{String, PHSNode},
        edge::ConnectionEdge
    )

Apply a connection to the global interconnection matrix based on connection type.
"""
function apply_connection!(
    J_global::AbstractMatrix{T},
    nodes::Dict{String,PHSNode{T}},
    edge::ConnectionEdge{T},
) where {T<:Real}
    # Get nodes
    source_node = nodes[edge.from_node]
    target_node = nodes[edge.to_node]

    # Apply based on connection type
    if edge.type == :direct
        apply_direct_connection!(J_global, source_node, target_node, edge)
    elseif edge.type == :negative_feedback
        apply_negative_feedback_connection!(J_global, source_node, target_node, edge)
    elseif edge.type == :skew_symmetric
        # For skew-symmetric, we need both nodes symmetrically
        apply_skew_symmetric_connection!(J_global, source_node, target_node, edge)
    else
        error("Unknown connection type: $(edge.type)")
    end
end
