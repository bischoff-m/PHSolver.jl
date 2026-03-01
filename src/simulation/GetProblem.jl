import OrdinaryDiffEq as Eq

"""
    nonlinear_resistance!(x::AbstractVector, R::AbstractMatrix)

Example nonlinear resistance update used inside the DAE residual.

This function mutates `R` based on the current state `x` to demonstrate
state-dependent dissipation. It is a placeholder and can be replaced with a
model-specific law.
"""
function nonlinear_resistance!(x::AbstractVector{T}, R::AbstractMatrix{T}) where {T<:Real}
    # Example nonlinear resistance function
    current = abs(x[5])
    # println(current)
    return if current > 1.0 || current < 0.001
        R[5, 5] = T(3.0)
    else
        R[5, 5] = T(10.0)
    end
end

"""
    get_problem(dynamics::SimDynamics, sim_config::SimulationConfig)

Construct a DAE problem for a port-Hamiltonian network.

The residual is \$Q \\dot{x} - (J - R) x - B u(t)\$, with initial derivatives
computed only for differential variables.
"""

function get_problem(
    dynamics::SimDynamics{T},
    sim_config::SimulationConfig
) where {T<:Real}
    # Get matrices
    Q = dynamics.system.mass
    J = dynamics.system.interaction
    R = copy(dynamics.system.dissipation)
    B = dynamics.system.input

    # Compute initial derivatives
    # Q * dx = (J - R) * x + B * u(0)
    dx0 = zeros(T, length(dynamics.x0))
    u0 = dynamics.input_func(sim_config.time_span[1])
    rhs = (J - R) * dynamics.x0 + B * u0

    # Differential variables (non-zero entries in Q)
    differential_vars = [Q[i, i] != 0.0 for i in axes(Q, 1)]

    # Fill in derivatives for differential variables
    for i in eachindex(dx0)
        if differential_vars[i]
            dx0[i] = rhs[i] / Q[i, i]
        end
    end

    # Define DAE residual function (out = 0 at solution)
    function dae_residual!(out, dx, x, p, t)
        u_t = dynamics.input_func(t)
        out .= Q * dx - (J - R) * x - B * u_t
    end

    # Create DAE problem
    return Eq.DAEProblem(
        dae_residual!,
        dx0,
        dynamics.x0,
        sim_config.time_span;
        differential_vars=differential_vars
    )
end