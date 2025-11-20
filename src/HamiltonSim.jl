
module HamiltonSim

# Include component/source files so the entire library is exported from this
# single module. Files included here should NOT declare their own `module`.
include("PortHamiltonianSystem.jl")

# Export primary types and convenience functions
export PortHamiltonianSystem
export state_dimension, input_dimension

end