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
        @assert isdiag(energy) "Energy matrix must be diagonal"
        @assert all(diag(energy) .>= -1e-10) "Energy matrix must be positive semi-definite"
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

"""
    compute_consistent_initial_conditions(
        sys::HamiltonSystem,
        x0_differential::Vector,
        input_func::Function,
        t0::Real = 0.0
    )

Compute consistent initial conditions for a port-Hamiltonian DAE system.

Given initial values for the differential variables, this function:
1. Computes the algebraic variables from the algebraic constraints
2. Computes the initial derivatives for the differential variables

The DAE system is: E * dx = (J - R) * x + B * u(t)

# Arguments
- `sys`: The HamiltonSystem
- `x0_differential`: Initial values for differential variables (where E[i,i] != 0)
- `input_func`: Input function u(t)
- `t0`: Initial time (default: 0.0)

# Returns
- `x0`: Complete initial state vector (differential + algebraic variables)
- `dx0`: Initial derivative vector
- `differential_vars`: Boolean vector indicating which variables are differential

# Example
```julia
# For a system with differential variables [IL, V1, V2] and algebraic [IG, IR]
x0_diff = [1.83, -5.66, -5.48]
u(t) = 0.0
x0, dx0, diff_vars = compute_consistent_initial_conditions(sys, x0_diff, u)
```
"""
function derive_initial_conditions(
    sys::HamiltonSystem{T},
    x0_differential::AbstractVector{T},
    input_func::Function,
    t0::Real=0.0
) where {T<:Real}
    n = state_dimension(sys)
    E = sys.energy
    J = sys.interconnection
    R = sys.dissipation
    B = sys.input

    # Identify differential and algebraic variables
    differential_vars = [E[i, i] != 0.0 for i in 1:n]
    n_differential = sum(differential_vars)

    @assert length(x0_differential) == n_differential "Expected $n_differential differential variables, got $(length(x0_differential))"

    # Build the complete state vector
    x0 = zeros(T, n)
    diff_idx = 1

    # First pass: set differential variables
    for i in 1:n
        if differential_vars[i]
            x0[i] = x0_differential[diff_idx]
            diff_idx += 1
        end
    end

    # Second pass: solve for algebraic variables
    # For each algebraic variable i: 0 = [(J - R) * x + B * u]_i
    # This is a linear system for the algebraic variables
    JminusR = J - R
    u0 = input_func(t0)

    for i in 1:n
        if differential_vars[i]
            continue  # Skip differential variables
        end
        # Algebraic constraint for row i: 0 = sum_j (J-R)[i,j] * x[j] + (B*u)[i]
        # x[i] appears in the sum, so: (J-R)[i,i] * x[i] = -sum_{j!=i} (J-R)[i,j] * x[j] - (B*u)[i]
        rhs = -(B*u0)[i]
        for j in 1:n
            if j != i
                rhs -= JminusR[i, j] * x0[j]
            end
        end

        # Solve for x[i]
        if abs(JminusR[i, i]) > 1e-12
            x0[i] = rhs / JminusR[i, i]
        else
            # If diagonal is zero, we have a more complex constraint
            # For now, set to zero (may need iterative solver for general case)
            x0[i] = zero(T)
            @warn "Algebraic constraint $i has zero diagonal coefficient. Setting x[$i] = 0."
        end
    end

    # Compute initial derivatives for differential variables
    # E * dx = (J - R) * x + B * u
    rhs = JminusR * x0 + B * u0
    dx0 = zeros(T, n)

    for i in 1:n
        if differential_vars[i]
            dx0[i] = rhs[i] / E[i, i]
        end
    end

    return x0, dx0, differential_vars
end
