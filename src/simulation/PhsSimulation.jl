import OrdinaryDiffEq as Eq

struct SimulationTimeout <: Exception end

Base.showerror(io::IO, ::SimulationTimeout) =
    print(io, "simulation exceeded its wall-clock timeout")

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
    snapshot_dir::String=joinpath("examples", "output.local"),
    verbose=false,
    residual_log_interval::Real=Inf
)
    started = time()
    fixed_vars = Dict(:t => 0.0)
    result = collect_system(system_config; keep=Set(keys(fixed_vars)), verbose=verbose)
    verbose && println("[timing] collect_system total: $(round(time() - started, digits=3)) s")

    stage_started = time()
    state = PhsState(result, sim_config, fixed_vars)
    verbose && println("[timing] initialize PhsState: $(round(time() - stage_started, digits=3)) s")

    stage_started = time()
    problem = init_problem(
        state,
        Ref(Inf);
        residual_log_interval=residual_log_interval
    )
    solver = get_dae_solver(state.sim_config.solver)
    verbose && println("[timing] build DAE problem and solver: $(round(time() - stage_started, digits=3)) s")
    verbose && println("[diagnostics] simulation states=$(length(state.system.ids)), " *
                       "RefFunctions=$(length(state.system.functions)), solver=$(sim_config.solver)")
    verbose && println("[timing] simulation setup total: $(round(time() - started, digits=3)) s")

    return PhsSimulation(state, problem, solver, snapshot_dir)
end


function init_problem(
    state::PhsState,
    deadline::Base.RefValue{Float64};
    residual_log_interval::Real=Inf
)
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
    residual_calls = Ref(0)
    last_t = Ref(NaN)
    next_log_time = Ref(time() + Float64(residual_log_interval))
    function dae_residual!(out, dx, x, p, t)
        residual_calls[] += 1
        current_t = Float64(t)
        delta_t = isnan(last_t[]) ? NaN : current_t - last_t[]
        last_t[] = current_t
        time() > deadline[] && throw(SimulationTimeout())
        update(state, Dict(:t => current_t), x)
        out .= residual(state, x, dx)
        if time() >= next_log_time[]
            max_x_index = argmax(abs.(x))
            max_dx_index = argmax(abs.(dx))
            println(
                "[residual] calls=$(residual_calls[]) t=$(current_t) dt=$(delta_t) " *
                "max_x=$(abs(x[max_x_index])) ($(state.system.ids[max_x_index])) " *
                "max_dx=$(abs(dx[max_dx_index])) ($(state.system.ids[max_dx_index])) " *
                "max_residual=$(maximum(abs, out))"
            )
            next_log_time[] = time() + Float64(residual_log_interval)
        end
    end

    return Eq.DAEProblem(
        dae_residual!,
        dx0,
        x0,
        state.sim_config.time_span,
        deadline;
        differential_vars=differential_vars
    )
end