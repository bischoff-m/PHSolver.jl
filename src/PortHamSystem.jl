using LinearAlgebra

# Helper function to check if a matrix is skew-symmetric
function isskewsym(A::AbstractMatrix{<:Real})
    return A ≈ -transpose(A)
end

struct PortHamSystem{T<:Real}
    # Name "interaction" from the figure in
    # "Port-Hamiltonian framework in power systems domain: A survey"
    # https://doi.org/10.1016/j.egyr.2023.09.077
    # and
    # Name "mass" from mass matrix in DAE literature
    # https://en.wikipedia.org/wiki/Mass_matrix
    interaction::AbstractMatrix{T}
    dissipation::AbstractMatrix{T}
    mass::AbstractMatrix{T}
    input::AbstractMatrix{T}

    function PortHamSystem(
        interaction::AbstractMatrix{T},
        dissipation::AbstractMatrix{T},
        mass::AbstractMatrix{T},
        input::AbstractMatrix{T},
    ) where {T<:Real}
        # State dimension
        n = size(mass, 1)

        # Check dimensions
        @assert size(interaction, 1) == n "Interconnection matrix must have size (n, n)"
        @assert size(interaction, 2) == n "Interconnection matrix must have size (n, n)"
        @assert size(dissipation, 1) == n "Dissipation matrix must have size (n, n)"
        @assert size(dissipation, 2) == n "Dissipation matrix must have size (n, n)"
        @assert size(mass, 1) == n "Mass matrix must have size (n, n)"
        @assert size(mass, 2) == n "Mass matrix must have size (n, n)"
        @assert size(input, 1) == n "Input matrix must have size (n, m)"

        # Check properties
        @assert issymmetric(dissipation) "Dissipation matrix must be symmetric"
        @assert all(eigvals(Matrix(dissipation)) .>= -1e-10) "Dissipation matrix must be positive semi-definite"
        @assert isdiag(mass) "Mass matrix must be diagonal"
        @assert all(diag(mass) .>= -1e-10) "Mass matrix must be positive semi-definite"
        @assert isskewsym(interaction) "Interconnection matrix must be skew-symmetric"

        new{T}(interaction, dissipation, mass, input)
    end
end

state_dimension(sys::PortHamSystem) = size(sys.mass, 1)
input_dimension(sys::PortHamSystem) = size(sys.input, 2)

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