import OrdinaryDiffEq as Eq

struct SimDynamics{T<:Real}
    system::PhsSystem
    x0::AbstractVector{T}
    input_func::Function
end

"""
    get_problem(dynamics::SimDynamics, sim_config::SimulationConfig)

Construct a DAE problem for a port-Hamiltonian network.

The residual is \$E \\dot{x} - (J - R) x - B u(t)\$, with initial derivatives
computed only for differential variables.
"""
# TODO: This is replaced by PhsSimulation
function get_problem(
    dynamics::SimDynamics{T},
    sim_config::SimConfig
) where {T<:Real}
    # Get matrices
    E = dynamics.system.mass
    J = dynamics.system.interaction
    R = dynamics.system.dissipation
    B = dynamics.system.input

    # Compute initial derivatives
    # E * dx = (J - R) * x + B * u(0)
    dx0 = zeros(T, length(dynamics.x0))
    u0 = dynamics.input_func(sim_config.time_span[1])
    rhs = (J - R) * dynamics.x0 + B * u0

    # Differential variables (non-zero entries in E)
    differential_vars = [E[i, i] != 0.0 for i in axes(E, 1)]

    # Fill in derivatives for differential variables
    for i in eachindex(dx0)
        if differential_vars[i]
            dx0[i] = rhs[i] / E[i, i]
        end
    end

    # Define DAE residual function (out = 0 at solution)
    function dae_residual!(out, dx, x, p, t)
        u_t = dynamics.input_func(t)
        out .= E * dx - (J - R) * x - B * u_t
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