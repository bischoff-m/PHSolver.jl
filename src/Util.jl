

"""
    compute_hamiltonian(system::PortHamSystem, x::Vector)

Compute the Hamiltonian of a port-Hamiltonian system.

H(x) = 0.5 * x^T * Q * x

# Arguments
- `system::PortHamSystem`: The PHS
- `x::Vector`: State vector

# Returns
- Total energy
"""
function compute_hamiltonian(system::PortHamSystem{T}, x::AbstractVector{T}) where {T<:Real}
    @assert length(x) == state_dimension(system) "State dimension mismatch"
    return 0.5 * dot(x, system.mass * x)
end

"""
    compute_energy(solution, system::PortHamSystem)

Compute the total energy over the solution trajectory.

# Arguments
- `solution`: Solution object
- `system::PortHamSystem`: The PHS

# Returns
- Vector of energy values at each time point
"""
function compute_energy(solution, system::PortHamSystem{T}) where {T<:Real}
    return [compute_hamiltonian(system, solution[:, i]) for i in 1:length(solution.t)]
end
