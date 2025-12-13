#!/usr/bin/env julia
# Network-based simulation example using YAML configuration

include("../src/HamiltonSim.jl")

import .HamiltonSim
using Plots

println("="^70)
println("Port-Hamiltonian Network Simulation from YAML")
println("="^70)

# Specify which example to run
example = "dc_power_network"  # or "coupled_masses"

config_file = joinpath(@__DIR__, "configs", "$(example).yaml")
output_dir = joinpath(@__DIR__, "output")
isdir(output_dir) || mkdir(output_dir)

# Run complete simulation workflow
result = HamiltonSim.simulate_network_from_yaml(config_file; verbose=true, validate=true)

system = result.system
sol = result.solution
graph = result.graph
config = result.config

# Plot results
println("\nGenerating plots...")

# Plot all state variables
n = HamiltonSim.state_dimension(system)
plt = plot(
    sol.t,
    sol[1, :],
    label="x₁",
    xlabel="Time [s]",
    ylabel="State",
    lw=2,
    title=graph.name,
)

for i in 2:n
    plot!(plt, sol.t, sol[i, :], label="x$i", lw=2)
end

savefig(plt, output_dir * "/$(example)_states.png")
println("Saved state plot to $(output_dir)/$(example)_states.png")

# Plot network energy
energy = HamiltonSim.compute_energy(sol, system)
plt_energy = plot(
    sol.t,
    energy,
    label="Total Energy",
    xlabel="Time [s]",
    ylabel="Energy [J]",
    lw=2,
    title="$(graph.name) - Energy",
)

savefig(plt_energy, output_dir * "/$(example)_energy.png")
println("Saved energy plot to $(output_dir)/$(example)_energy.png")

# Display network information
println("\n" * "="^70)
println("Network Information")
println("="^70)

state_info = HamiltonSim.get_network_state_info(graph)

for (node_id, info) in sort(collect(state_info); by=x -> x[1])
    println("\nNode: $node_id")
    println("  State dimension: $(info["state_dim"])")
    println("  State range: $(info["state_range"])")
    println("  Differential variables: $(info["n_differential"])")
    println("  Algebraic variables: $(info["n_algebraic"])")

    if info["n_differential"] > 0
        println("  Differential indices: $(info["differential_indices"])")
    end
    if info["n_algebraic"] > 0
        println("  Algebraic indices: $(info["algebraic_indices"])")
    end
end

println("\n" * "="^70)
println("Simulation completed successfully!")
println("="^70)

