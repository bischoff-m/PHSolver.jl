
module HamiltonSim

# Include component/source files so the entire library is exported from this
# single module. Files included here should NOT declare their own `module`.
include("AbstractTypes.jl")
include("PortHamSystem.jl")
include("Network.jl")
include("Interconnection.jl")
include("NetworkAssembly.jl")
include("Validation.jl")
include("YAMLParser.jl")
include("NetworkSolver.jl")

# import HamiltonSim: PortHamSystem, HamiltonState, evolve_step

# Export abstract types and generic interfaces
export AbstractModel, AbstractState, AbstractParameters
export state_dimension, input_dimension, dynamics!
export get_state, set_state!, get_derivative, set_derivative!
export evolve_step!, evolve

# Export simulation parameter types
export EulerParams

# Export primary types and convenience functions
export PortHamSystem, HamiltonState
export get_output, set_output!
export compute_hamiltonian, compute_output
export derive_initial_conditions

# Export network types
export PHSNode, ConnectionEdge, ExternalInput, NetworkGraph
export get_node, create_network_nodes
export get_node_state_range, get_global_state, extract_node_state

# Export interconnection functions
export apply_connection!
export apply_direct_connection!, apply_negative_feedback_connection!
export apply_skew_symmetric_connection!

# Export network assembly functions
export assemble_network
export compute_hamiltonian, get_network_state_info

# Export validation functions
export validate_phs, validate_network, validate_skew_symmetry, validate_symmetry
export validate_positive_semidefinite, validate_diagonal
export validate_power_balance, validate_connection_compatibility

# Export YAML parser functions
export load_network_from_yaml, get_simulation_config
export parse_input_function

# Export solver functions
export solve_phs, simulate_network_from_yaml
export extract_node_solution, compute_energy
export get_dae_solver

end
