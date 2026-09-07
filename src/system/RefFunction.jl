import Symbolics as Sym

struct RefFunction
    func::Function
    dependencies::AbstractVector{Symbol}
    result_ref::Ref{Float64}
    # Reuse argument storage because reference functions run on every serial DAE residual call.
    args::Vector{Float64}
end

function RefFunction(def::Definition)
    # Sort variables alphabetically for consistent function signatures
    vars_set = union(def.rhs_vars, def.lhs_vars)
    vars = sort(collect(vars_set))
    sym_vars = Sym.variable.(vars)

    # Build the function
    func = Sym.build_function(def.eq.rhs, sym_vars...; expression=false)
    return RefFunction(func, vars, Ref{Float64}(0.0), zeros(Float64, length(vars)))
end

function evaluate(sf::RefFunction, values::Dict{Symbol,<:Real})
    @inbounds for index in eachindex(sf.dependencies)
        sym = sf.dependencies[index]
        haskey(values, sym) || error("Missing value for dependency: $sym")
        sf.args[index] = Float64(values[sym])
    end
    return sf.func(sf.args...)
end

function update_ref!(sf::RefFunction, values::Dict{Symbol,<:Real})
    sf.result_ref[] = evaluate(sf, values)
end

function qualify_state_refs(
    def::Definition,
    state_refs::Set{Symbol},
    scope::Vector{String}
)
    mapping = Dict{Symbol,Symbol}()
    for ref in def.rhs_vars
        ref in def.lhs_vars && continue
        endswith(String(ref), ".x") || continue
        candidates = Symbol.(build_scoped_ids(ref, scope))
        match = findfirst(candidate -> candidate in state_refs, candidates)
        isnothing(match) || (mapping[ref] = candidates[match])
    end
    isempty(mapping) && return def

    substitution = Dict(
        Sym.variable(old) => Sym.variable(new)
        for (old, new) in mapping
    )
    rhs = Sym.substitute(def.eq.rhs, substitution; fold=Val(false))
    rhs_vars = Set(get(mapping, ref, ref) for ref in def.rhs_vars)
    return Definition(def.symbol, def.lhs_vars, rhs_vars, Sym.Equation(def.eq.lhs, rhs))
end

function build_func_or_float(
    sym::Symbol,
    val::Union{Float64,String},
    defs::Definitions;
    scope::Vector{String}=String[],
    keep::Set{Symbol}=Set{Symbol}(),
    state_refs::Set{Symbol}=Set{Symbol}()
)
    if isa(val, Number)
        return Float64(val)
    elseif !isa(val, String)
        error("Unsupported type for $sym: $(typeof(val)). " *
              "Expected Number or String expression.")
    end

    # Parse string to symbolic expression
    def = Definition(sym, val)
    def = qualify_state_refs(def, state_refs, scope)
    def = resolve_definition(def, defs; scope=scope, keep=keep)

    # Check if rhs is fully resolved to a constant
    if isempty(def.rhs_vars)
        f = Sym.build_function(def.eq.rhs; expression=false)
        return Float64(f())
    end

    free_vars = union(def.rhs_vars, def.lhs_vars)
    unresolved = setdiff(free_vars, keep)
    if !isempty(unresolved)
        error("Definition $(def.eq) has dependencies that are unresolved " *
              "and not given as free variables: $unresolved.")
    end
    return RefFunction(def)
end