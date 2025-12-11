# Example demonstrating the evolve function with a 2D Mass-Spring-Damper system
# This file can be run independently: `julia test/examples.jl`
# Based on documentation/examples/Mass Spring Damper 2D System/config/2D_MSD_System.jl

if abspath(PROGRAM_FILE) == @__FILE__
    import Pkg
    Pkg.activate(joinpath(@__DIR__, ".."))
end

using HamiltonSim
using Plots
using LinearAlgebra

# Parameters from original config
m = 1.0
k = 2.0
d = 0.5

# Matrices from original config
# J: Skew-symmetric interconnection matrix
J = [0.0 1.0; -1.0 0.0]

# R: Dissipation matrix (damping)
R = [0.0 0.0; 0.0 d]

# Qe: Energy matrix
Qe = Diagonal([k, 1 / m])  # k=2, m=1

# G: Input matrix
G = reshape([0.0, 1.0], 2, 1)

# Create the system
sys = PortHamSystem(J, R, Qe, G)

# Initial state from original config
x0 = [1.0, -4.0]
xdot0 = zeros(2)
y0 = zeros(1)
state = HamiltonState(x0, xdot0, y0)

# Simulation parameters from original config
dt = 0.002
t_final = 20.0
n_steps = Int(t_final / dt)

# Input function from original config
input_func(t) = [sin(t)]

# Run the simulation using evolve
println("Simulating 2D Mass-Spring-Damper system for $t_final seconds with dt = $dt...")
states = evolve(sys, state, dt, n_steps, input_func)

# Extract data for plotting
times = [(i - 1) * dt for i in 1:n_steps]
positions = [states[i].state[1] for i in 1:n_steps]
momenta = [states[i].state[2] for i in 1:n_steps]
outputs = [states[i].output[1] for i in 1:n_steps]

# Create plots
p1 = plot(times, positions,
    label="Position",
    xlabel="Time (s)",
    ylabel="Position",
    linewidth=2,
    title="2D Mass-Spring-Damper System (m=$m, k=$k, d=$d)"
)

p2 = plot(times, momenta,
    label="Momentum",
    xlabel="Time (s)",
    ylabel="Momentum",
    linewidth=2,
    color=:red
)

p3 = plot(positions, momenta,
    label="Phase Portrait",
    xlabel="Position",
    ylabel="Momentum",
    linewidth=2,
    color=:green,
    aspect_ratio=:equal
)

p4 = plot(times, outputs,
    label="Output",
    xlabel="Time (s)",
    ylabel="Output",
    linewidth=2,
    color=:purple
)

# Combine all plots
plot(p1, p2, p3, p4,
    layout=(2, 2),
    size=(1000, 800),
    plot_title="Port-Hamiltonian System Evolution"
)

# Save the plot
savefig("test/simulation_results.png")
println("Plot saved to test/simulation_results.png")

# Display the plot (if running in an environment that supports it)
gui()
