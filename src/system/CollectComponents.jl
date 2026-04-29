

function build_id(parts::Union{String,Symbol}...)
    parts = String.(parts)
    res = join(parts, ".")
    # Remove leading dots
    res = replace(res, r"^\.+" => "")
    !isnothing(match(r"\.\.+", res)) && error("ID cannot contain empty parts: $res")
    return res
end

function build_id_sym(parts::Union{String,Symbol}...)
    return Symbol(build_id(parts...))
end

function collect_components!(result::PhsSystem, config::SystemConfig)
    idx = 1
    function handler(config::AbstractSystemConfig, names::Vector{String})
        id = build_id(names...)
        if isa(config, SystemConfig)
            # Add ports as aliases
            for (port_name, target) in config.ports
                port_id = build_id(id, port_name)
                target_id = build_id(id, target)
                result.port_to_index[port_id] = get_index(result, target_id)
            end

            isempty(config.definitions) && return
            # Parse strings to Definitions
            defs = exprs_to_definitions(config.definitions...)
            # Check for overlaps with existing definitions
            overlap = intersect(keys(result.definitions), keys(defs))
            !isempty(overlap) && error("Duplicate definitions for symbols: $(overlap)")
            namespace = build_id(names[1:end-1]...)
            # Prepend namespace to symbols
            for (sym, def) in defs
                if isnothing(def)
                    sym = build_id_sym(namespace, sym)
                else
                    def = prepend_namespace(def, namespace)
                    sym = def.symbol
                end
                result.definitions[sym] = def
            end

            return
        elseif !isa(config, Component)
            error("Unknown config type: $(typeof(config)) for id: `$id`")
        end

        # Add id to index map
        result.id_to_index[id] = idx
        push!(result.ids, id)

        idx += 1
    end

    iter_config!(config, handler)
    return nothing
end