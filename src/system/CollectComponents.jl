

function build_id(parent::String, child::String)
    return isempty(parent) ? child : parent * "." * child
end

function collect_components!(result::PhsSystem, config::SystemConfig)
    idx = 1
    function handler(config::AbstractSystemConfig, id::String)
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

        idx += 1
    end

    iter_config!(config, handler)
    return nothing
end