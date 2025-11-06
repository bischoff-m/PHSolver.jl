"""
The SystemModelling module wraps the neccessary modules etc. for fast inclusion in code. Usage (mostly):

    include("./Object Oriented/src/SystemModelling.jl")

    using .SystemModellingModule
    using .SystemModellingModule.pHModule
"""

module TestPhsSolver

include("utils.jl")
include("portHamiltonianSystem.jl")
include("simulator.jl")
include("interconnection.jl")
include("components.jl")

using .utilsModule
using .pHModule
using .SimulatorModule
using .interconnectionModule
using .componentsModule

using Plots
using LaTeXStrings
using LinearAlgebra

# utils.jl
export is_skewSymmetric,
    is_positiveSemiDefinite, plot_states, plot_energy, plot_results, blockdiag, blockmatrix
# pH (ODE)
export pHSystem, Hamiltonian, output, dynamics, dynamics!, power, dHdt, state_space
# pH (DAE)
export pHDescriptorSystem,
    state_matrix, to_pHODE, is_index1_like, as_coenergy_state, check_coherence
# simulators
export Simulator, DescriptorSimulator, simulate
export SolverMethod, EulerMethod, MidpointMethod, Gauss1Method, Gauss2Method, BackwardEulerMethod
# interconnection.jl
export PortPair, build_K, connect, connect_resistor
# components.jl
export inductor, capacitor

end
