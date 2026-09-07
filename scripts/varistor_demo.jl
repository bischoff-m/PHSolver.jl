include("../src/PHSolver.jl")

using Plots

examples_dir = normpath(@__DIR__, "../examples")
output_dir = joinpath(examples_dir, "output.local")
isdir(output_dir) || mkdir(output_dir)

config_file = joinpath(examples_dir, "configs", "varistor_demo.yaml")
config = PHSolver.read_config(config_file)

sim = PHSolver.PhsSimulation(config, PHSolver.SimConfig([0.0, 3.0]); verbose=false)
sol = PHSolver.solve_timespan(sim; verbose=false)

# Reuse the YAML definitions to visualize the drive and the varistor curve.
defs = PHSolver.resolve_definitions(PHSolver.exprs_to_definitions(config.definitions...))
drive_def = defs[:drive]
varistor_def = defs[:varistor_R]
drive_fun = PHSolver.RefFunction(drive_def)
varistor_fun = PHSolver.RefFunction(varistor_def)

times = range(sol.t[1], sol.t[end], length=250)
drive_values = [PHSolver.evaluate(drive_fun, Dict(:t => t)) for t in times]
resistance_values = [PHSolver.evaluate(varistor_fun, Dict(:v => v)) for v in drive_values]

plt1 = plot(
    sol.t,
    sol[1, :],
    label=sim.state.system.ids[1],
    lw=2,
    xlabel="Time [s]",
    ylabel="State",
    title="Varistor demo: state trajectories",
)
for i in 2:length(sim.state.system.ids)
    plot!(plt1, sol.t, sol[i, :], label=sim.state.system.ids[i], lw=2)
end

plt2 = plot(
    times,
    drive_values,
    label="drive(t)",
    lw=2,
    xlabel="Time [s]",
    ylabel="Voltage / Resistance",
    title="Drive voltage and effective varistor resistance",
)
plot!(plt2, times, resistance_values, label="varistor_R(drive)", lw=2)

plt = plot(plt1, plt2, layout=(2, 1), size=(1100, 800))
savefig(plt, joinpath(output_dir, "varistor_demo.png"))
display(plt)

println("Saved varistor demo plot to ", joinpath(output_dir, "varistor_demo.png"))