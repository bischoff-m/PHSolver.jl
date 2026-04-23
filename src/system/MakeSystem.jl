
function make_system(config::SystemConfig; keep::Set{Symbol}=Set(), verbose=false)
    defs = process_definitions(config.definitions)

    result = PhsSystem()
    # Parse components, ids and ports
    collect_components!(result, config, defs; keep=keep)
    # Parse connections and signals
    collect_interactions!(result, config, defs; keep=keep)

    verbose && pprint(result)
    return result
end