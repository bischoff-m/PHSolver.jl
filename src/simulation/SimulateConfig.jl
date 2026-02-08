import Term
import Logging: global_logger
import TerminalLoggers: TerminalLogger
global_logger(TerminalLogger(right_justify=120))

"""
    simulate_config(config::RootConfig)

Load, assemble, and solve a network configuration.

Returns a `SimulationResult` containing the solution, assembled system, and
network metadata.
"""
function simulate_config(config::RootConfig)
    # Load network
    network = network_from_config(config.network, Float64)
    sim_config = config.simulation
    Term.tprintln("  {bold green}✓{/bold green} Configuration: t=$(sim_config.time_span), solver={cyan}$(sim_config.solver){/cyan}")

    # Assemble network
    sim_input = build_network(network)
    n_nodes = length(network.nodes)
    n_states = length(sim_input.x0)
    Term.tprintln("  {bold green}✓{/bold green} Assembled {cyan}$n_nodes{/cyan} nodes → {cyan}$n_states{/cyan} state variables")

    # Solve
    sol = solve_phs(sim_input, sim_config=sim_config)
    # sol = solve_phs_realtime(sim_input, sim_config=sim_config)
    Term.tprintln("  {bold green}✓{/bold green} Solved DAE: {cyan}$(length(sol.t)){/cyan} time points, t_final={cyan}$(round(sol.t[end], digits=2)){/cyan}")

    return SimulationResult(sol, sim_input.system, network)
end

"""
    simulate_file(config_path::String)

Complete workflow: read config, assemble the network, and solve it.

# Arguments
- `config_path::String`: Path to the YAML configuration file

# Returns
- `SimulationResult`: Struct containing system, solution, and network metadata
"""
function simulate_file(config_path::String)
    config = read_config(config_path)
    return simulate_config(config)
end
