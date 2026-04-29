
function collect_interactions!(
    result::PhsSystem,
    config::SystemConfig,
    defs::Definitions;
    keep=Set{Symbol}()
)
    init_size_dependent_fields!(result)

    function handler(config::AbstractSystemConfig, names::Vector{String})
        id = build_id(names...)
        # Parse component parameters
        if isa(config, Component)
            # Get sibling component IDs (same prefix)
            prefix = build_id(names[1:end-1]...)
            siblings = filter(k -> startswith(k, prefix), result.ids)
            siblings = map(k -> replace(k, r"^" * prefix * "." => ""), siblings)
            # println("$id has siblings: $siblings")

            for sym in [:dissipation, :mass, :input, :x0]
                val = getfield(config, sym)
                id_sym = build_id_sym(id, sym)
                encoded = build_func_or_float(id_sym, val, defs; keep=keep)

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
            ids = Dict("from" => conn.from, "to" => conn.to)
            ids = Dict(k => build_id(id, v) for (k, v) in ids)

            for (key, val) in ids
                haskey(result.id_to_index, val) || error("Connection '$key' id not found: $val")
            end
            ids = Dict(k => result.id_to_index[v] for (k, v) in ids)
            from = ids["from"]
            to = ids["to"]

            if result.interaction[to, from] != 0.0 || result.interaction[from, to] != 0.0
                error("Duplicate connection from $from to $to")
            end

            encoded = build_func_or_float(:weight, conn.weight, defs; keep=keep)
            if isa(encoded, RefFunction)
                push!(result.functions, encoded)
                result.interaction[from, to] = SignedRef(encoded.result_ref, 1.0)
                result.interaction[to, from] = SignedRef(encoded.result_ref, -1.0)
            elseif isa(encoded, AbstractFloat)
                result.interaction[from, to] = encoded
                result.interaction[to, from] = -encoded
            else
                error("Unexpected return type from build_func_or_float for " *
                      "connection weight: $(typeof(encoded))")
            end
        end

        # Parse signals
        for (signal_name, target) in config.signals
            signal_id = build_id(id, signal_name)
            target_idx = get_index(result, signal_id)
            encoded = build_func_or_float(:signal, target, defs; keep=keep)

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

    iter_config!(config, handler)
    return nothing
end