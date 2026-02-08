using LinearAlgebra

"""
    SimDynamics

Simulation-ready dynamics container for a port-Hamiltonian system.

# Fields
- `system::PortHamSystem{T}`: Assembled system
- `x0::AbstractVector{T}`: Initial state
- `differential_vars::AbstractVector{Bool}`: Mask for differential variables
- `input_func::Function`: Input function `u(t)`
"""
struct SimDynamics{T<:Real}
    system::PortHamSystem{T}
    x0::AbstractVector{T}
    differential_vars::AbstractVector{Bool}
    input_func::Function

    function SimDynamics(
        system::PortHamSystem{T},
        x0::AbstractVector{T},
        differential_vars::AbstractVector{Bool},
        input_func::Function,
    ) where {T<:Real}
        n = state_dimension(system)
        @assert length(x0) == n "Initial state vector x0 must have length $n"
        @assert length(differential_vars) == n "Differential vars vector must have length $n"

        new{T}(system, x0, differential_vars, input_func)
    end
end