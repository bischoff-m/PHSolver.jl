# From:
#   Structure-preserving discretization for port-Hamiltonian descriptor systems
#   Section 4.1: A basic DC power network example

include("../src/HamiltonSim.jl")

using .HamiltonSim
using LinearAlgebra
import Plots
import OrdinaryDiffEq as Eq
import Sundials

println("Starting DC Power Example Simulation...")

# Circuit parameters
L = 2.0
C1 = 0.01
C2 = 0.02
RL = 0.1
RG = 6.0
RR = 3.0

# Port-Hamiltonian Matrices
E = Diagonal([L, C1, C2, 0.0, 0.0])
B = reshape([0.0, 0.0, 0.0, 1.0, 0.0], :, 1)
# y = IG

J = [
    0.0 -1.0 1.0 0.0 0.0;
    1.0 0.0 0.0 -1.0 0.0;
    -1.0 0.0 0.0 0.0 -1.0;
    0.0 1.0 0.0 0.0 0.0;
    0.0 0.0 1.0 0.0 0.0
]

R = Diagonal([RL, 0.0, 0.0, RG, RR])

sys = HamiltonSystem(J, R, E, B)

u(t) = 0.0

# Initial values for differential variables: [IL, V1, V2]
x0_differential = [1.83, -5.66, -5.48]
x0, dx0, differential_vars = derive_initial_conditions(sys, x0_differential, u)

tspan = (0.0, 1.0)

function fn(out, dx, x, p, t)
    out .= (sys.interconnection .- sys.dissipation) * x .+ sys.input * u(t) .- sys.energy * dx
end

prob = Eq.DAEProblem(fn, dx0, x0, tspan, differential_vars=differential_vars)
sol = Eq.solve(prob, Sundials.IDA())


Plots.plot(
    sol.t,
    sol[1, :],
    label="IL(t)",
    xlabel="Time [s]",
    ylabel="Current [A]",
    lw=2,
)
Plots.plot!(sol.t, sol[2, :], label="V1(t)", lw=2)
Plots.plot!(sol.t, sol[3, :], label="V2(t)", lw=2)
Plots.plot!(sol.t, sol[4, :], label="IG(t)", lw=2)
Plots.plot!(sol.t, sol[5, :], label="IR(t)", lw=2, title="DC Power Network Simulation")
Plots.savefig("dc_power_example_results.png")
