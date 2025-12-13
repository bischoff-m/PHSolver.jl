using OrdinaryDiffEq
using Sundials
using Term
using Term.Progress

"""
    solve_phs(
        system::PortHamSystem,
        x0::Vector,
        differential_vars::Vector{Bool},
        time_span::Tuple,
        u_func::Function;
        solver_name::String = "IDA"
    )

Solve a port-Hamiltonian system DAE.

The DAE is:
    Q * ẋ = (J - R) * x + B * u(t)

# Arguments
- `system::PortHamSystem`: The PHS to solve
- `x0::Vector`: Initial conditions
- `differential_vars::Vector{Bool}`: Indicators for differential variables
- `time_span::Tuple`: Time span (t_start, t_end) for simulation
- `u_func::Function`: Input function u(t)
- `solver_name::String`: DAE solver to use ("IDA", "DFBDF", "Rodas5")

# Returns
- Solution object from DifferentialEquations.jl
"""
function solve_phs(
    system::PortHamSystem{T},
    x0::Vector{T},
    differential_vars::Vector{Bool},
    time_span::Tuple{Real,Real},
    u_func::Function;
    solver_name::String="IDA",
    timestep::Union{Real,Nothing}=nothing,
) where {T<:Real}
    # Get matrices
    Q = system.mass
    J = system.interconnection
    R = system.dissipation
    B = system.input

    # Compute initial derivatives
    # Q * dx = (J - R) * x + B * u(0)
    dx0 = zeros(T, length(x0))
    u0 = u_func(time_span[1])
    rhs = (J - R) * x0 + B * u0

    for i in 1:length(dx0)
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
    prob = DAEProblem(dae_residual!, dx0, x0, time_span; differential_vars=differential_vars)

    # Select solver
    solver = get_dae_solver(solver_name)

    # Solve with automatic initialization
    # If timestep is specified, use saveat to control output times
    if isnothing(timestep)
        sol = solve(prob, solver; initializealg=OrdinaryDiffEq.BrownFullBasicInit())
    else
        sol = solve(prob, solver; initializealg=OrdinaryDiffEq.BrownFullBasicInit(), saveat=timestep)
    end

    return sol
end

"""
    create_external_input_function(graph::NetworkGraph, B::Matrix)

Create an external input function for the network from YAML configuration.

# Arguments
- `graph::NetworkGraph`: Network graph with external input specifications
- `B::Matrix`: Global input matrix

# Returns
- `Function`: u(t) that returns the input vector at time t
"""
function create_external_input_function(graph::NetworkGraph{T}, B::Matrix{T}) where {T<:Real}
    n_inputs = size(B, 2)

    # Parse all input function expressions
    input_funcs = Dict{String,Function}()
    for ext_input in graph.external_inputs
        input_funcs[ext_input.system] = parse_input_function(ext_input.function_expr)
    end

    # Create global input function
    function u_network(t::Real)
        u = zeros(T, n_inputs)

        input_offset = 0
        for (node_id, node) in sort(collect(graph.nodes), by=x -> x[1])
            node_input_dim = input_dimension(node.system)

            # Check if this node has external input
            if haskey(input_funcs, node_id)
                node_u = input_funcs[node_id](t)
                # Handle scalar vs vector input
                if node_u isa Number
                    u[input_offset+1] = node_u
                else
                    u[(input_offset+1):(input_offset+node_input_dim)] .= node_u
                end
            end

            input_offset += node_input_dim
        end

        return u
    end

    return u_network
end

"""
    get_dae_solver(solver_name::String)

Get a DAE solver algorithm by name.

# Supported solvers
- "IDA": Sundials IDA (implicit differential-algebraic)
- "DFBDF": OrdinaryDiffEq DFBDF
- "Rodas5": OrdinaryDiffEq Rodas5

# Arguments
- `solver_name::String`: Name of the solver

# Returns
- Solver algorithm
"""
function get_dae_solver(solver_name::String)
    if solver_name == "IDA"
        return IDA()
    elseif solver_name == "DFBDF"
        return DFBDF()
    elseif solver_name == "Rodas5"
        return Rodas5()
    else
        @warn "Unknown solver '$solver_name', using IDA as default"
        return IDA()
    end
end

struct SimulationResult{T}
    system::PortHamSystem{T}
    solution::Any
    graph::NetworkGraph{T}
    config::Dict
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
function simulate_file(
    yaml_path::String;
    validate::Bool=true,
)
    T = Float64

    # Verbose mode with progress tracking
    # Create progress bar
    total_steps = validate ? 4 : 3
    pbar = ProgressBar(;
        columns=:default,
        width=80,
        transient=false,
        colors="cyan"
    )

    result = with(pbar) do
        job = addjob!(pbar; N=total_steps)

        # Step 1: Load network
        graph = load_network_from_yaml(yaml_path, T)
        Term.tprintln("  {bold green}✓{/bold green} Loaded network {cyan}$(graph.name){/cyan}")
        update!(job)

        # Step 2: Load configuration
        sim_config = get_simulation_config(yaml_path)
        Term.tprintln("  {bold green}✓{/bold green} Configuration: t=$(sim_config["time_span"]), solver={cyan}$(sim_config["solver"]){/cyan}")
        update!(job)

        # Step 3: Assemble network
        system, x0, differential_vars = assemble_network(graph; verbose=false)
        u_func = create_external_input_function(graph, system.input)
        n_nodes = length(graph.nodes)
        n_states = length(x0)
        Term.tprintln("  {bold green}✓{/bold green} Assembled {cyan}$n_nodes{/cyan} nodes → {cyan}$n_states{/cyan} state variables")
        update!(job)

        # Step 4: Validate (if enabled)
        if validate
            if !validate_phs(system, "Assembled Network"; verbose=false)
                Term.tprintln("  {bold red}✗{/bold red} Validation failed!")
                error("Network validation failed!")
            end
            Term.tprintln("  {bold green}✓{/bold green} System validation passed")
            update!(job)
        end

        # Step 5: Solve
        sol = solve_phs(
            system,
            x0,
            differential_vars,
            sim_config["time_span"],
            u_func;
            solver_name=sim_config["solver"],
            timestep=sim_config["timestep"],
        )
        Term.tprintln("  {bold green}✓{/bold green} Solved DAE: {cyan}$(length(sol.t)){/cyan} time points, t_final={cyan}$(round(sol.t[end], digits=2)){/cyan}")

        return SimulationResult(system, sol, graph, sim_config)
    end

    return result
end

"""
    extract_node_solution(solution, graph::NetworkGraph, node_id::String)

Extract a specific node's state trajectory from the network solution.

# Arguments
- `solution`: Solution object from solve_phs
- `graph::NetworkGraph`: The network graph metadata
- `node_id::String`: ID of the node to extract

# Returns
- Matrix where each column is the node state at a time point
"""
function extract_node_solution(solution, graph::NetworkGraph, node_id::String)
    node = get_node(graph, node_id)
    range = get_node_state_range(node)

    # Extract node states across all time points
    return solution[range, :]
end

"""
    compute_energy(solution, system::PortHamSystem)

Compute the total energy over the solution trajectory.

# Arguments
- `solution`: Solution object
- `system::PortHamSystem`: The PHS

# Returns
- Vector of energy values at each time point
"""
function compute_energy(solution, system::PortHamSystem{T}) where {T<:Real}
    Q = system.mass
    energy = zeros(T, length(solution.t))

    for (i, t) in enumerate(solution.t)
        x = solution[:, i]
        energy[i] = 0.5 * dot(x, Q * x)
    end

    return energy
end
