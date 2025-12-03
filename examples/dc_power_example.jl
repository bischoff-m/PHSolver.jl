# From:
#   Structure-preserving discretization for port-Hamiltonian descriptor systems
#   Section 4.1: A basic DC power network example


using HamiltonSim
using LinearAlgebra
using Plots
using OrdinaryDiffEq

println("Starting DC Power Example Simulation...")

# Circuit parameters
L = 2
C1 = 0.01
C2 = 0.02
RL = 0.1
RG = 6
RR = 3

# Amount of power delivered to RR
P = 10
# Current through inductor

# Energy of the generator (controlled)
# EG = -(RR + RL + RG) * 

# Kirchhoff's laws
IR = sqrt(P / RR)
VR = IR * RR

V2 = VR
I2 = V2 * C2

# IL is I in the paper (reserved symbol for Julia)
IL = -(IR + I2)
VL = IL * RL

V1 = V2 + VL
I1 = V1 * C1

IG = IL - I1
VG = IG * RG


# Objective
IL_star = IR * 1
V1_star = IR * (-RR - RL)
V2_star = IR * (-RR)
IG_star = IR * 1
IR_star = IR * (-1)

# Port-Hamiltonian Matrices
E = Diagonal([L, C1, C2, 1, 1])
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

u(t) = VG
x0 = [IL; V1; V2; IG; IR]
tspan = (0.0, 1.0)

sol = solve_dae(sys, x0, tspan, u; saveat=0.1)
times = sol.t
states = sol.u
println("Simulation completed.")

# Plot all currents and voltages and the hamiltonian
ILs = [s[1] for s in states]
V1s = [s[2] for s in states]
V2s = [s[3] for s in states]
IGs = [s[4] for s in states]
IRs = [s[5] for s in states]

H(i, v1, v2) = 0.5 * (L * i^2 + C1 * v1^2 + C2 * v2^2)

Hs = [H(s[1], s[2], s[3]) for s in states]

plot(
    times,
    [ILs V1s V2s IGs IRs Hs],
    labels=["IL(t)" "V1(t)" "V2(t)" "IG(t)" "IR(t)" "H(t)"],
    title="Currents and Voltages over Time",
    xlabel="Time [s]",
    ylabel="Values",
)
savefig("dc_power_example_results.png")