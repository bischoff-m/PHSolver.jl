function process_definitions(expr::String; keep::Set{Symbol}=Set{Symbol}(), verbose=false)
    # Parse definitions and resolve dependencies
    defs = definition_from_expr(expr)
    graph = DefinitionGraph()
    add_defs!(graph, defs)
    resolve_graph!(graph; keep=keep, verbose=verbose)
    return graph.definitions
end