using LinearAlgebra
using OrdinaryDiffEq

# Helper function to check if a matrix is skew-symmetric
function isskewsym(A::AbstractMatrix{<:Real})
    return A ≈ -transpose(A)
end

struct PortHamSystem{T<:Real}
    interconnection::AbstractMatrix{T}
    dissipation::AbstractMatrix{T}
    mass::AbstractMatrix{T}
    input::AbstractMatrix{T}

    function PortHamSystem(
        interconnection::AbstractMatrix{T},
        dissipation::AbstractMatrix{T},
        mass::AbstractMatrix{T},
        input::AbstractMatrix{T},
    ) where {T<:Real}
        # State dimension
        n = size(mass, 1)

        # Check dimensions
        @assert size(interconnection, 1) == n "Interconnection matrix must have size (n, n)"
        @assert size(interconnection, 2) == n "Interconnection matrix must have size (n, n)"
        @assert size(dissipation, 1) == n "Dissipation matrix must have size (n, n)"
        @assert size(dissipation, 2) == n "Dissipation matrix must have size (n, n)"
        @assert size(mass, 1) == n "Mass matrix must have size (n, n)"
        @assert size(mass, 2) == n "Mass matrix must have size (n, n)"
        @assert size(input, 1) == n "Input matrix must have size (n, m)"

        # Check properties
        @assert issymmetric(dissipation) "Dissipation matrix must be symmetric"
        @assert all(eigvals(dissipation) .>= -1e-10) "Dissipation matrix must be positive semi-definite"
        @assert isdiag(mass) "Mass matrix must be diagonal"
        @assert all(diag(mass) .>= -1e-10) "Mass matrix must be positive semi-definite"
        @assert isskewsym(interconnection) "Interconnection matrix must be skew-symmetric"

        new{T}(interconnection, dissipation, mass, input)
    end
end

state_dimension(sys::PortHamSystem) = size(sys.mass, 1)
input_dimension(sys::PortHamSystem) = size(sys.input, 2)
