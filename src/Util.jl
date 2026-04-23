

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


to_dense(col::AbstractVector) = collect(col)
to_dense(col::AbstractMatrix) = Matrix(col)

function pprint(
    cols::AbstractVecOrMat...;
    header::Union{Nothing,Union{Vector,Tuple}}=nothing,
    title::Union{Nothing,String}=nothing,
    args...
)
    if !isnothing(title)
        Term.tprintln(Term.highlight(title, :symbol))
    end
    cols = map(to_dense, cols)
    mat = hcat(cols...)
    # Round floating point numbers for better display
    for i in eachindex(mat)
        if isa(mat[i], AbstractFloat)
            mat[i] = round(mat[i], sigdigits=5)
        end
    end
    Term.tprint(Term.Table(
        mat,
        header=header,
        show_header=!isnothing(header),
        columns_justify=[:left; fill(:center, max(length(header) - 1, 0))...],
        args...,
    ))
end



Namespace = Dict{String,Any}

function print_namespace(namespace::Namespace; prefix="")
    Term.tprintln(Term.highlight("Namespace", :symbol))
    function inner(subspace, prefix)
        keys_sorted = sort(collect(keys(subspace)))
        for (i, key) in enumerate(keys_sorted)
            val = subspace[key]
            color = isnothing(val) ? :number : :code
            if i == length(keys_sorted)
                Term.tprintln(
                    prefix *
                    Term.highlight("└─ ", :emphasis) *
                    Term.highlight(key, color)
                )
                isnothing(val) || inner(val, prefix * "   ")
            else
                Term.tprintln(
                    Term.highlight(prefix * "├─ ", :emphasis) *
                    Term.highlight(key, color)
                )
                isnothing(val) || inner(val, prefix * "│  ")
            end
        end
    end
    inner(namespace, prefix)
    println()
end