import Symbolics as Sym
import SymbolicUtils as SymUtils

# Resolve dependencies in the RHS by substituting definitions for each
# symbol
function rewrite(
    expr,
    context::Definitions,
    keep::Set{Symbol}=Set{Symbol}(),
    verbose::Bool=false
)
    expr_old = expr
    # Input is of the form, e.g. f, g(2t), h(2x, a)
    sym = Sym.tosymbol(Sym.iscall(expr) ? Sym.operation(expr) : expr)

    # Only rewrite symbols relevant to the current definition.
    sym in keep && return expr

    haskey(context, sym) || return expr
    u_def = context[sym]

    # Skip free parameters
    isnothing(u_def) && return expr
    args = Sym.iscall(expr) ? Sym.arguments(expr) : []
    n_args = length(args)
    length(u_def.lhs_vars) != n_args && error(
        "Argument count mismatch for symbol $(u_def.eq.lhs): " *
        "expected $(length(u_def.lhs_vars)), got $n_args in call $expr")


    # Substitute definition into the expression
    if n_args == 0
        expr = Sym.substitute(expr, Dict(expr => u_def.eq.rhs); fold=Val(false))
    else
        # Substitute arguments into the definition
        lhs_args = Sym.arguments(u_def.eq.lhs)
        expr = Sym.substitute(u_def.eq.rhs, Dict(lhs_args .=> args); fold=Val(false))
    end

    verbose && println("Replace: - | $expr_old\n" *
                       "         + | $expr")
    return expr
end

function resolve_definition(
    def::Definition,
    given::Definitions;
    keep=Set{Symbol}(),
    verbose=false
)
    sym = def.symbol
    verbose && println("\n\nResolving ", isnothing(def) ? sym : def.eq)

    # Return constants
    isempty(def.rhs_vars) && return def

    # Walk the expression tree and resolve dependencies in the RHS by
    # substituting definitions for each symbol
    function rewrite_wrapper(u)
        rewrite(u, given, keep, verbose)
    end
    rewriter = SymUtils.Postwalk(rewrite_wrapper)
    rhs = rewriter(def.eq.rhs)

    # Check for remaining unresolved symbols
    rhs_vars = Set{Symbol}(Sym.tosymbol.(Sym.get_variables(rhs)))

    # Get free parameters
    free_params = filter(v -> !(v in def.lhs_vars), rhs_vars)

    unresolved = setdiff(rhs_vars, union(free_params, def.lhs_vars))
    isempty(unresolved) || error(
        "Unresolved symbols in expression for $sym: $unresolved. " *
        "Could not substitute definitions for these symbols, and they are " *
        "not marked as free parameters or defined on the LHS.")

    # Update definition with the resolved expression and no dependencies
    rhs = Sym.simplify(rhs)
    eq = Sym.Equation(def.eq.lhs, rhs)
    verbose && println("Final expression: ", eq, " [deps: $free_params]")

    return Definition(sym, def.lhs_vars, free_params, eq)
end


"""
    resolve_parameters!(graph::DefinitionGraph; keep=Set{Symbol}(), verbose=false)

Substitute definitions into one another within `graph` in topological order,
eliminating dependencies where possible and collecting free parameters.

`keep` is a set of symbols that should not be resolved (e.g. independent
variables such as `t`).  When a RHS symbol has no definition (i.e. `nothing`)
it is treated as a free parameter.

`verbose=true` prints each substitution step.

# Examples

```jldoctest
julia> g = DefinitionGraph();

julia> add_defs!(g, PHSolver.parse_defs(["a = 3", "f(x)=a*x"]));

julia> @show g
DefinitionGraph with 2 vertices and 1 edges
  Vertex 1: a = 3
  Vertex 2: f(x) = a * x | deps: [a]
    Edges: [1]

julia> resolve_parameters!(g; keep=Set([:x]))

julia> @show g
DefinitionGraph with 2 vertices and 0 edges
  Vertex 1: a = 3
  Vertex 2: f(x) = 3 * x
```
"""
function resolve_graph!(graph::DefinitionGraph; keep=Set{Symbol}(), verbose=false)
    order = traverse_order(graph)

    # Traverse in topological order, starting with constants (no dependencies)
    for sym in order
        def = graph.definitions[sym]
        (sym in keep || isnothing(def) || isempty(def.rhs_vars)) && continue

        old_deps = copy(def.rhs_vars)
        resolved_def = resolve_definition(def, graph.definitions; keep=keep, verbose=verbose)
        reconcile_dependency_edges!(graph, sym, old_deps, resolved_def.rhs_vars)
        graph.definitions[sym] = resolved_def
    end
end
