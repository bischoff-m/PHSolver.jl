
"""
PHSolver

Port-Hamiltonian network simulation library.

This module re-exports the core types, assembly utilities, YAML config loader,
and solver/plotting helpers defined across the source files.
"""
module PHSolver

# Include component/source files so the entire library is exported from this
# single module. Files included here should NOT declare their own `module`.
include("schema/DictSchema.jl")
include("schema/ComponentSchema.jl")
export Component, Connection
include("schema/SystemConfig.jl")
export SystemConfig, SystemConfigSchema, make_system_schema
include("schema/SimConfig.jl")
export SimulationConfig

include("models/PortHamSystem.jl")
include("models/SimDynamics.jl")

include("network/Models.jl")
include("network/InputFunction.jl")
include("network/Interconnection.jl")
include("network/Assembly.jl")

include("simulation/GetProblem.jl")
include("simulation/GetSolver.jl")
include("simulation/SolvePHS.jl")
include("simulation/SimulateConfig.jl")

include("config/ParseConfig.jl")
include("config/ParseNetwork.jl")

include("plots/Plots.jl")
include("plots/NetworkPlot.jl")

include("Util.jl")


# Export primary types and convenience functions
export PortHamSystem
export state_dimension
export input_dimension

# Export network types
export PhsNodeOld

# Export interconnection functions
export apply_connection!

# Export network assembly functions
export dynamics_from_network
export compute_hamiltonian
export parse_external_function

# Export YAML parser functions
export network_from_config
export validate_config
export read_config

# Export solver functions
export solve_phs
export init_solver
export step_solver!
export simulate_file
export supported_solvers
export simulate_config
export get_dae_solver

# Export symbolic utilities
include("symbolics/ParseExpr.jl")
export parse_expr

include("symbolics/Definition.jl")
export Definition
export parse_definitions
export parse_definition

include("symbolics/DefinitionGraph.jl")
export DefinitionGraph
export traverse_order
export add_vertex!
export add_edge!
export rem_edge!
export add_defs!

include("symbolics/Resolve.jl")
export resolve_graph!

# Export utility functions
export compute_energy

# Export plots
export plot_result
export graphviz_network

end
