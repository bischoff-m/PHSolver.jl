"""
Example: Creating a Custom Dynamical System using the Generic Framework

This example demonstrates how to extend the HamiltonSim framework to create
your own custom dynamical system types. We'll implement a simple linear
state-space system as an example.

The key steps are:
1. Define a concrete system type <: AbstractDynamicalSystem{T}
2. Define a concrete state type <: AbstractSystemState{T}
3. Implement the required interface methods
4. Use the generic simulation functions
"""

using HamiltonSim
using LinearAlgebra
using Printf

# ============================================================================
# Step 1: Define a custom system type
# ============================================================================

"""
    LinearStateSpaceSystem{T<:Real} <: AbstractDynamicalSystem{T}

A linear state-space system with dynamics:
    ẋ = A x + B u
    y = C x + D u

# Fields
- `A::Matrix{T}`: State matrix (n × n)
- `B::Matrix{T}`: Input matrix (n × m)
- `C::Matrix{T}`: Output matrix (p × n)
- `D::Matrix{T}`: Feedthrough matrix (p × m)
"""
struct LinearStateSpaceSystem{T<:Real} <: AbstractDynamicalSystem{T}
    A::Matrix{T}
    B::Matrix{T}
    C::Matrix{T}
    D::Matrix{T}

    function LinearStateSpaceSystem(A::Matrix{T}, B::Matrix{T},
        C::Matrix{T}, D::Matrix{T}) where T<:Real
        n = size(A, 1)
        m = size(B, 2)
        p = size(C, 1)

        @assert size(A) == (n, n) "A must be square"
        @assert size(B, 1) == n "B must have $n rows"
        @assert size(C, 2) == n "C must have $n columns"
        @assert size(D) == (p, m) "D must have size ($p, $m)"

        new{T}(A, B, C, D)
    end
end

# Implement required interface methods
HamiltonSim.state_dimension(sys::LinearStateSpaceSystem) = size(sys.A, 1)
HamiltonSim.input_dimension(sys::LinearStateSpaceSystem) = size(sys.B, 2)

# ============================================================================
# Step 2: Define a custom state type
# ============================================================================

"""
    LinearSystemState{T<:Real} <: AbstractSystemState{T}

State representation for a linear state-space system.

# Fields
- `x::Vector{T}`: State vector
- `xdot::Vector{T}`: State derivative
- `y::Vector{T}`: Output vector
"""
mutable struct LinearSystemState{T<:Real} <: AbstractSystemState{T}
    x::Vector{T}
    xdot::Vector{T}
    y::Vector{T}
end

# Implement state access interface
HamiltonSim.get_state(state::LinearSystemState{T}) where T<:Real = state.x
HamiltonSim.set_state!(state::LinearSystemState{T}, x::AbstractVector{T}) where T<:Real = (state.x .= x)
HamiltonSim.get_derivative(state::LinearSystemState{T}) where T<:Real = state.xdot
HamiltonSim.set_derivative!(state::LinearSystemState{T}, xdot::AbstractVector{T}) where T<:Real = (state.xdot .= xdot)

# ============================================================================
# Step 3: Implement the dynamics
# ============================================================================

"""
    dynamics!(sys::LinearStateSpaceSystem{T}, 
              state::LinearSystemState{T}, 
              input::AbstractVector{T}) where T<:Real

Compute linear state-space dynamics:
    ẋ = A x + B u
    y = C x + D u
"""
function HamiltonSim.dynamics!(sys::LinearStateSpaceSystem{T},
    state::LinearSystemState{T},
    input::AbstractVector{T}) where T<:Real
    # Compute state derivative: ẋ = A x + B u
    state.xdot .= sys.A * state.x + sys.B * input

    # Compute output: y = C x + D u
    state.y .= sys.C * state.x + sys.D * input

    return nothing
end

# ============================================================================
# Example Usage
# ============================================================================

println("="^70)
println("Custom Linear State-Space System Example")
println("="^70)

# Define a simple mass-spring-damper system in state-space form
# State: [position, velocity]
# ẋ = [0  1] x + [0]
#     [-k -c]     [1/m] u
#
# where k = spring constant, c = damping, m = mass

m, k, c = 1.0, 2.0, 0.5  # mass, stiffness, damping

A = [0.0 1.0;
    -k/m -c/m]
B = reshape([0.0, 1.0 / m], 2, 1)
C = [1.0 0.0]  # Output is position only
D = zeros(1, 1)

# Create the system
sys = LinearStateSpaceSystem(A, B, C, D)

println("\nSystem matrices:")
println("A = ", A)
println("B = ", B)
println("C = ", C)
println("D = ", D)

# Create initial state
x0 = [1.0, 0.0]  # Initial position = 1.0, velocity = 0.0
xdot0 = zeros(2)
y0 = zeros(1)
initial_state = LinearSystemState(x0, xdot0, y0)

println("\nInitial state: x = ", x0)

# Define input function (zero input - free response)
u_func(t) = [0.0]

# Simulation parameters
params = EulerParams(0.01, 500)  # dt = 0.01, n_steps = 500

# Run simulation using the generic evolve function!
println("\nRunning simulation with ", params.n_steps, " steps, dt = ", params.step_size)
states = evolve(sys, initial_state, params, u_func)

# Extract results
positions = [s.x[1] for s in states]
velocities = [s.x[2] for s in states]
times = [(i - 1) * params.step_size for i in 1:params.n_steps]

println("\nFinal state:")
println("  Position: ", states[end].x[1])
println("  Velocity: ", states[end].x[2])
println("  Output:   ", states[end].y[1])

# Print some intermediate results
println("\nSample trajectory (every 100 steps):")
println("  Time    Position   Velocity")
for i in 1:100:params.n_steps
    @printf("  %.2f    %8.5f   %8.5f\n", times[i], positions[i], velocities[i])
end

println("\n" * "="^70)
println("Comparison with PortHamSystem")
println("="^70)

# The same system as a Port-Hamiltonian system
# For a mass-spring-damper: H(x) = (1/2)k*x₁² + (1/2)m*x₂²
# with x = [position, momentum/m]

Q = [k 0.0; 0.0 m]  # Energy matrix
J = [0.0 1.0; -1.0 0.0]  # Interconnection (skew-symmetric)
R = [0.0 0.0; 0.0 c]  # Dissipation
B_ham = reshape([0.0, 1.0], 2, 1)  # Input matrix

ham_sys = PortHamSystem(J, R, Q, B_ham)
ham_state = HamiltonState([1.0, 0.0], zeros(2), zeros(1))

println("\nRunning Hamilton system simulation...")
ham_states = evolve(ham_sys, ham_state, params, u_func)

ham_positions = [s.state[1] for s in ham_states]
ham_velocities = [s.state[2] for s in ham_states]

println("\nFinal state (Hamilton):")
println("  Position: ", ham_states[end].state[1])
println("  Velocity: ", ham_states[end].state[2])

println("\n" * "="^70)
println("Both systems use the same generic simulation framework!")
println("="^70)
