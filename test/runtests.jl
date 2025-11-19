using TestPhsSolver: pHSystem, Simulator, simulate, plot_results
using LaTeXStrings

cfg_MSD = include("../documentation/examples/Mass Spring Damper 2D System/config/2D_MSD_System.jl")

# System struct only needs defining matrices J, R, Qe, G
sys_MSD = pHSystem(cfg_MSD.J, cfg_MSD.R, cfg_MSD.Qe, cfg_MSD.G)

# Simulator struct only needs pHSystem, timestep-size, simulation method
sim_MSD = Simulator(sys_MSD, cfg_MSD.dt, cfg_MSD.method)

# Simulation itself needs the simulator struct, initial condition of system, input/control u, and time interval
t, states, output = simulate(sim_MSD, cfg_MSD.x0, cfg_MSD.u, cfg_MSD.tspan);


#p1 = plot_energy(t, states, sys_MSD)
#p2 = plot_states(t, states)
p3 = plot_results(t, states; sys=sys_MSD, separate=false, state_labels=[L"$p(t)$", L"$q(t)$"])