import Symbolics as Sym

"""
    remove_blocks(expr)

Strip `begin ... end`/`:block` wrappers and line-number metadata that
`Meta.parse` may insert, returning an expression suitable for
`Symbolics.parse_expr_to_symbolic`.

# Examples

```jldoctest
julia> remove_blocks(Meta.parse("begin a = 1 end"))
:(a = 1)
```
"""
function remove_blocks(expr)
    # Work on a copy so the original parsed expression remains unchanged.
    unwrapped = Base.remove_linenums!(deepcopy(expr))

    # Unwrap `begin ... end` / `:block` wrappers until we reach the actual RHS.
    while unwrapped isa Expr && unwrapped.head == :block
        # Ignore any remaining line-number nodes in the block body.
        block_args = [arg for arg in unwrapped.args if !(arg isa LineNumberNode)]
        # A RHS for this use-case must be a single expression.
        if length(block_args) != 1
            error("Expected a single expression in block, got $(length(block_args)) expressions")
        end
        # Replace the block with its only contained expression and continue.
        unwrapped = block_args[1]
    end

    # Return a Symbolics-compatible expression (or literal value).
    unwrapped
end

"""
    parse_expr(expr)

Convert a Julia expression or literal into its Symbolics representation and
collect the `Symbol`s that occur in it.

Internally the expression is passed through [`remove_blocks`](@ref) and then
parsed with `Symbolics.parse_expr_to_symbolic`. Variables are extracted with
`Symbolics.get_variables` and converted to plain `Symbol`s.

# Examples

```jldoctest
julia> parsed, syms = parse_expr(Meta.parse("x + 2y"));

julia> syms
Set([:x, :y])
```
"""
function parse_expr(expr)
    # Remove `begin ... end`/`:block` wrappers and line-number metadata that
    # `Meta.parse` may insert
    expr = remove_blocks(expr)

    # Normalization and constants (e.g. π)
    parsed = Sym.parse_expr_to_symbolic(expr, Base)

    # Get all variables appearing in the expression
    vars = Sym.get_variables(parsed)
    # Convert from BasicSymbolic to Symbol
    symbols = Set{Symbol}(Sym.tosymbol(var) for var in vars)

    return parsed, symbols
end
