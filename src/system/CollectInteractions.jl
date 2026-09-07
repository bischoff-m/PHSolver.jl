
function collect_interactions!(
    result::PhsSystem,
    config::SystemConfig;
    keep=Set{Symbol}()
)
    init_size_dependent_fields!(result)
    defs = result.definitions
    state_refs = Set(Symbol(id * ".x") for id in result.ids)

    function endpoint_indices(id::String)
        if haskey(result.id_to_index, id)
            return [result.id_to_index[id]]
        end

        grouped = [build_id(id, coordinate) for coordinate in ("d", "q")]
        if all(haskey(result.id_to_index, child) for child in grouped)
            return [result.id_to_index[child] for child in grouped]
        end

        error("Connection endpoint id not found: $id")
    end

    function endpoint_pairs(from::Vector{Int}, to::Vector{Int})
        if length(from) == length(to)
            return collect(zip(from, to))
        elseif length(from) == 1
            return [(from[1], target) for target in to]
        elseif length(to) == 1
            return [(source, to[1]) for source in from]
        end

        error("Connection endpoints must have matching d/q dimensions")
    end

    function on_exit(config::AbstractSystemConfig, names::Vector{String})
        id = build_id(names...)
        # Parse component parameters
        if isa(config, Component)
            # Get sibling component IDs (same prefix)
            prefix = build_id(names[1:(end-1)]...)
            siblings = filter(k -> startswith(k, prefix), result.ids)
            siblings = map(k -> replace(k, r"^" * prefix * "." => ""), siblings)
            # println("$id has siblings: $siblings")

            for sym in [:dissipation, :mass, :input, :x0]
                val = getfield(config, sym)
                id_sym = build_id_sym(id, sym)
                encoded = build_func_or_float(
                    id_sym,
                    val,
                    defs;
                    scope=names,
                    keep=union(keep, state_refs),
                    state_refs=state_refs
                )

                container = getfield(result, sym)
                if isa(encoded, RefFunction)
                    push!(result.functions, encoded)
                    push!(container, encoded.result_ref)
                elseif isa(encoded, AbstractFloat)
                    push!(container, encoded)
                else
                    error("Unexpected return type from build_func_or_float for " *
                          "$id_sym: $(typeof(encoded))")
                end
            end

            return
        elseif !isa(config, SystemConfig)
            error("Unknown config type: $(typeof(config)) for id: $id")
        end

        # Parse connections
        for conn in config.connections
            from_id = build_id(id, conn.from)
            to_id = build_id(id, conn.to)
            pairs = endpoint_pairs(endpoint_indices(from_id), endpoint_indices(to_id))

            for (from, to) in pairs
                if result.interaction[to, from] != 0.0 || result.interaction[from, to] != 0.0
                    error("Duplicate connection from $from to $to")
                end
            end

            encoded = build_func_or_float(
                :weight,
                conn.weight,
                defs;
                scope=names,
                keep=union(keep, state_refs),
                state_refs=state_refs
            )
            if isa(encoded, RefFunction)
                push!(result.functions, encoded)
                for (from, to) in pairs
                    result.interaction[from, to] = SignedRef(encoded.result_ref, 1.0)
                    result.interaction[to, from] = SignedRef(encoded.result_ref, -1.0)
                end
            elseif isa(encoded, AbstractFloat)
                for (from, to) in pairs
                    result.interaction[from, to] = encoded
                    result.interaction[to, from] = -encoded
                end
            else
                error("Unexpected return type from build_func_or_float for " *
                      "connection weight: $(typeof(encoded))")
            end
        end

        # Parse signals
        for (signal_name, target) in config.signals
            signal_id = build_id(id, signal_name)
            target_idx = get_index(result, signal_id)
            encoded = build_func_or_float(
                :signal,
                target,
                defs;
                scope=names,
                keep=union(keep, state_refs),
                state_refs=state_refs
            )

            if isa(encoded, RefFunction)
                push!(result.functions, encoded)
                result.signal[target_idx] = encoded.result_ref
            elseif isa(encoded, AbstractFloat)
                result.signal[target_idx] = encoded
            else
                error("Unexpected return type from build_func_or_float for " *
                      "signal $signal_id: $(typeof(encoded))")
            end
        end
    end

    iter_config!(config; on_exit=on_exit)
    return nothing
end