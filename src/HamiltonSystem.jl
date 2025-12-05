using LinearAlgebra
using OrdinaryDiffEq

# Helper function to check if a matrix is skew-symmetric
function isskewsym(A::AbstractMatrix{<:Real})
    return A ≈ -transpose(A)
end

struct HamiltonSystem{T<:Real} <: AbstractModel{T}
    interconnection::AbstractMatrix{T}
    dissipation::AbstractMatrix{T}
    energy::AbstractMatrix{T}
    input::AbstractMatrix{T}

    function HamiltonSystem(
        interconnection::AbstractMatrix{T},
        dissipation::AbstractMatrix{T},
        energy::AbstractMatrix{T},
        input::AbstractMatrix{T},
    ) where {T<:Real}
        # State dimension
        n = size(energy, 1)

        # Check dimensions
        @assert size(interconnection, 1) == n "Interconnection matrix must have size (n, n)"
        @assert size(interconnection, 2) == n "Interconnection matrix must have size (n, n)"
        @assert size(dissipation, 1) == n "Dissipation matrix must have size (n, n)"
        @assert size(dissipation, 2) == n "Dissipation matrix must have size (n, n)"
        @assert size(energy, 1) == n "Energy matrix must have size (n, n)"
        @assert size(energy, 2) == n "Energy matrix must have size (n, n)"
        @assert size(input, 1) == n "Input matrix must have size (n, m)"

        # Check properties
        @assert issymmetric(dissipation) "Dissipation matrix must be symmetric"
        @assert all(eigvals(dissipation) .>= -1e-10) "Dissipation matrix must be positive semi-definite"
        @assert issymmetric(energy) "Energy matrix must be symmetric"
        # @assert isposdef(energy) "Energy matrix must be positive definite"
        @assert isskewsym(interconnection) "Interconnection matrix must be skew-symmetric"

        new{T}(interconnection, dissipation, energy, input)
    end
end

state_dimension(sys::HamiltonSystem) = size(sys.energy, 1)
input_dimension(sys::HamiltonSystem) = size(sys.input, 2)

mutable struct HamiltonState{T<:Real} <: AbstractState{T}
    state::Vector{T}
    state_derivative::Vector{T}
    output::Vector{T}

    function HamiltonState(
        state::Vector{T},
        state_derivative::Vector{T},
        output::Vector{T},
    ) where {T<:Real}
        @assert length(state) == length(state_derivative) "State and derivative must have same dimension"
        new{T}(state, state_derivative, output)
    end
end

# Convenience constructor
HamiltonState(
    state::AbstractVector{T},
    state_derivative::AbstractVector{T},
    output::AbstractVector{T},
) where {T<:Real} =
    HamiltonState(Vector{T}(state), Vector{T}(state_derivative), Vector{T}(output))

# Implement state access interface
get_state(state::HamiltonState{T}) where {T<:Real} = state.state
set_state!(state::HamiltonState{T}, x::AbstractVector{T}) where {T<:Real} =
    (state.state .= x)
get_derivative(state::HamiltonState{T}) where {T<:Real} = state.state_derivative
set_derivative!(state::HamiltonState{T}, xdot::AbstractVector{T}) where {T<:Real} =
    (state.state_derivative .= xdot)

# Optional: getter for output
get_output(state::HamiltonState{T}) where {T<:Real} = state.output
set_output!(state::HamiltonState{T}, y::AbstractVector{T}) where {T<:Real} =
    (state.output .= y)

function dynamics!(
    sys::HamiltonSystem{T},
    state::HamiltonState{T},
    input::AbstractVector{T},
) where {T<:Real}
    @assert length(state.state) == state_dimension(sys) "State dimension mismatch"
    @assert length(input) == input_dimension(sys) "Input dimension mismatch"

    # Compute the Hamiltonian gradient: ∇H(x) = Q x
    dH_dx = sys.energy * state.state

    # Compute state derivative: ẋ = (J - R) ∇H(x) + B u
    state.state_derivative .=
        (sys.interconnection - sys.dissipation) * dH_dx + sys.input * input

    # Compute output: y = Bᵀ ∇H(x)
    state.output .= transpose(sys.input) * dH_dx

    return nothing
