using LinearAlgebra

# ============================================================================
# Abstract Type Definitions
# ============================================================================

abstract type AbstractModel{T<:Real} end

abstract type AbstractState{T<:Real} end

abstract type AbstractParameters{T<:Real} end

abstract type AbstractSolver{T<:Real} end

# ============================================================================
# Generic Interface Functions (to be implemented by concrete types)
# ============================================================================

function input_dimension(sys::AbstractModel)::Int end

function dynamics!(
    sys::AbstractModel{T},
    state::AbstractState{T},
    input::AbstractVector{T},
    time::T,
) where {T<:Real} end

# ============================================================================
# Default Simulation Parameters Implementation
# ============================================================================

struct EulerParams{T<:Real} <: AbstractParameters{T}
    step_size::T
    n_steps::Int

    function EulerParams(step_size::T, n_steps::Int) where {T<:Real}
        @assert step_size > 0 "Step size must be positive"
        @assert n_steps > 0 "Number of steps must be positive"
        new{T}(step_size, n_steps)
    end
end

# ============================================================================
# Generic Simulation Functions
# ============================================================================

function evolve_step!(
    sys::AbstractModel{T},
    state::AbstractState{T},
    duration::T,
    input::AbstractVector{T},
) where {T<:Real}
    @assert length(input) == input_dimension(sys) "Input dimension mismatch"

    # Compute dynamics (updates state derivative)
    dynamics!(sys, state, input)

    # Forward Euler integration: x(t+dt) = x(t) + ẋ(t) * dt
    x = get_state(state)
    xdot = get_derivative(state)
    set_state!(state, x .+ xdot .* duration)

    return state
end

function evolve(
    sys::AbstractModel{T},
    initial_state::AbstractState{T},
    params::EulerParams{T},
    input_func::Function,
) where {T<:Real}

    # Create a working copy of the initial state
    state = deepcopy(initial_state)

    # Pre-allocate result vector
    states = Vector{typeof(state)}(undef, params.n_steps)

    for i = 1:params.n_steps
        t = (i - 1) * params.step_size
        u = input_func(t)
        evolve_step!(sys, state, params.step_size, u)
        # Store a copy of the current state
        states[i] = deepcopy(state)
    end

    return states
end
