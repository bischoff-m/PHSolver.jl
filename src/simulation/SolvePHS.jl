import OrdinaryDiffEq as Eq

"""
    init_solver(dynamics::SimDynamics; sim_config::SimulationConfig)

Initialize a DAE integrator for stepping the solver externally.

Returns `(integrator, dt)` where `dt` is the step size used by default.
"""
function init_solver(
    dynamics::SimDynamics{T};
    sim_config::SimulationConfig,
) where {T<:Real}
    prob = get_problem(dynamics, sim_config)
    solver = get_dae_solver(sim_config.solver)

    integrator = Eq.init(prob, solver;
        initializealg=Eq.BrownFullBasicInit(),
        dt=sim_config.timestep,
    )

    return integrator
end

"""
    step_solver!(integrator, dt)

Advance the integrator by one step and return `(t, u)`.
"""
function step_solver!(integrator, dt::Real)
    Eq.step!(integrator, dt, true)
    return integrator.t, integrator.u
end

"""
    solve_phs(dynamics::SimDynamics; sim_config=SimulationConfigDefault)

Solve the assembled DAE and return the SciML solution object.

If `sim_config.timestep` is provided, the solver output is sampled at that
fixed interval via `saveat`.
"""
function solve_phs(
    dynamics::SimDynamics{T};
    sim_config::SimulationConfig,
) where {T<:Real}
    # Get problem and solver
    prob = get_problem(dynamics, sim_config)
    solver = get_dae_solver(sim_config.solver)

    # Solve with automatic initialization
    # If timestep is specified, use saveat to control output times
    sol = Eq.solve(prob, solver;
        initializealg=Eq.BrownFullBasicInit(),
        progress=true,
        progress_name="Solver",
        (isnothing(sim_config.timestep) ? (;) :
         (saveat=sim_config.timestep,))...
    )

    return sol
end

"""
    solve_phs_realtime(dynamics::SimDynamics; sim_config::SimulationConfig)

Solve the DAE while plotting the state trajectories in (near) real time.

This advances the integrator in fixed steps and updates the plot after each
step. Useful for interactive exploration.
"""
function solve_phs_realtime(
    dynamics::SimDynamics{T};
    sim_config::SimulationConfig,
) where {T<:Real}
    integrator = init_solver(dynamics; sim_config=sim_config)

    t_final = sim_config.time_span[2]
    while integrator.t < t_final
        step_solver!(integrator, sim_config.timestep)
        # TODO: This is just temporary and needs to be done on the outside
        plot_result(
            SimulationResult(
                integrator.sol,
                dynamics.system,
                Network("Live Plot", OrderedDict{String,PhsNodeOld{T}}(), NetworkConnection[])
            );
            title="t = $(round(integrator.t, digits=2)) s"
        )
    end

    # Return result
    return integrator.sol
end