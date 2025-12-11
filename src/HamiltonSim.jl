
module HamiltonSim

# Include component/source files so the entire library is exported from this
# single module. Files included here should NOT declare their own `module`.
include("AbstractTypes.jl")
include("HamiltonSystem.jl")

# import HamiltonSim: HamiltonSystem, HamiltonState, evolve_step

# Export abstract types and generic interfaces
export AbstractModel, AbstractState, AbstractParameters
export state_dimension, input_dimension, dynamics!
export get_state, set_state!, get_derivative, set_derivative!
export evolve_step!, evolve

# Export simulation parameter types
export EulerParams

# Export primary types and convenience functions
export HamiltonSystem, HamiltonState
export get_output, set_output!
export evolve_step  # Legacy compatibility

# Export DAE solver functions
export solve_dae, create_dae_function
export compute_hamiltonian, compute_output
export derive_initial_conditions

end
