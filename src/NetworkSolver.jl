import OrdinaryDiffEq as Eq
import Sundials
import Term
import Logging: global_logger
import TerminalLoggers: TerminalLogger
import ProgressLogging
global_logger(TerminalLogger(right_justify=120))

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

function get_problem(dynamics::SimDynamics{T}, sim_config::SimulationConfig) where {T<:Real}
    system = dynamics.system
    # Get matrices
    Q = system.mass
    J = system.interaction
    R = copy(system.dissipation)
    B = system.input

    # Compute initial derivatives
    # Q * dx = (J - R) * x + B * u(0)
    dx0 = zeros(T, length(dynamics.x0))
    u0 = dynamics.input_func(sim_config.time_span[1])
    rhs = (J - R) * dynamics.x0 + B * u0

    # Fill in derivatives for differential variables
    for i in eachindex(dx0)
        if dynamics.differential_vars[i]
            dx0[i] = rhs[i] / Q[i, i]
        end
    end

    # Define DAE residual function
    # residual = Q * dx - (J - R) * x - B * u(t)
    function dae_residual!(out, dx, x, p, t)
        nonlinear_resistance!(x, R)
        u_t = dynamics.input_func(t)
        out .= Q * dx - (J - R) * x - B * u_t
    end

    # Create DAE problem
    return Eq.DAEProblem(
        dae_residual!,
        dx0,
        dynamics.x0,
        sim_config.time_span;
        differential_vars=dynamics.differential_vars
    )
end

function solve_phs(
    dynamics::SimDynamics{T};
    sim_config::SimulationConfig=SimulationConfigDefault,
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

function solve_phs_realtime(
    dynamics::SimDynamics{T};
    sim_config::SimulationConfig=SimulationConfigDefault,
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
        plot_result(
            SimulationResult(
                integrator.sol,
                dynamics.system,
                NetworkGraph("Live Plot", OrderedDict{String,PHSNode{T}}(), Connection[], ExternalInput[]));
            title="t = $(round(integrator.t, digits=2)) s"
        )
        # Wait for 0.01 seconds to allow plot to update
        sleep(0.1)
    end

    # Return result
    return integrator.sol
end

supported_solvers = Dict(
    "default" => Sundials.IDA(),
    "IDA" => Sundials.IDA(),
    "DFBDF" => Eq.DFBDF(),
    "DABDF2" => Eq.DABDF2(),
    "DImplicitEuler" => Eq.DImplicitEuler(),
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
        return supported_solvers[key]
    end

    fallback = supported_solvers["default"]
    @warn "Unknown solver '$solver_name', using $fallback as default"
    return fallback()
end

function simulate_config(config::RootConfig)
    # Load network
    graph = load_network(config.network, Float64)
    Term.tprintln("  {bold green}✓{/bold green} Loaded network {cyan}$(graph.name){/cyan}")

    # Load configuration
    sim_config = config.simulation
    sim_config = isnothing(sim_config) ? SimulationConfigDefault : sim_config
    Term.tprintln("  {bold green}✓{/bold green} Configuration: t=$(sim_config.time_span), solver={cyan}$(sim_config.solver){/cyan}")

    # Assemble network
    sim_input = build_network(graph)
    n_nodes = length(graph.nodes)
    n_states = length(sim_input.x0)
    Term.tprintln("  {bold green}✓{/bold green} Assembled {cyan}$n_nodes{/cyan} nodes → {cyan}$n_states{/cyan} state variables")

    # Solve
    sol = solve_phs_realtime(sim_input, sim_config=sim_config)
    Term.tprintln("  {bold green}✓{/bold green} Solved DAE: {cyan}$(length(sol.t)){/cyan} time points, t_final={cyan}$(round(sol.t[end], digits=2)){/cyan}")

    return SimulationResult(sol, sim_input.system, graph)
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
