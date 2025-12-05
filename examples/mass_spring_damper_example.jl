"""
Mass-Spring-Damper System Example using DAE Solver

This example demonstrates how to use the HamiltonSim package to simulate
a 2D mass-spring-damper system using the DAE solver from OrdinaryDiffEq.jl.

The system has:
- Mass m = 1.0 kg
- Spring constant k = 2.0 N/m
- Damping coefficient d = 0.5 N⋅s/m

State variables:
- x[1]: Spring displacement (position)
- x[2]: Momentum (velocity * mass)

The port-Hamiltonian representation is:
    Q * dx/dt = (J - R) * Q * x + B * u(t)

where:
- Q (energy matrix) = diag([k, 1/m]) - relates state to energy coordinates
- J (interconnection) = [0 1; -1 0] - skew-symmetric structure matrix
- R (dissipation) = [0 0; 0 d] - symmetric dissipation matrix
- B (input matrix) = [0; 1] - input distribution
"""

using HamiltonSim
using LinearAlgebra
using Plots
using OrdinaryDiffEq

# ============================================================================
# System Parameters
# ============================================================================

m = 1.0  # Mass [kg]
k = 2.0  # Spring constant [N/m]
d = 0.5  # Damping coefficient [N⋅s/m]

# ============================================================================
# Port-Hamiltonian Matrices
# ============================================================================

# Interconnection matrix (skew-symmetric)
J = [0.0 1.0; -1.0 0.0]

# Dissipation matrix (symmetric, positive semi-definite)
R = [0.0 0.0; 0.0 d]

# Energy matrix (symmetric, positive definite)
# Q relates state to energy: H = 0.5 * x^T * Q * x
# For mass-spring: H = 0.5*k*q^2 + 0.5*(p^2/m)
Q = Diagonal([k, 1.0 / m])

# Input matrix (where forces are applied)
B = reshape([0.0, 1.0], 2, 1)  # Force applied to momentum equation

# ============================================================================
# Create Hamilton System
# ============================================================================

sys = HamiltonSystem(J, R, Q, B)

println("Mass-Spring-Damper System Created")
println("State dimension: ", state_dimension(sys))
println("Input dimension: ", input_dimension(sys))
println()

# ============================================================================
# Define Input and Initial Conditions
# ============================================================================

# Input force: sinusoidal excitation
u(t) = [sin(t)]

# Initial conditions: [position, momentum]
x0 = [1.0, -4.0]  # Start with displacement and initial velocity

# Time span
tspan = (0.0, 20.0)

println("Initial state: ", x0)
println("Initial energy: ", compute_hamiltonian(sys, x0))
println()

# ============================================================================
# Solve using DAE Solver
# ============================================================================

println("Solving with DAE solver (Rodas5)...")
sol = solve_dae(sys, x0, tspan, u; saveat=0.05)

println("Solution computed successfully!")
println("Number of time points: ", length(sol.t))
println("Final state: ", sol.u[end])
println("Final energy: ", compute_hamiltonian(sys, sol.u[end]))
println()

# ============================================================================
# Extract solution data for plotting
# ============================================================================

t = sol.t
positions = [sol.u[i][1] for i in 1:length(sol.u)]
momenta = [sol.u[i][2] for i in 1:length(sol.u)]
velocities = momenta ./ m  # v = p/m
energies = [compute_hamiltonian(sys, sol.u[i]) for i in 1:length(sol.u)]

# Compute outputs (forces transmitted)
outputs = [compute_output(sys, sol.u[i])[1] for i in 1:length(sol.u)]

# ============================================================================
# Create Plots
# ============================================================================

println("Creating plots...")

# Plot 1: State variables over time
p1 = plot(t, positions, label="Position q(t)", xlabel="Time [s]", ylabel="Position [m]",
    linewidth=2, legend=:topright)
plot!(p1, t, velocities, label="Velocity v(t)", linewidth=2)
title!(p1, "Mass-Spring-Damper: State Variables")

# Plot 2: Phase portrait
p2 = plot(positions, velocities, label="", xlabel="Position [m]", ylabel="Velocity [m/s]",
    linewidth=2, marker=:circle, markersize=2, markerstrokewidth=0)
scatter!(p2, [x0[1]], [x0[2] / m], label="Initial", markersize=6, markercolor=:green)
scatter!(p2, [positions[end]], [velocities[end]], label="Final", markersize=6, markercolor=:red)
title!(p2, "Phase Portrait")

# Plot 3: Energy over time
p3 = plot(t, energies, label="Total Energy H(x)", xlabel="Time [s]", ylabel="Energy [J]",
    linewidth=2, color=:red)
title!(p3, "System Energy (should decrease due to damping)")

# Plot 4: Input and output
p4 = plot(t, [u(ti)[1] for ti in t], label="Input u(t)", xlabel="Time [s]",
    ylabel="Force [N]", linewidth=2)
plot!(p4, t, outputs, label="Output y(t)", linewidth=2, linestyle=:dash)
title!(p4, "Input and Output")

# Combine all plots
plot_combined = plot(p1, p2, p3, p4, layout=(2, 2), size=(1200, 800),
    plot_title="Mass-Spring-Damper System (DAE Solver)")

# Save plot
savefig(plot_combined, "examples/mass_spring_damper_dae.png")
println("Plot saved as 'examples/mass_spring_damper_dae.png'")

# Display plot (if in interactive environment)
display(plot_combined)

# ============================================================================
# Additional Analysis
# ============================================================================

println("\n" * "="^70)
println("ANALYSIS SUMMARY")
println("="^70)

# Natural frequency and damping ratio
ω_n = sqrt(k / m)  # Natural frequency
ζ = d / (2 * sqrt(k * m))  # Damping ratio

println("System characteristics:")
println("  Natural frequency ω_n = $(round(ω_n, digits=3)) rad/s")
println("  Damping ratio ζ = $(round(ζ, digits=3))")
if ζ < 1
    println("  System is underdamped")
elseif ζ == 1
    println("  System is critically damped")
else
    println("  System is overdamped")
end

println("\nEnergy dissipation:")
println("  Initial energy: $(round(energies[1], digits=4)) J")
println("  Final energy: $(round(energies[end], digits=4)) J")
println("  Energy dissipated: $(round(energies[1] - energies[end], digits=4)) J")

println("\n" * "="^70)
