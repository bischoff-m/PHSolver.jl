function process_definitions(expr::AbstractVector{String}; keep::Set{Symbol}=Set{Symbol}(), verbose=false)
    isempty(expr) && return Definitions()
    # Parse definitions and resolve dependencies
    defs = exprs_to_definitions(expr...)
    graph = DefinitionGraph()
    add_defs!(graph, defs)
    resolve_graph!(graph; keep=keep, verbose=verbose)
    return graph.definitions
end