using LinearAlgebra

# Helper function to check if a matrix is skew-symmetric
function isskewsym(A::AbstractMatrix{<:Real})
    return A ≈ -transpose(A)
end

struct PortHamiltonianSystem{T<:Real}
    interconnection::AbstractMatrix{T}
    dissipation::AbstractMatrix{T}
    energy::AbstractMatrix{T}
    input::AbstractMatrix{T}

    function PortHamiltonianSystem(
        interconnection::AbstractMatrix{T},
        dissipation::AbstractMatrix{T},
        energy::AbstractMatrix{T},
        input::AbstractMatrix{T}
    ) where T<:Real
        # State dimension
        n = size(energy, 1)

        # Check dimensions
        @assert size(interconnection, 1) == n "Interconnection matrix must have size (n,n)"
        @assert size(interconnection, 2) == n "Interconnection matrix must have size (n,n)"
        @assert size(dissipation, 1) == n "Dissipation matrix must have size (n,n)"
        @assert size(dissipation, 2) == n "Dissipation matrix must have size (n,n)"
        @assert size(energy, 1) == n "Energy matrix must have size (n,n)"
        @assert size(energy, 2) == n "Energy matrix must have size (n,n)"
        @assert size(input, 1) == n "Input matrix must have size (n,m)"

        # Check properties
        @assert issymmetric(dissipation) "Dissipation matrix must be symmetric"
        @assert isposdef(dissipation) "Dissipation matrix must be positive definite"
        @assert issymmetric(energy) "Energy matrix must be symmetric"
        @assert isposdef(energy) "Energy matrix must be positive definite"
        @assert isskewsym(interconnection) "Interconnection matrix must be skew-symmetric"

        new{T}(interconnection, dissipation, energy, input)
    end
end

state_dimension(sys::PortHamiltonianSystem) = size(sys.energy, 1)
input_dimension(sys::PortHamiltonianSystem) = size(sys.input, 2)
