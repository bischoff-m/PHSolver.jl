import OrdinaryDiffEq as Eq


function solve_realtime(sim::PhsSimulation; verbose=false)
    config = sim.state.sim_config
    callback, finalize! = snapshot_callback(sim)
    integrator = Eq.init(sim.problem, sim.solver;
        initializealg=Eq.BrownFullBasicInit(),
        dt=config.output_interval,
        callback=callback,
    )

    t_final = config.time_span[2]
    try
        while integrator.t < t_final
            Eq.step!(integrator, config.output_interval, true)
        end
        return integrator.sol
    finally
        finalize!()
    end
end