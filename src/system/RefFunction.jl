import Symbolics as Sym

struct RefFunction
    func::Function
    dependencies::AbstractVector{Symbol}
    result_ref::Ref{Float64}
end

function RefFunction(def::Definition)
    # Sort variables alphabetically for consistent function signatures
    vars_set = union(def.rhs_vars, def.lhs_vars)
    vars = sort(collect(vars_set))
    sym_vars = Sym.variable.(vars)

    # Build the function
    func = Sym.build_function(def.eq.rhs, sym_vars...; expression=false)
    return RefFunction(func, vars, Ref{Float64}(0.0))
end

function evaluate(sf::RefFunction, values::Dict{Symbol,<:Real})
    args = map(sf.dependencies) do sym
        haskey(values, sym) || error("Missing value for dependency: $sym")
        Float64(values[sym])
    end
    return sf.func(args...)
end

function update_ref!(sf::RefFunction, values::Dict{Symbol,<:Real})
    sf.result_ref[] = evaluate(sf, values)
end

function build_func_or_float(
    sym::Symbol,
    val::Union{Float64,String},
    defs::Definitions;
    keep::Set{Symbol}=Set{Symbol}()
)
    if isa(val, Number)
        return Float64(val)
    elseif !isa(val, String)
        error("Unsupported type for $sym: $(typeof(val)). " *
              "Expected Number or String expression.")
    end

    # Parse string to symbolic expression
    def = Definition(sym, val)
    def = resolve_definition(def, defs; keep=keep)

    # Check if rhs is fully resolved to a constant
    if isempty(def.rhs_vars)
        f = Sym.build_function(def.eq.rhs; expression=false)
        return Float64(f())
    end

    free_vars = union(def.rhs_vars, def.lhs_vars)
    unresolved = setdiff(free_vars, keep)
    if !isempty(unresolved)
        error("Definition $(def.eq) has dependencies that are " *
              "not fixed variables: $unresolved.")
    end
    return RefFunction(def)
end