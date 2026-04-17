
function collect_interactions!(
    config::SystemConfig,
    defs::Definitions,
    res_collect::ComponentResult;
    keep=Set{Symbol}()
)
    result = InteractionResult(length(res_collect.id_to_index))
    id_map = res_collect.id_to_index

    function handler(config, id)
        !isa(config, SystemConfig) && return

        # Parse connections
        for conn in config.connections
            ids = Dict("from" => conn.from, "to" => conn.to)
            ids = Dict(k => id * "." * v for (k, v) in ids)

            for (key, val) in ids
                haskey(id_map, val) || error("Connection '$key' id not found: $val")
            end
            ids = Dict(k => id_map[v] for (k, v) in ids)
            from = ids["from"]
            to = ids["to"]

            if result.interaction[to, from] != 0.0 || result.interaction[from, to] != 0.0
                error("Duplicate connection from $from to $to")
            end

            encoded = build_func_or_float(:weight, conn.weight, defs; keep=keep)
            if isa(encoded, StateFunction)
                push!(res_collect.functions, encoded)
                result.interaction[from, to] = SignedRef(encoded.result_ref, 1.0)
                result.interaction[to, from] = SignedRef(encoded.result_ref, -1.0)
            elseif isa(encoded, Float64)
                result.interaction[from, to] = encoded
                result.interaction[to, from] = -encoded
            else
                error("Unexpected return type from build_function for " *
                      "connection weight: $(typeof(encoded))")
            end
        end

        # Parse signals
        for (signal_name, target) in config.signals
            signal_id = id * "." * signal_name
            target_idx = get_index(res_collect, signal_id)
            encoded = build_func_or_float(:signal, target, defs; keep=keep)

            if isa(encoded, StateFunction)
                push!(res_collect.functions, encoded)
                result.input[target_idx] = encoded.result_ref
            elseif isa(encoded, Float64)
                result.input[target_idx] = encoded
            else
                error("Unexpected return type from build_function for " *
                      "signal $signal_id: $(typeof(encoded))")
            end
        end


    end
    iter_config!(config, handler)
    return result
end