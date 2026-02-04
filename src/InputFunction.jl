using LinearAlgebra
using OrderedCollections


"""
    parse_external_function(expr::String)

Parse a string expression into a Julia function.

Supported expressions:
- "constant(value)": Returns constant value
- "sin(freq*t)" or similar: Evaluates Julia expression with variable t
- "step(t0, value)": Step function at time t0

# Arguments
- `expr::String`: Function expression

# Returns
- Function that takes time `t` and returns the value
"""
# NEEDS REFACTORING, AND ALLOWS RCE
function parse_external_function(expr::String)
    # Remove whitespace
    expr = strip(expr)

    # Match constant(value) pattern
    const_match = match(r"constant\(([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)\)", expr)
    if !isnothing(const_match)
        value = parse(Float64, const_match.captures[1])
        return t -> value
    end

    # Match step(t0, value) pattern
    step_match = match(r"step\(([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?),\s*([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)\)", expr)
    if !isnothing(step_match)
        t0 = parse(Float64, step_match.captures[1])
        value = parse(Float64, step_match.captures[2])
        return t -> t >= t0 ? value : 0.0
    end

    # Otherwise, try to evaluate as Julia expression with variable 't'
    # This is potentially unsafe - in production, use a safer parser
    try
        return eval(Meta.parse("t -> $expr"))
    catch e
        error("Failed to parse input function expression '$expr': $e")
    end
end


"""
    create_external_input_function(graph::NetworkGraph, B::Matrix)

Create an external input function for the network from YAML configuration.

# Arguments
- `graph::NetworkGraph`: Network graph with external input specifications
- `B::Matrix`: Global input matrix

# Returns
- `Function`: u(t) that returns the input vector at time t
"""
function get_input_function(graph::NetworkGraph{T}, input_matrix::AbstractMatrix{T}) where {T<:Real}
    n_inputs = size(input_matrix, 2)

    # Parse all input function expressions
    input_funcs = OrderedDict{String,Function}()
    for ext_input in graph.external_inputs
        input_funcs[ext_input.system] = parse_external_function(ext_input.func)
    end

    # Create global input function
    function u_network(t::Real)
        u = zeros(T, n_inputs)

        input_offset = 0
        for (node_id, node) in graph.nodes
            node_input_dim = input_dimension(node.system)

            # Check if this node has external input
            if haskey(input_funcs, node_id)
                node_u = input_funcs[node_id](t)
                # Handle scalar vs vector input
                if node_u isa Number
                    u[input_offset+1] = node_u
                else
                    u[(input_offset+1):(input_offset+node_input_dim)] .= node_u
                end
            end

            input_offset += node_input_dim
        end

        return u
    end

    return u_network
end
