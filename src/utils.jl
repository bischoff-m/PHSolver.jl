"""
    The utilsModule consists of additional struct-independent functions for simulations and modelling of port-Hamiltonian systems.

    The current implementation has functions
        - is_skewSymmetric:
            ->  Checks if a matrix input is skew symmetric up to a given tolerance atol. 
                Used for initializing a pHODE/pHDAE struct where the Interconnection matrix J must be skew symmetric

        - is_positiveSemiDefinite:
            ->  Checks if a matrix input is positive semi definite up to a given tolerance atol. 
                    Used for initializing a pHODE/pHDAE struct where the dissipation matrix R must be positive semi definite.

        - plot_states:
            -> Plots time vs states
        
        - plot_energy:
            -> Plots time vs states
        
        - plot_results
            -> Plots time vs states and energy in either one or two separated plots
        
"""

module utilsModule

# Main exports
export is_skewSymmetric, is_positiveSemiDefinite, blockdiag, blockmatrix
# Visualizations
export plot_states, plot_energy, plot_results

# Other needed resources
using LinearAlgebra
using Plots
using LaTeXStrings
using TestPhsSolver: pHSystem, pHDescriptorSystem


# -------------------------------------------------
# Main functions
# -------------------------------------------------
function is_skewSymmetric(M::AbstractMatrix; atol::Real = 1e-12)
    # Scale tolerance with matrix size/scale
    return opnorm(M + M', Inf) <= max(atol, eps(eltype(M))^(2 / 3) * opnorm(M, Inf))
end

function is_positiveSemiDefinite(M::AbstractMatrix, atol::Real = 1e-10)
    @assert size(M, 1) == size(M, 2)  #PSD requires square Matrix
    lambda_min = eigmin(Hermitian(M))
    return lambda_min >= -max(atol, eps(eltype(M))^(2 / 3) * opnorm(M, Inf))
end

function blockdiag(A::AbstractMatrix, B::AbstractMatrix)
    T = promote_type(eltype(A), eltype(B))
    M = zeros(T, size(A, 1) + size(B, 1), size(A, 2) + size(B, 2))
    M[1:size(A, 1), 1:size(A, 2)] .= A
    M[(size(A, 1)+1):end, (size(A, 2)+1):end] .= B
    return M
end

function blockmatrix(
    A::AbstractMatrix,
    B::AbstractMatrix,
    C::AbstractMatrix,
    D::AbstractMatrix,
)
    mA, nA = size(A)
    mB, nB = size(B)
    mC, nC = size(C)
    mD, nD = size(D)

    @assert mA == mB "Dimensions are not matching to build blockmatrix."
    @assert mC == mD "Dimensions are not matching to build blockmatrix."
    @assert nA == nC "Dimensions are not matching to build blockmatrix."
    @assert nB == nD "Dimensions are not matching to build blockmatrix."

    return [A B; C D]

end

# -------------------------------------------------
# Visualizations
# -------------------------------------------------
function plot_states(t, X)
    tt = collect(t)
    n = size(X, 1)
    p = plot(
        tt,
        vec(@view X[1, :]),
        label = "x(1)",
        xlabel = L"Time $t$",
        ylabel = L"States $x$",
        title = "Simulation results",
    )
    if n > 7
        for i = 2:7
            plot!(p, tt, vec(@view X[i, :]), label = "x$(i)")
        end
    else
        # Less or equal to 7 states to plot
        for i = 2:n
            plot!(p, tt, vec(@view X[i, :]), label = "x$(i)")
        end
    end
    return p
end

function plot_energy(t, X, sys)
    tt = collect(t)
    n = size(X, 1)
    if sys isa pHSystem
        Q = getfield(sys, :Qe)
    elseif sys isa pHDescriptorSystem
        Q = getfield(sys, :QH)
    else
        @error "No QH/Qe found on sys; skipping Hamiltonian computation."
    end
    H = Vector{Float64}(undef, length(tt))
    xi = zeros(eltype(X), n)
    @inbounds for k in eachindex(tt)
        xi .= @view X[:, k]
        H[k] = 0.5 * dot(xi, Q * xi)
    end
    p = plot(tt, H, label = "H", xlabel = "t", ylabel = "energy", title = "Hamiltonian")
    return p
end

function plot_results(
    t,
    X;
    sys = nothing,
    H = nothing,
    separate::Bool = false,
    state_labels = nothing,
    energy_label::AbstractString = L"$\mathcal{H}$",
)
    @assert size(X, 2) == length(t) "States X must be n x nt with nt == length(t)"
    n, nt = size(X)

    # Compute H if not provided
    if H === nothing && sys !== nothing
        # Case 1: pHDescriptorSystem + QH exists
        if hasproperty(sys, :QH) && sys.QH != nothing
            H = vec(0.5 .* sum(X .* (sys.QH * X), dims = 1))
        elseif sys isa pHSystem
            H = vec(0.5 .* sum(X .* (sys.Qe * X), dims = 1))
        else
            @warn "No QH/Qe found on sys; skipping Hamiltonian computation."
        end
    end

    # labels
    state_labels === nothing && (state_labels = ["x($(i))" for i = 1:n])
    @assert length(state_labels) == n "state_labels must have length $n"

    if separate
        p_states = plot(xlabel = L"Time $t$", title = "States")
        for i = 1:n
            plot!(p_states, t, view(X, i, :), label = state_labels[i])
        end

        p_energy = plot()
        if H !== nothing
            plot!(
                p_energy,
                t,
                H,
                l = :dash,
                label = energy_label,
                xlabel = L"Time $t$",
                title = "Hamiltonian",
            )
        else
            @warn "H is not available; only states will be shown."
        end
        p = plot(p_states, p_energy; layout = (2, 1), link = :x)
    else
        p = plot(xlabel = L"Time $t$", title = "Simulation results")
        for i = 1:n
            plot!(p, t, view(X, i, :), label = state_labels[i])
        end
        if H !== nothing
            plot!(p, t, H, l = :dash, label = energy_label)
        else
            @warn "H is not available; overlay will only show states."
        end
    end

    return p
end



end
