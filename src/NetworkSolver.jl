import OrdinaryDiffEq as Eq
import Sundials
import Term
import Logging: global_logger
import TerminalLoggers: TerminalLogger
import ProgressLogging
global_logger(TerminalLogger(right_justify=120))

# function get_problem()
#     # Get matrices
#     Q = system.mass
#     J = system.interconnection
#     R = system.dissipation
#     B = system.input

#     # Compute initial derivatives
#     # Q * dx = (J - R) * x + B * u(0)
#     dx0 = zeros(T, length(x0))
#     u0 = u_func(sim_config.time_span[1])
#     rhs = (J - R) * x0 + B * u0

#     # Fill in derivatives for differential variables
#     for i in eachindex(dx0)
#         if differential_vars[i]
#             dx0[i] = rhs[i] / Q[i, i]
#         end
#     end

#     # Define DAE residual function
#     # residual = Q * dx - (J - R) * x - B * u(t)
#     function dae_residual!(out, dx, x, p, t)
#         u_t = u_func(t)
#         out .= Q * dx - (J - R) * x - B * u_t
#     end

#     # Create DAE problem
#     prob = Eq.DAEProblem(dae_residual!, dx0, x0, sim_config.time_span; differential_vars=differential_vars)
#     return prob, dx0
# end

function solve_phs(
    system::PortHamSystem{T},
    x0::Vector{T},
    differential_vars::Vector{Bool},
    u_func::Function;
    sim_config::SimulationConfigSchema=SimulationConfigDefault,
) where {T<:Real}
    # Get matrices
    Q = system.mass
    J = system.interconnection
    R = system.dissipation
    B = system.input

    # Compute initial derivatives
    # Q * dx = (J - R) * x + B * u(0)
    dx0 = zeros(T, length(x0))
    u0 = u_func(sim_config.time_span[1])
    rhs = (J - R) * x0 + B * u0

    # Fill in derivatives for differential variables
    for i in eachindex(dx0)
        if differential_vars[i]
            dx0[i] = rhs[i] / Q[i, i]
        end
    end

    # Define DAE residual function
    # residual = Q * dx - (J - R) * x - B * u(t)
    function dae_residual!(out, dx, x, p, t)
        u_t = u_func(t)
        out .= Q * dx - (J - R) * x - B * u_t
    end

    # Create DAE problem
    prob = Eq.DAEProblem(dae_residual!, dx0, x0, sim_config.time_span; differential_vars=differential_vars)

    # Select solver
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

supported_solvers = Dict(
    "default" => Sundials.IDA,
    "IDA" => Sundials.IDA,
    "DFBDF" => Eq.DFBDF,
    "DABDF2" => Eq.DABDF2,
    "DImplicitEuler" => Eq.DImplicitEuler,
)

"""
    get_dae_solver(solver_name::String)

Get a DAE solver algorithm by name. See the
[reference](https://docs.sciml.ai/DiffEqDocs/stable/solvers/dae_solve/#OrdinaryDiffEq.jl-(Implicit-ODE)).

Could be extended to support the [DASKR
solver](https://docs.sciml.ai/DiffEqDocs/stable/api/daskr/#daskr) in the future.

# Supported solvers
- "IDA": Sundials IDA (implicit differential-algebraic)
- "DFBDF": OrdinaryDiffEq DFBDF
- "DABDF2": OrdinaryDiffEq DABDF2
- "DImplicitEuler": OrdinaryDiffEq DImplicitEuler

# Arguments
- `solver_name::String`: Name of the solver

# Returns
- Solver algorithm
"""
function get_dae_solver(solver_name::Union{Nothing,String})
    key = isnothing(solver_name) ? "default" : solver_name

    if haskey(supported_solvers, key)
        return supported_solvers[key]()
    end

    fallback = supported_solvers["default"]
    @warn "Unknown solver '$solver_name', using $fallback as default"
    return fallback()
end

struct SimulationResult{T,S<:Eq.SciMLBase.AbstractSolution}
    system::PortHamSystem{T}
    solution::S
    graph::NetworkGraph{T}
end

function simulate_config(config::RootConfigSchema)
    # Load network
    graph = load_network_from_yaml(config, Float64)
    Term.tprintln("  {bold green}✓{/bold green} Loaded network {cyan}$(graph.name){/cyan}")

    # Load configuration
    sim_config = config.network.simulation
    sim_config = isnothing(sim_config) ? SimulationConfigDefault : sim_config
    Term.tprintln("  {bold green}✓{/bold green} Configuration: t=$(sim_config.time_span), solver={cyan}$(sim_config.solver){/cyan}")

    # Assemble network
    system, x0, differential_vars = assemble_network(graph)
    u_func = create_external_input_function(graph, system.input)
    n_nodes = length(graph.nodes)
    n_states = length(x0)
    Term.tprintln("  {bold green}✓{/bold green} Assembled {cyan}$n_nodes{/cyan} nodes → {cyan}$n_states{/cyan} state variables")

    # Solve
    sol = solve_phs(
        system,
        x0,
        differential_vars,
        u_func;
        sim_config=sim_config,
    )
    Term.tprintln("  {bold green}✓{/bold green} Solved DAE: {cyan}$(length(sol.t)){/cyan} time points, t_final={cyan}$(round(sol.t[end], digits=2)){/cyan}")

    return SimulationResult(system, sol, graph)
end

"""
    simulate_network_from_yaml(
        yaml_path::String;
        verbose::Bool = true,
        validate::Bool = true
    )

Complete workflow: load network from YAML, assemble, validate, and solve.

# Arguments
- `yaml_path::String`: Path to YAML configuration file
- `verbose::Bool`: Print progress messages
- `validate::Bool`: Validate network before solving

# Returns
- `SimulationResult`: Struct containing system, solution, graph, and config
"""
function simulate_file(config_path::String)
    config = read_config(config_path)
    return simulate_config(config)
end
