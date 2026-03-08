import Symbolics as Sym
import SymbolicUtils as SymUtils

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
function resolve_parameters!(graph::DefinitionGraph; keep=Set{Symbol}(), verbose=false)
    order = traverse_order(graph)

    # Traverse in topological order, starting with constants (no dependencies)
    for sym in order
        def = graph.definitions[sym]
        verbose && println(
            "\n\nResolving parameters for symbol: ",
            isnothing(def) ? sym : def.eq)
        # Skip free parameters and vars with no dependencies (e.g. constants)
        (sym in keep || isnothing(def) || isempty(def.rhs_vars)) && continue

        free_params = Set{Symbol}()

        # Resolve dependencies in the RHS by substituting definitions for each
        # symbol
        function rewrite(u)
            u_old = u
            # Input is of the form, e.g. f, g(2t), h(2x, a)
            u_sym = Sym.tosymbol(Sym.iscall(u) ? Sym.operation(u) : u)

            # Only consider RHS symbols
            # (skip "+", "*", ..., and variables in the LHS)
            u_sym in def.rhs_vars || return u

            haskey(graph.definitions, u_sym) || error(
                "Symbol $u_sym in expression $u cannot be resolved. " *
                "`resolve_parameters!` assumes that all symbols are " *
                "defined in the graph, even if they are free parameters " *
                "(= nothing).")
            u_def = graph.definitions[u_sym]

            # Skip free parameters
            if isnothing(u_def)
                push!(free_params, u_sym)
                return u
            end

            # Substitute definition into the expression
            if !Sym.iscall(u)
                u = Sym.substitute(u, Dict(u => u_def.eq.rhs))
            else
                # Check for correct number of arguments
                args = Sym.arguments(u)
                lhs_args = Sym.arguments(u_def.eq.lhs)
                length(args) != length(lhs_args) && error(
                    "Argument count mismatch for symbol $(u_def.eq.lhs): " *
                    "expected $(length(lhs_args)), got $(length(args)) in call $u")

                # Substitute arguments into the definition
                u = Sym.substitute(u_def.eq.rhs, Dict(lhs_args .=> args))
            end

            # Add transitive dependencies for free parameters
            for dep in u_def.rhs_vars
                push!(free_params, dep)
                add_edge!(graph, dep, sym)
            end

            # Remove resolved dependency edge from graph
            rem_edge!(graph, u_sym, sym)

            verbose && println("Replace: - | $u_old\n" *
                               "         + | $u")
            return u
        end
        rewriter = SymUtils.Postwalk(rewrite)
        rhs = rewriter(def.eq.rhs)

        rhs_vars = Set{Symbol}(Sym.tosymbol.(Sym.get_variables(rhs)))
        unresolved = setdiff(rhs_vars, union(free_params, def.lhs_vars))
        isempty(unresolved) || error(
            "Unresolved symbols in expression for $sym: $unresolved. " *
            "Could not substitute definitions for these symbols, and they are " *
            "not marked as free parameters or defined on the LHS.")
        rhs = Sym.simplify(rhs)

        # Update definition with the resolved expression and no dependencies
        eq = Sym.Equation(def.eq.lhs, rhs)
        graph.definitions[sym] = Definition(sym, def.lhs_vars, free_params, eq)

        verbose && println("Final expression: ", eq)
    end
end