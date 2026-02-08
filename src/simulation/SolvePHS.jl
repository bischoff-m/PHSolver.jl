import OrdinaryDiffEq as Eq

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
    prob = get_problem(dynamics, sim_config)
    solver = get_dae_solver(sim_config.solver)

    dt = isnothing(sim_config.timestep) ? 1 / 2^4 : sim_config.timestep

    integrator = Eq.init(prob, solver;
        initializealg=Eq.BrownFullBasicInit(),
        dt=dt,
    )

    t_final = sim_config.time_span[2]
    while integrator.t < t_final
        Eq.step!(integrator, dt, true)
        # TODO: This was just temporary and needs to be done on the outside
        plot_result(
            SimulationResult(
                integrator.sol,
                dynamics.system,
                Network("Live Plot", OrderedDict{String,PHSNode{T}}(), NetworkConnection[]));
            title="t = $(round(integrator.t, digits=2)) s"
        )
        # Wait for 0.01 seconds to allow plot to update
        # sleep(0.1)
    end

    # Return result
    return integrator.sol
end