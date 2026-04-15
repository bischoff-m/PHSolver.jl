using LinearAlgebra
using OrderedCollections


"""
    parse_external_function(expr::String)

Parse a string expression into a time-dependent input function `u(t)`.

Supported forms:
- `constant(value)`: constant scalar output
- `step(t0, value)`: step that switches at `t0`
- Any Julia expression in `t` (e.g., `sin(2*pi*t)`)

Notes:
- The fallback path uses `eval(Meta.parse(...))` and is unsafe for untrusted
    input. This is intended for local, trusted configuration files only.

# Arguments
- `expr::String`: Function expression

# Returns
- A function `u(t)` that returns a scalar or vector value
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
    build_input_func(network::Network{T}, input_matrix::AbstractMatrix{T}) where {T<:Real}

Create a global input function `u(t)` from the network configuration.

Inputs are matched by node id and assembled in the global input order defined
by the block-diagonal input matrix. For now, per-port indices in
`ExternalInput` are not applied; if a node has an external input, the function
is written into the first `input_dimension(system)` entries for that node.

# Arguments
- `network::Network{T}`: Network metadata with external input specifications
- `input_matrix::AbstractMatrix{T}`: Global input matrix for sizing

# Returns
- A function `u(t)` that returns the global input vector at time `t`
"""
function build_input_func(graph::PhsGraph{T}, input_matrix::AbstractMatrix{T}) where {T<:Real}
    n_inputs = size(input_matrix, 2)

    # Parse all input function expressions
    input_funcs = OrderedDict{String,Function}()
    # for ext_input in network.external_inputs
    #     input_funcs[ext_input.system] = parse_external_function(ext_input.func)
    # end

    # Create input function
    function input_function(t::Real)
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

    return input_function
end
