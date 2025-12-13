using LinearAlgebra

"""
    validate_skew_symmetry(J::Matrix, name::String = "J"; tol::Float64 = 1e-10)

Validate that a matrix is skew-symmetric: J = -J^T

# Returns
- `true` if skew-symmetric, `false` otherwise
"""
function validate_skew_symmetry(J::Matrix{T}, name::String="J"; tol::T=1e-10) where {T<:Real}
    if size(J, 1) != size(J, 2)
        @error "Matrix $name must be square" size = size(J)
        return false
    end

    max_deviation = maximum(abs.(J + J'))

    if max_deviation > tol
        @error "Matrix $name is not skew-symmetric" max_deviation
        return false
    end

    return true
end

"""
    validate_symmetry(R::Matrix, name::String = "R"; tol::Float64 = 1e-10)

Validate that a matrix is symmetric: R = R^T

# Returns
- `true` if symmetric, `false` otherwise
"""
function validate_symmetry(R::Matrix{T}, name::String="R"; tol::T=1e-10) where {T<:Real}
    if size(R, 1) != size(R, 2)
        @error "Matrix $name must be square" size = size(R)
        return false
    end

    max_deviation = maximum(abs.(R - R'))

    if max_deviation > tol
        @error "Matrix $name is not symmetric" max_deviation
        return false
    end

    return true
end

"""
    validate_positive_semidefinite(M::Matrix, name::String = "M"; tol::Float64 = 1e-10)

Validate that a matrix is positive semi-definite (all eigenvalues >= 0)

# Returns
- `true` if positive semi-definite, `false` otherwise
"""
function validate_positive_semidefinite(
    M::Matrix{T},
    name::String="M";
    tol::T=1e-10,
) where {T<:Real}
    if size(M, 1) != size(M, 2)
        @error "Matrix $name must be square" size = size(M)
        return false
    end

    try
        eigs = eigvals(Symmetric(M))
        min_eig = minimum(eigs)

        if min_eig < -tol
            @error "Matrix $name is not positive semi-definite" min_eigenvalue = min_eig
            return false
        end
    catch e
        @error "Failed to compute eigenvalues of $name" exception = e
        return false
    end

    return true
end

"""
    validate_diagonal(E::Matrix, name::String = "E"; tol::Float64 = 1e-10)

Validate that a matrix is diagonal

# Returns
- `true` if diagonal, `false` otherwise
"""
function validate_diagonal(E::Matrix{T}, name::String="E"; tol::T=1e-10) where {T<:Real}
    if size(E, 1) != size(E, 2)
        @error "Matrix $name must be square" size = size(E)
        return false
    end

    n = size(E, 1)
    for i in 1:n
        for j in 1:n
            if i != j && abs(E[i, j]) > tol
                @error "Matrix $name is not diagonal" i = i j = j value = E[i, j]
                return false
            end
        end
    end

    return true
end

"""
    validate_power_balance(system::PortHamSystem, x::Vector, u::Vector)

Validate the power balance of a PHS:
    dH/dt = -∇H^T * R * ∇H + y^T * u <= y^T * u

This checks passivity of the system.

# Returns
- `true` if power balance is satisfied, `false` otherwise
"""
function validate_power_balance(
    system::PortHamSystem{T},
    x::Vector{T},
    u::Vector{T};
    tol::T=1e-8,
) where {T<:Real}
    Q = system.mass
    J = system.interconnection
    R = system.dissipation
    B = system.input

    # Compute Hamiltonian gradient
    dH = Q * x

    # Compute state derivative: ẋ = (J - R) * ∇H + B * u
    xdot = (J - R) * dH + B * u

    # Compute dH/dt = ∇H^T * ẋ
    dH_dt = dot(dH, xdot)

    # Compute output: y = B^T * ∇H
    y = B' * dH

    # Compute supplied power: y^T * u
    supplied_power = dot(y, u)

    # Compute dissipated power: -∇H^T * R * ∇H
    dissipated_power = -dot(dH, R * dH)

    # Check: dH/dt = dissipated_power + supplied_power
    expected_dH_dt = dissipated_power + supplied_power

    deviation = abs(dH_dt - expected_dH_dt)

    if deviation > tol
        @error "Power balance violation" dH_dt expected_dH_dt deviation
        return false
    end

    # Check passivity: dH/dt <= supplied_power
    # (equivalent to dissipated_power <= 0)
    if dissipated_power > tol
        @error "Passivity violation: positive dissipation" dissipated_power
        return false
    end

    return true
end

"""
    validate_phs(system::PortHamSystem, name::String; verbose::Bool = true)

Validate a port-Hamiltonian system.

Checks:
1. J is skew-symmetric
2. R is symmetric and positive semi-definite
3. Q (mass matrix) is diagonal and positive semi-definite
4. Matrix dimensions are consistent

# Arguments
- `system::PortHamSystem`: PHS to validate
- `name::String`: Name to display in validation messages
- `verbose::Bool`: Print validation results

# Returns
- `true` if all validation checks pass, `false` otherwise
"""
function validate_phs(system::PortHamSystem{T}, name::String="PHS"; verbose::Bool=true) where {T<:Real}
    all_valid = true

    n = state_dimension(system)
    J = system.interconnection
    R = system.dissipation
    Q = system.mass
    B = system.input

    verbose && println("Validating $name...")

    # 1. Check J is skew-symmetric
    verbose && print("  Checking J is skew-symmetric... ")
    if validate_skew_symmetry(J, "J")
        verbose && println("✓")
    else
        verbose && println("✗")
        all_valid = false
    end

    # 2. Check R is symmetric and PSD
    verbose && print("  Checking R is symmetric... ")
    if validate_symmetry(R, "R")
        verbose && println("✓")
    else
        verbose && println("✗")
        all_valid = false
    end

    verbose && print("  Checking R is positive semi-definite... ")
    if validate_positive_semidefinite(R, "R")
        verbose && println("✓")
    else
        verbose && println("✗")
        all_valid = false
    end

    # 3. Check Q is diagonal and PSD
    verbose && print("  Checking Q is diagonal... ")
    if validate_diagonal(Q, "Q")
        verbose && println("✓")
    else
        verbose && println("✗")
        all_valid = false
    end

    verbose && print("  Checking Q is positive semi-definite... ")
    if validate_positive_semidefinite(Q, "Q")
        verbose && println("✓")
    else
        verbose && println("✗")
        all_valid = false
    end

    # 4. Check dimensions
    verbose && print("  Checking matrix dimensions... ")
    dims_valid = true
    if size(J) != (n, n)
        @error "J dimension mismatch" expected = (n, n) actual = size(J)
        dims_valid = false
    end
    if size(R) != (n, n)
        @error "R dimension mismatch" expected = (n, n) actual = size(R)
        dims_valid = false
    end
    if size(Q) != (n, n)
        @error "Q dimension mismatch" expected = (n, n) actual = size(Q)
        dims_valid = false
    end
    if size(B, 1) != n
        @error "B row dimension mismatch" expected = n actual = size(B, 1)
        dims_valid = false
    end

    if dims_valid
        verbose && println("✓")
    else
        verbose && println("✗")
        all_valid = false
    end

    if verbose
        if all_valid
            println("\n✓ PHS validation passed!")
        else
            println("\n✗ PHS validation failed!")
        end
    end

    return all_valid
end

"""
    validate_connection_compatibility(
        source_node::PHSNode,
        target_node::PHSNode,
        edge::ConnectionEdge
    )

Validate that a connection is compatible (port dimensions match).

# Returns
- `true` if compatible, `false` otherwise
"""
function validate_connection_compatibility(
    source_node::PHSNode,
    target_node::PHSNode,
    edge::ConnectionEdge,
)
    # Check that source output dimension matches target input dimension
    # For PHS, output_dim = input_dim

    source_dim = source_node.output_dim
    target_dim = target_node.input_dim

    # If indices are specified, check those
    if !isnothing(edge.source_indices)
        source_dim = length(edge.source_indices)
    end
    if !isnothing(edge.target_indices)
        target_dim = length(edge.target_indices)
    end

    if source_dim != target_dim
        @error "Connection dimension mismatch" source = source_node.id target = target_node.id source_dim target_dim
        return false
    end

    return true
end
