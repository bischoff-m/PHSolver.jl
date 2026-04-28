import OrdinaryDiffEq as Eq
import DiffEqCallbacks as EqCB
import CSV
import DataFrames
import OrderedCollections



function init_output(ids::AbstractVector{String})
    cols = Symbol[:t, :H]
    append!(cols, Symbol.(ids .* ".x"))
    append!(cols, Symbol.(ids .* ".dx"))
    append!(cols, Symbol.(ids .* ".u"))
    append!(cols, Symbol.(ids .* ".y"))

    return DataFrames.DataFrame([Float64[] for _ in cols], cols)
end

function append_output!(df::DataFrames.DataFrame, state::PhsState, integrator)
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
    df::DataFrames.DataFrame,
    csv_path::String,
    header_written::Ref{Bool}
)
    if DataFrames.nrow(df) == 0
        return nothing
    end

    CSV.write(
        csv_path,
        df;
        append=header_written[],
        writeheader=!header_written[]
    )
    header_written[] = true
    empty!(df)
    return nothing
end

function snapshot_callback(sim::PhsSimulation; flush_every::Int=1)
    isdir(sim.snapshot_path) || mkpath(sim.snapshot_path)
    csv_path = joinpath(sim.snapshot_path, "snapshots.csv")
    isfile(csv_path) && rm(csv_path)
    # isfile(csv_path) && error("Snapshot file already exists at $csv_path. Please remove it before running the simulation.")

    buffer = init_output(sim.state.system.ids)
    header_written = Ref(false)

    function emit_snapshot(integrator)
        append_output!(buffer, sim.state, integrator)
        if DataFrames.nrow(buffer) >= flush_every
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

function solve_timespan(sim::PhsSimulation; verbose=false)
    callback, finalize! = snapshot_callback(sim)
    try
        sol = Eq.solve(
            sim.problem,
            sim.solver;
            initializealg=Eq.BrownFullBasicInit(),
            progress=true,
            progress_name="Simulation",
            callback=callback
        )
        println("Simulation complete: t_final=$(round(sol.t[end], digits=2))")
        return sol
    finally
        finalize!()
    end
end