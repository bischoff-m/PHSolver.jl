
module HamiltonSim

# Include component/source files so the entire library is exported from this
# single module. Files included here should NOT declare their own `module`.
include("NetworkSchema.jl")
include("PortHamSystem.jl")
include("NetworkModels.jl")
include("Interconnection.jl")
include("NetworkAssembly.jl")
include("YAMLParser.jl")
include("NetworkSolver.jl")
include("Plots.jl")
include("Util.jl")
include("InputFunction.jl")


# Export primary types and convenience functions
export PortHamSystem
export state_dimension
export input_dimension

# Export network types
export PHSNode
export ConnectionEdge
export ExternalInput
export NetworkGraph

# Export interconnection functions
export apply_connection!

# Export network assembly functions
export build_network
export compute_hamiltonian
export parse_external_function

# Export YAML parser functions
export load_network_from_yaml
export read_config

# Export solver functions
export solve_phs
export simulate_file
export supported_solvers
export simulate_config
export get_dae_solver

# Export utility functions
export compute_energy

# Export plots
export plot_result

end
