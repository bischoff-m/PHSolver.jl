import Term
import Symbolics as Sym
import Logging: global_logger
import TerminalLoggers: TerminalLogger
global_logger(TerminalLogger(right_justify=120))


"""
    simulate_config(config::RootConfig)

Load, assemble, and solve a network configuration.

Returns a `SimulationResult` containing the solution, assembled system, and
network metadata.
"""
function init_simulation(config::SystemConfig; verbose=false)
    fixed_vars = Set([:t])
    # result = make_system(config; keep=fixed_vars, verbose=verbose)

    # state = PhsState(result, SimConfig(), Dict(:t => 0.0))
    # pprint(state)
    sim_config = SimConfig([0.0, 3.0])
    sim = PhsSimulation(config, sim_config; verbose=verbose)
    sol = solve_timespan(sim; verbose=false)
    # plot_result(sol, sim.state.system, sim.state.sim_config; title="Simulation Result")


    # Load network
    # network = network_from_config(config.network, Float64)
    # sim_config = config.simulation
    # Term.tprintln("  {bold green}✓{/bold green} Configuration: t=$(sim_config.time_span), solver={cyan}$(sim_config.solver){/cyan}")

    # # Assemble network
    # sim_input = dynamics_from_network(network)
    # n_nodes = length(network.nodes)
    # n_states = length(sim_input.x0)
    # Term.tprintln("  {bold green}✓{/bold green} Assembled {cyan}$n_nodes{/cyan} nodes → {cyan}$n_states{/cyan} state variables")

    # # Solve
    # sol = solve_phs(sim_input, sim_config=sim_config)
    # # sol = solve_phs_realtime(sim_input, sim_config=sim_config)
    # Term.tprintln("  {bold green}✓{/bold green} Solved DAE: {cyan}$(length(sol.t)){/cyan} time points, t_final={cyan}$(round(sol.t[end], digits=2)){/cyan}")

    # return SimulationResult(sol, sim_input.system, network)
    nothing
end

"""
    init_simulation(config_path::String)

Complete workflow: read config, assemble the network, and solve it.

# Arguments
- `config_path::String`: Path to the YAML configuration file

# Returns
- `SimulationResult`: Struct containing system, solution, and network metadata
"""
function init_simulation(config_path::String; verbose=false)
    config = read_config(config_path)
    verbose && Term.tprintln(
        "Loaded configuration:",
        Term.highlight(config_path, :emphasis)
    )
    return init_simulation(config, verbose=verbose)
end
