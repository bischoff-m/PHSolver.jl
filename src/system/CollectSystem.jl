
import SparseArrays

function collect_system(config::SystemConfig; keep::Set{Symbol}=Set{Symbol}(), verbose=false)
    started = time()
    result = PhsSystem()
    # Parse components, ids and ports
    collect_components!(result, config)
    verbose && println("[timing] build system components: $(round(time() - started, digits=3)) s")

    stage_started = time()
    # Resolve bare/relative names in rhs_vars to fully-qualified keys
    result.definitions = resolve_namespaces(result.definitions)
    verbose && println("[timing] resolve definition namespaces: $(round(time() - stage_started, digits=3)) s")

    stage_started = time()
    # Resolve definitions
    result.definitions = resolve_definitions(result.definitions; keep=keep, verbose=false)
    verbose && println("[timing] resolve definitions: $(round(time() - stage_started, digits=3)) s")

    stage_started = time()
    # Parse connections and signals
    collect_interactions!(result, config; keep=keep)
    verbose && println("[timing] build interactions and RefFunctions: $(round(time() - stage_started, digits=3)) s")

    if verbose
        interaction_count = SparseArrays.nnz(result.interaction)
        println("[diagnostics] states=$(length(result.ids)), definitions=$(length(result.definitions)), " *
                "RefFunctions=$(length(result.functions)), interactions=$(interaction_count)")
        println("[timing] assemble system total: $(round(time() - started, digits=3)) s")
    end
    return result
end