

function build_id(parent::String, child::String)
    return isempty(parent) ? child : parent * "." * child
end

function collect_components!(
    result::PhsSystem,
    config::SystemConfig,
    defs::Definitions;
    keep::Set{Symbol}=Set{Symbol}()
)
    idx = 1
    function handler(config, id)
        if isa(config, SystemConfig)
            # Add ports as aliases
            for (port_name, target) in config.ports
                port_id = build_id(id, port_name)
                target_id = build_id(id, target)
                result.port_to_index[port_id] = get_index(result, target_id)
            end

            return
        elseif !isa(config, Component)
            error("Unknown config type: $(typeof(config)) for id: $id")
        end

        # Add id to index map
        result.id_to_index[id] = idx
        push!(result.ids, id)

        for sym in [:dissipation, :mass, :input, :x0]
            val = getfield(config, sym)
            id_sym = Symbol(id, ".", sym)
            encoded = build_func_or_float(id_sym, val, defs; keep=keep)

            container = getfield(result, sym)
            if isa(encoded, RefFunction)
                push!(result.functions, encoded)
                push!(container, encoded.result_ref)
            elseif isa(encoded, AbstractFloat)
                push!(container, encoded)
            else
                error("Unexpected return type from build_function: $(typeof(encoded))")
            end
        end
        idx += 1
    end
    result.namespace = iter_config!(config, handler)
end