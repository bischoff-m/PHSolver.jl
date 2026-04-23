import OrdinaryDiffEq as Eq

# https://docs.sciml.ai/DiffEqDocs/stable/basics/integrator/#Initialization-and-Stepping
struct PhsSimulation{T}
    state::PhsState
    problem::Eq.DAEProblem
    solver::T
    snapshot_path::String
end

function PhsSimulation(
    system_config::SystemConfig,
    sim_config::SimConfig;
    snapshot_dir::String="output.local",
    verbose=false
)
    fixed_vars = Dict(:t => 0.0)
    result = make_system(system_config; keep=Set(keys(fixed_vars)), verbose=verbose)

    state = PhsState(result, sim_config, fixed_vars)
    problem = init_problem(state)
    solver = get_dae_solver(state.sim_config.solver)

    return PhsSimulation(state, problem, solver, snapshot_dir)
end


function init_problem(state::PhsState)
    # Evaluate initial x
    x0 = zeros(Float64, length(state.system.ids))
    eval_refs!(x0, state.system.x0)

    # Set initial dx = inv(E) * dynamics_rhs(state)
    Edx = dynamics_rhs(state, x0)
    dx0 = zeros(Float64, length(state.system.ids))
    I, _, V = findnz(state.E)
    differential_vars = falses(length(state.system.ids))
    for k in eachindex(V)
        dx0[I[k]] = Edx[I[k]] / V[k]
        differential_vars[I[k]] = true
    end
    function dae_residual!(out, dx, x, p, t)
        update(state, Dict(:t => t))
        out .= residual(state, x, dx)
    end

    return Eq.DAEProblem(
        dae_residual!,
        dx0,
        x0,
        state.sim_config.time_span;
        differential_vars=differential_vars
    )
end