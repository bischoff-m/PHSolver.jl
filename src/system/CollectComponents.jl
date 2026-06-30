

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


function build_scoped_ids(name::Union{String,Symbol}, scope::AbstractVector{String})
    return [build_id(scope[1:i]..., name) for i in length(scope):-1:0]
end

function merge_definitions(outer::Definitions, inner::Definitions, scope::AbstractVector{String})
    isempty(inner) && return outer
    namespace = build_id(scope...)
    result = copy(outer)
    for (sym, def) in inner
        # Placeholders from exprs_to_definitions; resolved by resolve_namespaces
        isnothing(def) && continue
        new_sym = build_id_sym(namespace, sym)
        haskey(result, new_sym) && error("Duplicate definition: $new_sym")
        result[new_sym] = Definition(new_sym, def.lhs_vars, def.rhs_vars, def.eq)
    end
    return result
end

function resolve_namespaces(defs::Definitions)
    result = copy(defs)
    for (sym, def) in defs
        isnothing(def) && continue
        # Derive scope from the fully-qualified LHS, e.g. "dc.load.f" → ["dc", "load"]
        scope = String.(split(String(sym), "."))[1:(end-1)]
        isempty(scope) && continue  # root-level definitions need no remapping

        mapping = Dict{Symbol,Symbol}()
        for rhs_var in def.rhs_vars
            rhs_var in def.lhs_vars && continue   # function arguments, not dependencies
            rhs_str = String(rhs_var)
            # Walk up the scope chain, most specific first:
            # e.g. rhs_var = "source.voltage", scope = ["dc", "load"]
            # tries: "dc.load.source.voltage", "dc.source.voltage", "source.voltage"
            candidates = [Symbol(build_id(scope[1:i]..., rhs_str)) for i in length(scope):-1:0]
            found = findfirst(c -> haskey(defs, c), candidates)
            isnothing(found) && continue   # genuinely unresolved, stays as free param
            scoped = candidates[found]
            scoped != rhs_var && (mapping[rhs_var] = scoped)
        end

        isempty(mapping) && continue

        # Rename symbolic variables in the equation to their absolute names
        sym_map = Dict(Sym.variable(k) => Sym.variable(v) for (k, v) in mapping)
        new_rhs = Sym.substitute(def.eq.rhs, sym_map; fold=Val(false))
        new_rhs_vars = Set(get(mapping, v, v) for v in def.rhs_vars)
        result[sym] = Definition(sym, def.lhs_vars, new_rhs_vars, Sym.Equation(def.eq.lhs, new_rhs))
    end
    return result
end

function collect_components!(result::PhsSystem, config::SystemConfig)
    function on_enter(config::AbstractSystemConfig, names::Vector{String})
        (!isa(config, SystemConfig) || isempty(config.definitions)) && return

        # Parse strings to Definitions
        defs = exprs_to_definitions(config.definitions...)
        result.definitions = merge_definitions(result.definitions, defs, names)
    end

    idx = 1
    function on_exit(config::AbstractSystemConfig, names::Vector{String})
        id = build_id(names...)
        if isa(config, SystemConfig)
            # Add ports as aliases
            for (port_name, target) in config.ports
                port_id = build_id(id, port_name)
                target_id = build_id(id, target)
                result.port_to_index[port_id] = get_index(result, target_id)
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

    result.namespace = iter_config!(config; on_enter=on_enter, on_exit=on_exit)
    return nothing
end