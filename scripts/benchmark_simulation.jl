include(joinpath(@__DIR__, "..", "src", "PHSolver.jl"))

function measure(label::String, work::Function, repetitions::Int)
    # Warm up once so compilation time is excluded from the phase comparison.
    work()
    elapsed = @elapsed begin
        for _ in 1:repetitions
            work()
        end
    end
    allocations = @allocated begin
        for _ in 1:repetitions
            work()
        end
    end
    return (
        label=label,
        milliseconds=1000 * elapsed / repetitions,
        allocations=allocations ÷ repetitions,
    )
end

function benchmark_simulation(
    config_path::String="examples/configs/DGU.yaml";
    repetitions::Int=10_000
)
    config = PHSolver.read_config(config_path)
    sim = PHSolver.PhsSimulation(
        config,
        PHSolver.SimConfig([0.0, 0.01]);
        snapshot_dir=joinpath("examples", "output.local", "benchmark"),
        verbose=false,
    )
    state = sim.state
    x = zeros(Float64, length(state.system.ids))
    PHSolver.eval_refs!(x, state.system.x0)
    dx = zeros(Float64, length(x))
    out = zeros(Float64, length(x))
    sim.problem.p[] = Inf
    callback = sim.problem.f.f
    params = Dict(:t => 0.0)

    update_work = () -> PHSolver.update(state, params, x)
    residual_work = () -> (out .= PHSolver.residual(state, x, dx))
    residual_in_place_work = () -> PHSolver.residual!(out, state, x, dx)
    callback_work = () -> callback(out, dx, x, sim.problem.p, 0.0)

    measurements = [
        measure("update", update_work, repetitions),
        measure("residual (allocating)", residual_work, repetitions),
        measure("residual! (in-place)", residual_in_place_work, repetitions),
        measure("full DAE callback", callback_work, repetitions),
    ]

    println("Simulation benchmark: $config_path")
    println("State dimension: $(length(x)); reference functions: $(length(state.system.functions))")
    println("Iterations: $repetitions")
    println("Phase                         ms/call       bytes/call")
    println("-------------------------------------------------------")
    for result in measurements
        println(rpad(result.label, 30), lpad(round(result.milliseconds, digits=4), 10), lpad(result.allocations, 16))
    end

    return measurements
end

if abspath(PROGRAM_FILE) == @__FILE__
    benchmark_simulation()
end