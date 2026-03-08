import Graphs

"""
    DefinitionGraph()

A directed graph of `Definition` objects used to track dependencies between
symbols.  Vertices correspond to symbols; edges point from a dependency to the
symbol that depends on it.

Use `add_defs!`, `add_vertex!`, and friends to construct the graph.  Several
helper functions provide traversal and manipulation.

# Examples

```jldoctest
julia> g = PHSolver.DefinitionGraph()
DefinitionGraph with 0 vertices and 0 edges

julia> defs = PHSolver.parse_defs(["a = 1", "b(x) = 2x + a"]);

julia> PHSolver.add_defs!(g, defs)

julia> @show g
DefinitionGraph with 2 vertices and 1 edges
  Vertex 1: a = 1
  Vertex 2: b(x) = 2x + a | deps: [a]
    Edges: [1]
```
"""
struct DefinitionGraph
    graph::Graphs.DiGraph
    symbol_to_vertex::Dict{Symbol,Int}
    definitions::Dict{Symbol,Union{Definition,Nothing}}

    function DefinitionGraph()
        new(
            Graphs.DiGraph(0),
            Dict{Symbol,Int}(),
            Dict{Symbol,Union{Definition,Nothing}}()
        )
    end

    function Base.show(io::IO, graph::DefinitionGraph)
        println(io, "DefinitionGraph with $(Graphs.nv(graph.graph)) vertices " *
                    "and $(Graphs.ne(graph.graph)) edges")
        f(vars) = join(sort!(string.(collect(vars))), ", ")
        g(vars, a, z) = isempty(vars) ? "" : a * f(vars) * z

        for sym in traverse_order(graph)
            vertex = graph.symbol_to_vertex[sym]
            def = graph.definitions[sym]
            if isnothing(def)
                println(io, "  Vertex $vertex: $sym = nothing")
            else
                lhs_str = g(def.lhs_vars, "(", ")")
                rhs_str = g(def.rhs_vars, " | deps: [", "]")
                println(io, "  Vertex $vertex: $sym$lhs_str = " *
                            "$(def.eq.rhs)$rhs_str")
            end
            edges = Graphs.inneighbors(graph.graph, vertex)
            !isempty(edges) && println(io, "    Edges: $edges")
        end
    end
end

"""
    traverse_order(graph::DefinitionGraph) -> Vector{Symbol}

Return the symbols in a topological order respecting dependencies (i.e. if
`a` depends on `b` then `b` appears before `a`).

This uses a depth-first search on the underlying `Graphs.DiGraph`.

# Examples

```jldoctest
julia> traverse_order(g)
[:a, :b]
```
"""
function traverse_order(graph::DefinitionGraph)
    order = Graphs.topological_sort_by_dfs(graph.graph)
    # Map from vertex ID back to symbol name
    vertex_to_symbol = Dict(vertex => sym for (sym, vertex) in graph.symbol_to_vertex)
    [vertex_to_symbol[v] for v in order]
end

"""
    add_vertex!(graph::DefinitionGraph, sym::Symbol,
                def::Union{Definition,Nothing})

Ensure that `sym` exists as a vertex in `graph`.  If `def` is provided it is
stored; if a definition already exists a conflict error is raised.

The `def` may be `nothing` to indicate a free parameter.

This helper is mainly internal but is exported for completeness.
"""
function add_vertex!(graph::DefinitionGraph, sym::Symbol, def::Union{Definition,Nothing})
    if !haskey(graph.symbol_to_vertex, sym)
        # Add vertex to graph
        Graphs.add_vertex!(graph.graph)
        new_vertex = Graphs.nv(graph.graph)
        graph.symbol_to_vertex[sym] = new_vertex
        graph.definitions[sym] = nothing
    end

    isnothing(def) && return
    if isnothing(graph.definitions[sym])
        # No existing definition, so we can add this one.
        graph.definitions[sym] = def
    elseif graph.definitions[sym] != def
        error("Conflicting definition for symbol $sym:\n" *
              "$sym = $(graph.definitions[sym])\n" *
              "vs\n" *
              "$sym = $def")
    end
end

"""
    add_edge!(graph::DefinitionGraph, from_sym::Symbol, to_sym::Symbol)

Add a directed edge from `from_sym` to `to_sym`.  Both symbols must already be
vertices in `graph`.
"""
function add_edge!(graph::DefinitionGraph, from_sym::Symbol, to_sym::Symbol)
    from_vertex = graph.symbol_to_vertex[from_sym]
    to_vertex = graph.symbol_to_vertex[to_sym]
    Graphs.add_edge!(graph.graph, from_vertex, to_vertex)
end

"""
    rem_edge!(graph::DefinitionGraph, from_sym::Symbol, to_sym::Symbol)

Remove the directed edge `from_sym -> to_sym` if it exists.
"""
function rem_edge!(graph::DefinitionGraph, from_sym::Symbol, to_sym::Symbol)
    from_vertex = graph.symbol_to_vertex[from_sym]
    to_vertex = graph.symbol_to_vertex[to_sym]
    Graphs.rem_edge!(graph.graph, from_vertex, to_vertex)
end

"""
    add_defs!(graph::DefinitionGraph,
              defs::Dict{Symbol,Union{Definition,Nothing}})

Add a batch of definitions to `graph`, creating vertices and edges as
necessary.  Dependencies (`rhs_vars`) generate edges from the dependency to the
defined symbol.  The function also checks for cycles and errors if any are
found.

# Examples

```jldoctest
julia> g = DefinitionGraph();

julia> add_defs!(g, PHSolver.parse_defs(["a=1", "b(a)=2a"]))
```
"""
function add_defs!(graph::DefinitionGraph, defs::Dict{Symbol,Union{Definition,Nothing}})
    for (sym, def) in defs
        # Add new vertex for the symbol
        add_vertex!(graph, sym, def)
        isnothing(def) && continue

        # Add edges from dependencies to this new symbol
        for dep in def.rhs_vars
            if !haskey(graph.symbol_to_vertex, dep)
                add_vertex!(graph, dep, nothing)
            end
            Graphs.add_edge!(graph.graph,
                graph.symbol_to_vertex[dep],
                graph.symbol_to_vertex[sym])
        end
    end

    # Check for cycles after adding new definitions
    if Graphs.is_cyclic(graph.graph)
        for cycle in Graphs.simplecycles(graph.graph)
            cycle_syms = [key for (key, vertex) in graph.symbol_to_vertex if vertex in cycle]
            println("Cycle in definition dependencies after adding definitions: ", cycle_syms)
        end
        error("Cannot add definitions due to cyclic dependencies")
    end
end