import Term
import Logging: global_logger
import TerminalLoggers: TerminalLogger
global_logger(TerminalLogger(right_justify=120))

# struct PhsNodeNew
#     id::String
#     systems::Graphs.DiGraph
#     definitions::DefinitionGraph
# end

function iter_config(config::Component, context=Dict{Symbol,Definition}())
    # Build dict of dissipation, mass, and initial state -> definitions
    # Parse expr to symbolic
    # Find RHS dependencies
    # Apply substitutions for given dependencies
    # Build function with remaining dependencies as arguments (in order)
    # Create Ref, function, and dependencies tuple

    # Process component definitions
    for field in (:dissipation, :mass, :x0)
        value = getfield(config, field)
        if value isa Number
        end
    end
    return PortHamSystem([[0.0]],)
end


function iter_config(config::SystemConfig)
    for sys in config.systems
        iter_config(sys)
    end
end

"""
    simulate_config(config::RootConfig)

Load, assemble, and solve a network configuration.

Returns a `SimulationResult` containing the solution, assembled system, and
network metadata.
"""
function simulate_config(config)

    # TODO: Construct entire state matrix with refs in on pass over the config
    # Save functions to calculate state and link them with the matrix entries

    @show config
    # for sys in iter_config(config)
    #     println("System: $(sys.id) isa $(typeof(sys))")
    # end

    # TODO: Construct PhsNodeNew instances and save in a tree
    # https://github.com/JuliaCollections/AbstractTrees.jl/tree/master

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
    println("Loaded configuration from: $config_path")
    return simulate_config(config)
end
# function simulate_file(config_path::String)
#     config = read_config(config_path)
#     println("Loaded configuration from: $config_path")
#     # return simulate_config(config)
#     println("Definitions: ", config.definitions)
#     # Split lines
#     lines = split(config.definitions, '\n')
#     defs = parse_definitions(lines)


#     graph = PHSolver.DefinitionGraph()
#     PHSolver.add_defs!(graph, defs)
#     @show graph

#     PHSolver.resolve_parameters!(graph; keep=Set([:t]), verbose=false)
#     println()
#     @show graph

#     u = Sym.value(graph.definitions[:u].eq.rhs)
#     println("u before evaluation: $u")
#     # u = Sym.evaluate(u, Dict("P" => 10.0, "t" => 5.0))
#     u = Sym.evaluate(u, Dict(Sym.variable(:P) => 10.0, Sym.variable(:t) => 50000.0))
#     println("u = $u")
#     nothing
# end
