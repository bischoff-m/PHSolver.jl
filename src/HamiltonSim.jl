
module HamiltonSim

# Include component/source files so the entire library is exported from this
# single module. Files included here should NOT declare their own `module`.
include("PortHamSystem.jl")
include("Network.jl")
include("Interconnection.jl")
include("NetworkAssembly.jl")
include("YAMLParser.jl")
include("NetworkSolver.jl")


# Export primary types and convenience functions
export PortHamSystem
export state_dimension
export input_dimension

# Export network types
export PHSNode
export ConnectionEdge
export ExternalInput
export NetworkGraph
export get_node
export create_network_nodes
export get_node_state_range

# Export interconnection functions
export apply_connection!

# Export network assembly functions
export assemble_network
export compute_hamiltonian
export get_network_state_info

# Export YAML parser functions
export load_network_from_yaml
export read_config
export parse_input_function

# Export solver functions
export solve_phs
export simulate_file
export supported_solvers
export simulate_config
export extract_node_solution
export compute_energy
export get_dae_solver

end
