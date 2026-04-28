import Symbolics as Sym

"""
    Definition

Container for a parsed formula or assignment.

# Fields
- `symbol::Symbol` - the identifier being defined.
- `lhs_vars::Set{Symbol}` - symbols appearing on the left-hand side of the
   expression (function arguments or bound variables).
- `rhs_vars::Set{Symbol}` - symbols that appear on the right-hand side and
   therefore represent dependencies.
- `eq::Sym.Equation` - the symbolic equation object returned by
   `Symbolics`.

# Examples

```jldoctest
julia> using Symbolics

julia> expr = Meta.parse("f(x) = x^2 + a");

julia> def = PHSolver.expr_to_definition(expr)
Definition(:f, Set([:x]), Set([:a]), Equation(f(x), x^2 + a))
```
"""
struct Definition
    symbol::Symbol
    lhs_vars::Set{Symbol}
    rhs_vars::Set{Symbol}
    eq::Sym.Equation
end

"""
    expr_to_definition(expr::Expr) -> Definition

Parse a Julia expression of the form `lhs = rhs` into a `Definition` object.

The left-hand side may be a variable or a function call; the right-hand side
is any expression that can be handled by `PHSolver.parse_expr`.

Throws an error if the expression is not an assignment or if the LHS contains
symbols not present on the RHS.

# Examples

```jldoctest
julia> expr_to_definition(Meta.parse("g(t) = 3t + b"))
Definition(:g, Set([:t]), Set([:b]), Equation(g(t), 3t + b))
```
"""
function Definition(lhs::Union{Symbol,Expr}, rhs::Union{Number,Symbol,Expr})
    # Parse the LHS and RHS separately
    lhs, lhs_vars = parse_expr(lhs)
    rhs, rhs_vars = parse_expr(rhs)

    name = Sym.tosymbol(Sym.iscall(lhs) ? lhs.f : lhs.val)
    # Remove name from the set of LHS variables, since it's being defined here
    lhs_vars = setdiff(lhs_vars, Set([name]))

    if setdiff(lhs_vars, rhs_vars) != Set{Symbol}()
        error("Variables on the LHS must appear on the RHS. Found: " *
              "$(setdiff(lhs_vars, rhs_vars)) in expression: $lhs = $rhs")
    end

    # Exclude variables defined on the LHS
    rhs_vars = setdiff(rhs_vars, lhs_vars)

    Definition(name, lhs_vars, rhs_vars, Sym.Equation(lhs, rhs))
end

function Definition(expr::Expr)
    if expr.head != :(=)
        error("Expected an assignment expression of the form " *
              "`f(x) = ...` or `f = ...`. Got expression: $expr")
    end
    return Definition(expr.args[1], expr.args[2])
end

function Definition(expr::String)
    # Results in type Expr, which is a Julia expression tree
    parsed = Meta.parse(expr)
    return Definition(parsed)
end

function Definition(sym::Symbol, expr::String)
    parsed = Meta.parse(expr)
    return Definition(sym, parsed)
end

"""
    parse_definitions(exprs::String...) -> Dict{Symbol,Union{Definition,Nothing}}

Given a vector of strings representing equations or assignments, parse each one
and return a dictionary mapping symbols to their `Definition`. Symbols that
appear only on right-hand sides are mapped to `nothing` to indicate free
parameters.

# Examples

```jldoctest
julia> definition_from_expr(["f(x)=a*x"])
Dict(:a=>nothing, :f=>Definition(:f, Set([:x]), Set([:a]), Equation(f(x), a*x)))
```
"""
function definition_from_expr(exprs::String...)
    definitions = Dict{Symbol,Union{Definition,Nothing}}()

    # Parse each expression into a Definition
    for raw_line in exprs
        # Convert to plain String to ensure Meta.parse works
        line = String(raw_line)
        isempty(line) && continue

        # Parse Expr into a Definition struct
        definition = Definition(line)
        if haskey(definitions, definition.symbol)
            error("Redefinition of symbol $(definition.symbol):\n" *
                  "Previous definition: $(definitions[definition.symbol])\n" *
                  "New definition: $definition")
        end
        definitions[definition.symbol] = definition
    end

    # Set missing references to nothing
    rhs_symbols = reduce(
        (acc, def) -> union(acc, def.rhs_vars),
        values(definitions),
        init=Set{Symbol}()
    )
    for sym in rhs_symbols
        haskey(definitions, sym) && continue
        definitions[sym] = nothing
    end

    return definitions
end

"""
    parse_definitions(text::String) -> Dict{Symbol,Union{Definition,Nothing}}

Convenience method to parse a multi-line string of definitions, where each line
is an equation or assignment. Lines starting with `#` are treated as comments
and ignored, as are empty lines and multiline comments.

# Examples

```jldoctest
julia> text = "a = 10\n# This is a comment\nf(x) = a*x"
julia> definition_from_expr(text)
Dict(:a=>nothing, :f=>Definition(:f, Set([:x]), Set([:a]), Equation(f(x), a*x)))
```
"""
function definition_from_expr(text::String)
    # Remove multiline comments
    cleaned = replace(text, r"\"\"\".*\"\"\""s => "")
    lines = split(cleaned, '\n')
    lines = strip.(lines)
    # Remove single-line comments
    lines = filter(line -> !startswith(line, "#"), lines)
    lines = filter(line -> !isempty(line), lines)
    lines = String.(lines)

    return definition_from_expr(lines...)
end