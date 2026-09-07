import OrdinaryDiffEq as Eq
import DiffEqCallbacks as EqCB
import CSV
import DataFrames as DF



function init_output(ids::AbstractVector{String})
    cols = Symbol[:t, :H]
    append!(cols, Symbol.(ids .* ".x"))
    append!(cols, Symbol.(ids .* ".dx"))
    append!(cols, Symbol.(ids .* ".u"))
    append!(cols, Symbol.(ids .* ".y"))

    return DF.DataFrame([Float64[] for _ in cols], cols)
end

function append_output!(df::DF.DataFrame, state::PhsState, integrator)
    y = dynamics_output(state, integrator.u)
    H = hamiltonian(state, integrator.u)
    row = Float64[
        integrator.t;
        H;
        integrator.u...;
        integrator.du...;
        state.u...;
        y...
    ]

    push!(df, row)
    return nothing
end

function flush_output!(
    df::DF.DataFrame,
    csv_path::String,
    header_written::Ref{Bool}
)
    if DF.nrow(df) == 0
        return nothing
    end

    CSV.write(
        csv_path,
        df;
        append=header_written[],
        writeheader=(!header_written[])
    )
    header_written[] = true
    empty!(df)
    return nothing
end

function snapshot_callback(sim::PhsSimulation; flush_every::Int=100)
    isdir(sim.snapshot_path) || mkpath(sim.snapshot_path)
    csv_path = joinpath(sim.snapshot_path, "snapshots.csv")
    isfile(csv_path) && rm(csv_path)
    # isfile(csv_path) && error("Snapshot file already exists at $csv_path. Please remove it before running the simulation.")

    buffer = init_output(sim.state.system.ids)
    header_written = Ref(false)

    function emit_snapshot(integrator)
        append_output!(buffer, sim.state, integrator)
        if DF.nrow(buffer) >= flush_every
            flush_output!(buffer, csv_path, header_written)
        end
        return nothing
    end

    callback = EqCB.PeriodicCallback(
        emit_snapshot,
        sim.state.sim_config.output_interval;
        initial_affect=true,
        final_affect=true,
    )

    finalize!() = flush_output!(buffer, csv_path, header_written)
    return callback, finalize!
end

function solve_timespan(
    sim::PhsSimulation;
    verbose=false,
    timeout_seconds::Real=Inf,
    dt::Union{Nothing,Real}=nothing,
    adaptive::Union{Nothing,Bool}=nothing,
    dtmax::Union{Nothing,Real}=nothing,
)
    started = time()
    callback, finalize! = snapshot_callback(sim)
    sim.problem.p[] = time() + Float64(timeout_seconds)
    try
        solve_kwargs = (
            initializealg=Eq.BrownFullBasicInit(),
            abstol=1e-6,
            reltol=1e-4,
            save_everystep=false,
            saveat=sim.state.sim_config.output_interval,
            progress=true,
            progress_name="Simulation",
            callback=callback
        )
        !isnothing(dt) && (solve_kwargs = merge(solve_kwargs, (; dt=Float64(dt))))
        !isnothing(adaptive) && (solve_kwargs = merge(solve_kwargs, (; adaptive=adaptive)))
        !isnothing(dtmax) && (solve_kwargs = merge(solve_kwargs, (; dtmax=Float64(dtmax))))

        sol = Eq.solve(sim.problem, sim.solver; solve_kwargs...)
        println("Simulation complete: t_final=$(round(sol.t[end], digits=6))")
        return sol
    finally
        finalize!()
        verbose && println("[timing] simulation solve: $(round(time() - started, digits=3)) s")
    end
end