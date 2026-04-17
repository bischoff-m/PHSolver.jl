

"""
    compute_hamiltonian(system::PortHamSystem, x::AbstractVector)

Compute the Hamiltonian of a port-Hamiltonian system.

\$H(x) = 0.5 * x^T Q x\$

# Arguments
- `system::PortHamSystem`: The PHS
- `x::AbstractVector`: State vector

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



function pprint(matrix::Union{AbstractMatrix,AbstractVector}; header::Union{Nothing,String}=nothing)
    isa(matrix, AbstractVector) && (matrix = reshape(matrix, :, 1))
    matrix = Matrix(matrix)
    if !isnothing(header)
        Term.tprintln(Term.highlight(header, :symbol))
    end
    Term.tprint(Term.Table(matrix; show_header=false, compact=true))
end