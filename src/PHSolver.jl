
"""
PHSolver

Port-Hamiltonian network simulation library.

This module re-exports the core types, assembly utilities, YAML config loader,
and solver/plotting helpers defined across the source files.
"""
module PHSolver

################################################################################
# Schema
################################################################################
include("schema/DictSchema.jl")
include("schema/ComponentSchema.jl")
export Component, Connection
include("schema/SystemConfig.jl")
export SystemConfig, SystemConfigSchema, make_system_schema
include("schema/SimConfig.jl")
export SimulationConfig


################################################################################
# Symbolics
################################################################################
include("symbolics/ParseExpr.jl")
export parse_expr

include("symbolics/Definition.jl")
export Definition
export parse_definitions

include("symbolics/DefinitionGraph.jl")
export DefinitionGraph
export traverse_order
export add_vertex!
export add_edge!
export rem_edge!
export add_defs!

include("symbolics/Resolve.jl")
export resolve_graph!


################################################################################
# Models
################################################################################
include("models/PortHamSystem.jl")
include("models/SimDynamics.jl")

################################################################################
# Util
################################################################################
include("Util.jl")
export pprint
export print_namespace
export compute_hamiltonian
export compute_energy

################################################################################
# State
################################################################################
include("state/IterConfig.jl")
export iter_config!

include("state/StateFunction.jl")
export StateFunction
export build_func_or_float
export evaluate
export update!

include("state/ComponentResult.jl")
export ComponentResult
export get_index
export has_index
export FloatOrRef

include("state/InteractionResult.jl")
export InteractionResult
export SignedRef

include("state/CollectComponents.jl")
export collect_components

include("state/CollectInteractions.jl")
export collect_interactions!

################################################################################
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

# Export plots
export plot_result
export graphviz_network

end
