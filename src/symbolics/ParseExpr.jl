import Symbolics as Sym


function preprocess_expr(ex)
    return ex
end

function preprocess_expr(ex::Expr)
    args = ex.args

    # Remove line number expressions (see Base.remove_linenums!)
    if ex.head === :block || ex.head === :quote
        args = filter(args) do x
            isa(x, Expr) && x.head === :line && return false
            isa(x, LineNumberNode) && return false
            return true
        end
    end

    # Unwrap blocks
    if ex.head === :block
        if length(args) != 1
            error("Expected a single expression in block, got " *
                  "$(length(args)) expressions:\n" *
                  string(dump(Expr(:block, args...))))
        end
        return preprocess_expr(args[1])
    end

    # Parse identifiers (e.g. `my_id.V1.x`)
    if ex.head === :.
        return Symbol(ex)
    end

    # Recursively format children
    args = map(preprocess_expr, args)
    new_expr = Expr(ex.head, args...)

    return new_expr
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
    expr = preprocess_expr(expr)

    # Normalization and constants (e.g. π)
    # Returns Sym.Num or Sym.BasicSymbolic
    parsed = Sym.parse_expr_to_symbolic(expr, Base)

    # Get all variables appearing in the expression
    vars = Sym.get_variables(parsed)
    # Convert from BasicSymbolic to Symbol
    symbols = Set{Symbol}(Sym.tosymbol(var) for var in vars)

    return parsed, symbols
end
