
"""
PHSolver

Port-Hamiltonian network simulation library.

This module re-exports the core types, assembly utilities, YAML config loader,
and solver/plotting helpers defined across the source files.
"""
module PHSolver

################################################################################
# SystemConfig, SimConfig and schema definitions
################################################################################
include("config/JuliaDictSchema.jl")
include("config/JuliaUnionSchema.jl")

include("config/ComponentSchema.jl")
export Component, Connection

include("config/SystemConfig.jl")
export SystemConfig, SystemConfigSchema, make_system_schema

include("config/ParseConfig.jl")
export validate_config
export read_config

include("config/SimConfig.jl")
export SimConfig

include("config/MakeSchema.jl")
export make_system_schema


################################################################################
# Symbolics
################################################################################
include("symbolics/ParseExpr.jl")
export parse_expr

include("symbolics/Definition.jl")
export Definition
export definition_from_expr

include("symbolics/DefinitionGraph.jl")
export DefinitionGraph
export traverse_order
export add_vertex!
export add_edge!
export rem_edge!
export add_defs!

include("symbolics/Resolve.jl")
export resolve_graph!

include("symbolics/MakeDefinitions.jl")
export process_definitions


################################################################################
# Models
################################################################################
include("models/PortHamSystem.jl")

################################################################################
# Util
################################################################################
include("Util.jl")
export pprint
export print_namespace
export compute_hamiltonian
export compute_energy

################################################################################
# PhsSystem assembly
################################################################################
include("system/IterConfig.jl")
export iter_config!

include("system/RefFunction.jl")
export RefFunction
export build_func_or_float
export evaluate
export update_ref!

include("system/RefTypes.jl")
export FloatOrRef
export SignedRef

include("system/PhsSystem.jl")
export PhsSystem
export get_index
export has_index

include("system/CollectComponents.jl")
export build_id
export collect_components!

include("system/CollectInteractions.jl")
export collect_interactions!

include("system/MakeSystem.jl")
export make_system


################################################################################
# PhsState
################################################################################
include("state/PhsState.jl")
export PhsState


################################################################################
# PhsSimulation
################################################################################
include("simulation/PhsSimulation.jl")
export PhsSimulation

include("simulation/SolveTimespan.jl")
export solve_timespan

include("simulation/SolveRealtime.jl")
export solve_realtime


################################################################################

include("simulation/GetProblem.jl")
include("simulation/GetSolver.jl")
include("simulation/SolvePhs.jl")
include("simulation/SimulateConfig.jl")

include("plots/Plots.jl")
include("plots/NetworkPlot.jl")


# Export primary types and convenience functions
export PortHamSystem
export state_dimension
export input_dimension

# Export YAML parser functions

# Export solver functions
export solve_phs
export init_solver
export step_solver!
export init_simulation
export supported_solvers
export init_simulation
export get_dae_solver

# Export plots
export plot_result
export graphviz_network

end