end

# ============================================================================
# Legacy API (backward compatibility)
# ============================================================================

function evolve_step(
    sys::HamiltonSystem{T},
    state::HamiltonState{T},
    duration::T,
    input::AbstractVector{T},
) where {T<:Real}
    return evolve_step!(sys, state, duration, input)
end

function evolve(
    sys::HamiltonSystem{T},
    state::HamiltonState{T},
    step_size::T,
    n_steps::Int,
    input_func::Function,
) where {T<:Real}
    params = EulerParams(step_size, n_steps)
    return evolve(sys, state, params, input_func)
end

# ============================================================================
# DAE Solver Integration
# ============================================================================

"""
    create_dae_function(sys::HamiltonSystem, input_func::Function)

Create a DAE function for use with DifferentialEquations.jl.

Port-Hamiltonian systems have the form:
    Q * dx/dt = (J - R) * Q * x + B * u(t)
    y = B^T * Q * x

This is a mass-matrix DAE: M * dx/dt = f(x, p, t) where M = Q (energy matrix).

Returns an ODEFunction with mass_matrix set.
"""
function create_dae_function(sys::HamiltonSystem{T}, input_func::Function) where {T<:Real}
    function dae_rhs!(dx, x, p, t)
        # Get input at current time
        u = input_func(t)

        # Compute the Hamiltonian gradient: ∇H(x) = Q x
        dH_dx = sys.energy * x

        # Compute right-hand side: (J - R) ∇H(x) + B u
        # Note: The mass matrix Q will multiply dx/dt on the left side
        dx .= (sys.interconnection - sys.dissipation) * dH_dx + sys.input * u

        return nothing
    end

    # Create ODEFunction with mass matrix (energy matrix Q)
    return ODEFunction(dae_rhs!, mass_matrix=sys.energy)
end

"""
    solve_dae(sys::HamiltonSystem, x0::Vector, tspan::Tuple, input_func::Function; 
              solver=Rodas5(), kwargs...)

Solve the port-Hamiltonian system as a DAE using DifferentialEquations.jl.

# Arguments
- `sys`: HamiltonSystem to solve
- `x0`: Initial state vector
- `tspan`: Time span tuple (t0, tf)
- `input_func`: Function u(t) that returns input vector at time t
- `solver`: DAE solver to use (default: Rodas5())
- `kwargs...`: Additional keyword arguments passed to solve()

# Returns
- Solution object from DifferentialEquations.jl

# Example
```julia
sys = HamiltonSystem(J, R, Q, B)
x0 = [1.0, 0.0]
u(t) = [sin(t)]
sol = solve_dae(sys, x0, (0.0, 10.0), u)
```
"""
function solve_dae(
    sys::HamiltonSystem{T},
    x0::AbstractVector{T},
    tspan::Tuple{T,T},
    input_func::Function;
    solver=Rodas5(),
    kwargs...
) where {T<:Real}
    @assert length(x0) == state_dimension(sys) "Initial state dimension mismatch"

    # Create DAE function with mass matrix
    f = create_dae_function(sys, input_func)

    # Create and solve ODE problem with mass matrix
    prob = ODEProblem(f, x0, tspan)
    sol = solve(prob, solver; kwargs...)

    return sol
end

"""
    compute_hamiltonian(sys::HamiltonSystem, x::Vector)

Compute the Hamiltonian (energy) of the system: H(x) = 0.5 * x^T * Q * x
"""
function compute_hamiltonian(sys::HamiltonSystem{T}, x::AbstractVector{T}) where {T<:Real}
    return 0.5 * dot(x, sys.energy * x)
end

"""
    compute_output(sys::HamiltonSystem, x::Vector)

Compute the output of the system: y = B^T * Q * x
"""
function compute_output(sys::HamiltonSystem{T}, x::AbstractVector{T}) where {T<:Real}
    dH_dx = sys.energy * x
    return transpose(sys.input) * dH_dx
end
