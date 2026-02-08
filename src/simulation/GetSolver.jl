import OrdinaryDiffEq as Eq
import Sundials

"""
Dictionary of supported DAE solver names to solver instances.
"""
supported_solvers = Dict(
    "default" => Sundials.IDA(),
    "IDA" => Sundials.IDA(),
    "DFBDF" => Eq.DFBDF(),
    "DABDF2" => Eq.DABDF2(),
    "DImplicitEuler" => Eq.DImplicitEuler(),
)

"""
    get_dae_solver(solver_name::Union{Nothing, String})

Get a DAE solver algorithm by name. See the
[reference](https://docs.sciml.ai/DiffEqDocs/stable/solvers/dae_solve/#OrdinaryDiffEq.jl-(Implicit-ODE)).

Could be extended to support the [DASKR
solver](https://docs.sciml.ai/DiffEqDocs/stable/api/daskr/#daskr) in the future.

# Supported solvers
- "IDA": Sundials IDA (implicit differential-algebraic)
- "DFBDF": OrdinaryDiffEq DFBDF
- "DABDF2": OrdinaryDiffEq DABDF2
- "DImplicitEuler": OrdinaryDiffEq DImplicitEuler

# Arguments
- `solver_name`: Name of the solver (use `nothing` for default)

# Returns
- Solver algorithm
"""
function get_dae_solver(solver_name::Union{Nothing,String})
    key = isnothing(solver_name) ? "default" : solver_name

    if haskey(supported_solvers, key)
        return supported_solvers[key]
    end

    fallback = supported_solvers["default"]
    @warn "Unknown solver '$solver_name', using $fallback as default"
    return fallback()
end
