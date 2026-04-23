using LinearAlgebra

"""
    SimDynamics

Simulation-ready dynamics container for a port-Hamiltonian system.

# Fields
- `system::PortHamSystem{T}`: Assembled system
- `x0::AbstractVector{T}`: Initial state
- `input_func::Function`: Input function `u(t)`
"""
struct SimDynamics{T<:Real}
    system::PortHamSystem{T}
    x0::AbstractVector{T}

    function SimDynamics(
        system::PortHamSystem{T},
        x0::AbstractVector{T}
    ) where {T<:Real}
        n = state_dimension(system)
        @assert length(x0) == n "Initial state vector x0 must have length $n"

        new{T}(system, x0)
    end
end