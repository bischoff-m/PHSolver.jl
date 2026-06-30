
function collect_system(config::SystemConfig; keep::Set{Symbol}=Set{Symbol}(), verbose=false)
    result = PhsSystem()
    # Parse components, ids and ports
    collect_components!(result, config)
    # Resolve bare/relative names in rhs_vars to fully-qualified keys
    result.definitions = resolve_namespaces(result.definitions)
    # Resolve definitions
    result.definitions = resolve_definitions(result.definitions; keep=keep, verbose=verbose)
    # Parse connections and signals
    collect_interactions!(result, config; keep=keep)

    verbose && pprint(result)
    return result
end