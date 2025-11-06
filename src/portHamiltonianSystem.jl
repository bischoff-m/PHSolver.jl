"""
    Generally, a linear port-Hamiltonian system is composed of several matrices that uniquely define the dynamics of the system
        E == Differential-pivot matrix (struct pHDescriptorSystem)
        J == Interconnection matrix (skew symmetric!)
        R == Dissipation matrix (positive semi definite!)
        Q == Linear part of energy flow variable grad(H)(x) = Qx (struct pHSystem) [or: matrix for quadratic hamiltonian H = 0.5*x^T*Q*x]
        g == input/output pertubation matrix

    pHModule contains the following:
        (classic) structs: pHSystem, pHDescriptorSystem with corresponding functional structs for conversion of types etc.

    The underlying dynamical systems modelled using these structs are the following:
        - pHSystem:
            For a n-dim. state x, Hamiltonian H, we assume a linear Hamiltonian gradient, i.e. ∇H(x) = Q*x where Q is a (square) nxn matrix, and
                    dx/dt = (J-R)Qx + Gu, y=G^T*Qx

        - pHDescriptorSystem:
            For a n-dim. state x, Hamiltonian H, we assume a port-Hamiltonian differential algebraic equation system, i.e. we have the form
                    E*dx/dt = (J-R)Qx + Gu, y=G^T*Qx
                Note that here: E might be a singular matrix, where we have Rank(E) pH-ODEs and n-Rank(E) pH-DAEs.
                In case of Rank(E)=n, i.e. E is non-singular, we can transform the pHDAE system into an pHODE system by using to_pHODE.

    The properties of the corresponding structs are the following:
        pHSystem:
            - J, R, Q, g (matrices as described above)
            - n: nxm is the size of these matrices
            - m: nxm is the size of these matrices

        pHDescriptorSystem:
            - E, J, R, Qe, g (matrices as described above)
            - QH: (optional) Matrix of weights for total energy stored in system [H(x) = 0.5*x^T*QH*x]
            - n: nxm is the size of these matrices
            - m: nxm is the size of these matrices
            - rep: either :x_state or :z_state

    The module contains functions that are essential for simulation and behavioural analysis, namely
        pHSystem (pHODE)
            - Hamiltonian: Computes the Hamiltonian of the system
            - dynamics: Computes the LHS of the dynamics given the RHS
            - output: Computes the output y = g^T Qx
            - power: Computes the power output of the system
            - dHdt: Computes the time-derivative of the Hamiltonian for energy-balance
            - state_space: Computes the (classical) state-space representation of the pHSystem

        pHDescriptorSystem (pHDAE)
            - Hamiltonian: Computes the Hamiltonian of the system
            - dynamics: Computes the LHS of the dynamics given the RHS
            - output: Computes the output y = g^T Qx
            - power: Computes the power output of the system
            - dHdt: Computes the time-derivative of the Hamiltonian for energy-balance
            - state_matrix: Computes the state-space matrix A of the (classical) state-space representation of the system
            - is_index1_like: For our case all the "indices" are equivalent, so this function tests if the underlying DAE is of index 1 
                            (differentiation/strangeness/tractability or Kronecker/Weierstraß (nilpotency) index). 
                            If true, the system does not need to be differentiated to be solved as an ODE.
            - to_pHODE: Converts pHDAE into pHODE system struct (if E is invertible)
            - check_coherence: Checks coherence of Qe and QH (Qe arising in pHODE and QH in Hamiltonian)
            - as_coenergy_state: Transformation to co-energy representation

"""
module pHModule

# Exports for pH ODEs
export pHSystem, Hamiltonian, dynamics, dynamics!, output, power, dHdt, state_space
# Exports for pH DAEs
export pHDescriptorSystem,
    state_matrix, to_pHODE, is_index1_like, as_coenergy_state, check_coherence

# Needed for mathematical operations
using LinearAlgebra
# Parent module (needed for struct)
using ..utilsModule: is_positiveSemiDefinite, is_skewSymmetric

# helper: Convert contrainer element type to T
_toT(A, ::Type{T}) where {T<:AbstractFloat} = T.(A)

# (optional) structure-preserving for Diagonal; use this instead of _toT to keep Diagonals
_toT(A::Diagonal, ::Type{T}) where {T<:AbstractFloat} = Diagonal(T.(diag(A)))

# --------------------------------------------------
# Everything for pH ODE system of form x' = (J-R)Qx + Gu
# --------------------------------------------------
struct pHSystem{
    T,
    JM<:AbstractMatrix{T},
    RM<:AbstractMatrix{T},
    QM<:AbstractMatrix{T},
    GM<:AbstractMatrix{T},
}
    # {T<:AbstractFloat} allows for usage of Float32, Float64 and BigFloat in Matrix{T}-entries

    # Matrices (n x m)
    J::JM  # Interconnection matrix
    R::RM  # Dissipation matrix
    Qe::QM  # Linear part of gradient of Hamiltonian, i.e. nabla H(x) = Qx with state x
    G::GM  # Input/Output matrix
    n::Int
    m::Int
end

# Inner constructor for pHSystem struct that checks the validity of the input matrices J and R
function pHSystem(
    J::AbstractMatrix{<:Real},
    R::AbstractMatrix{<:Real},
    Qe::AbstractMatrix{<:Real},
    G::AbstractVecOrMat{<:Real},
)

    # pick a float type: Float64 by default, but respects BigFloat if present
    T = promote_type(Float64, eltype(J), eltype(R), eltype(Qe), eltype(G))

    # convert containers to have element type T (quick dense fallback)
    Jf = _toT(J, T);
    Rf = _toT(R, T);
    Qf = _toT(Qe, T)
    Gm = isa(G, AbstractVector) ? reshape(G, :, 1) : G
    Gf = _toT(Gm, T)

    # Verification that matrices are n x n
    n = size(Qf, 1)
    @assert size(Qf, 2) == n "Q must be n×n"
    @assert size(Jf) == (n, n) "J must be n×n"
    @assert size(Rf) == (n, n) "R must be n×n"
    @assert size(Gf, 1) == n "G must have n rows"

    @assert is_skewSymmetric(Jf) "Invalid system: J must be skew-symmetric."
    @assert is_positiveSemiDefinite(Rf) "Invalid system: R must be positive semidefinite."

    return pHSystem{T,typeof(Jf),typeof(Rf),typeof(Qf),typeof(Gf)}(
        Jf,
        Rf,
        Qf,
        Gf,
        n,
        size(Gf, 2),
    )
end

# Hamiltonian function of the system
Hamiltonian(sys::pHSystem{T}, x::AbstractVector{T}) where {T} = T(0.5) * dot(x, sys.Qe * x)

# Dynamical equation for a fixed state x and input u
function dynamics(sys::pHSystem{T}, x::AbstractVector{T}, u::AbstractVector{T}) where {T}
    @assert length(u) == sys.m # u must be length $(sys.m)
    return (sys.J - sys.R) * (sys.Qe * x) + sys.G * u
end

# In-place, allocation free given preallocated buffers
function dynamics!(
    dx::AbstractVector,
    sys::pHSystem,
    x::AbstractVector,
    u::AbstractVector,
    Qx::AbstractVector,
)
    @assert length(u) == sys.m
    mul!(Qx, sys.Qe, x)
    mul!(dx, sys.J - sys.R, Qx)
    mul!(dx, sys.G, u, 1.0, 1.0)
    return dx
end

# Output equation for open-loop system
# Computes pH System output y = g^T * Qx
output(sys::pHSystem, x::AbstractVector) = (sys.G' * (sys.Qe * x))
power(sys::pHSystem, x::AbstractVector, u::AbstractVector) = dot(output(sys, x), u)

function dHdt(sys::pHSystem, x::AbstractVector, u::AbstractVector)
    Qx = sys.Qe * x
    return -dot(Qx, sys.R * Qx) + power(sys, x, u)
end

# LTI state-space representation
function state_space(sys::pHSystem)
    A = (sys.J - sys.R) * sys.Q
    B = sys.G
    C = sys.G' * sys.Q
    D = zeros(eltype(A), size(C, 1), size(B, 2))
    return A, B, C, D
end

# ------------------------------------------------------
# Everything for pH DAE system of form Ex' = (J-R)x + Gu
# ------------------------------------------------------
struct pHDescriptorSystem{
    T,
    EM<:AbstractMatrix{T},
    JM<:AbstractMatrix{T},
    RM<:AbstractMatrix{T},
    QeM<:AbstractMatrix{T},
    GM<:AbstractMatrix{T},
    QHM<:Union{AbstractMatrix{T},Nothing},
}
    E::EM
    J::JM
    R::RM
    Qe::QeM         # Effort map used in equations: e = Qe * x
    G::GM           # n×m
    QH::QHM         # Energy matrix for H(x) = 1/2x^T * QH * x (optional)
    n::Int
    m::Int
    rep::Symbol     # :x_state or :z_state
end

function pHDescriptorSystem(
    E::AbstractMatrix{<:Real},
    J::AbstractMatrix{<:Real},
    R::AbstractMatrix{<:Real},
    Qe::AbstractMatrix{<:Real},
    G::AbstractVecOrMat{<:Real};
    QH::Union{AbstractMatrix,Nothing} = nothing,
    rep::Symbol = :x_state,
)

    T = promote_type(
        Float64,
        eltype(E),
        eltype(J),
        eltype(R),
        eltype(Qe),
        eltype(G),
        (QH===nothing ? Float64 : eltype(QH)),
    )
    E, J, R, Qe = (T.(E), T.(J), T.(R), T.(Qe))
    G = isa(G, AbstractVector) ? reshape(T.(G), :, 1) : T.(G)
    n = size(E, 1);
    m = size(G, 2)
    @assert size(E)==(n, n) && size(J)==(n, n) && size(R)==(n, n) && size(Qe)==(n, n)
    @assert size(G, 1)==n
    @assert rep==:x_state || rep==:z_state
    @assert is_skewSymmetric(J)
    @assert is_positiveSemiDefinite(R)

    QHn = isnothing(QH) ? nothing : T.(QH)
    return pHDescriptorSystem{
        T,
        typeof(E),
        typeof(J),
        typeof(R),
        typeof(Qe),
        typeof(G),
        typeof(QHn),
    }(
        E,
        J,
        R,
        Qe,
        G,
        QHn,
        n,
        m,
        rep,
    )
end

# Reusing energy, output, etc.
function Hamiltonian(sys::pHDescriptorSystem, x::AbstractVector)
    if sys.QH !== nothing
        return 0.5 * dot(x, sys.QH * x)
    end

    # heuristic fallback: if E is spsd, use it
    if opnorm(sys.E - sys.E', Inf) <= 1e-12
        return 0.5 * dot(x, sys.E * x)
    end
    error("Hamiltonian requested but QH was not provided and E is not symmetric psd.")
end

function dHdt(sys::pHDescriptorSystem, x::AbstractVector, u::AbstractVector)
    @assert sys.QH !== nothing "dHdt needs QH"
    e = sys.Qe * x
    y = sys.G' * e
    return -dot(e, sys.R * e) + dot(y, u)
end

output(sys::pHDescriptorSystem, x::AbstractVector) = sys.G' * (sys.Qe * x)
power(sys::pHDescriptorSystem, y::AbstractVector, u::AbstractVector) = dot(y, u)

# Convenient A = (J-R)*Qe
state_matrix(sys::pHDescriptorSystem) = (sys.J - sys.R) * sys.Qe

# Coherence checker of relation between E and Qe/QH
function check_coherence(sys::pHDescriptorSystem, atol = 1e-10)
    # 1.  Left nullspace of E
    U, S, V = svd(sys.E; full = false)
    tol = max(atol, eps(eltype(S))^(2/3)*opnorm(sys.E, Inf))
    r = count(>(tol), S)
    N = (r < sys.n) ? U[:, (r+1):end] : zeros(eltype(sys.E), sys.n, 0)

    # 2. If QH exists
    issues = String[]
    if sys.QH !== nothing && size(N, 2) > 0
        M = sys.QH * N
        if opnorm(M, Inf) > 1e-8
            push!(issues, "Energy QH has components in algebrauc subspace (QH*N ≠ 0).")
        end
        # psd on dynamic subspace
        # form projector onto dynamic subspace: P = I - N*N'
        P = I - N*N'
        # test smallest eigenvalue of P'QH P in that subspace
        Hdyn = Symmetric(P' * sys.QH * P)
        lambda_min = eigmin(Hermitian(Hdyn))
        if lambda_min < -1e-10
            push!(issues, "QH is not psd on the dynamic subspace (λmin = $λmin).")
        end
    end

    # 3. representation consistency
    if sys.rep == :x_state && sys.QH !== nothing
        if opnorm(sys.Qe - sys.QH, Inf) > 1e-8
            push!(issues, "rep=:x_state expects Qe ≈ QH, but they differ.")
        end
    elseif sys.rep == :z_state
        if opnorm(sys.Qe - I, Inf) > 1e-8
            push!(issues, "rep=:z_state expects Qe = I, but Qe ≠ I.")
        end
    end

    return isempty(issues), issues
end

# Diagnostic function
function is_index1_like(sys::pHDescriptorSystem; atol = 1e-10)
    A = (sys.J - sys.R) * sys.Qe
    U, S, V = svd(sys.E; full = false)
    tol = max(atol, eps(eltype(S))^(2/3) * opnorm(sys.E, Inf))
    r = count(>(tol), S)
    if r == sys.n
        return true  # E invertible -> ODE (index 0 effectively)
    end
    N = U[:, (r+1):end]              # Null(E') left nullspace
    M = N' * A * N                 # algebraic block in reduced coords
    sigma = svdvals(M)
    return minimum(sigma) > tol
end

# from x_state (e = QH*x, Qe = QH) to z_state (z = e)
function as_coenergy_state(sys::pHDescriptorSystem)
    @assert sys.QH !== nothing "Need QH to switch to co-energy representation."
    QH = sys.QH
    # coordinate transformation: z = QH * x -> x = QH^{-1} * z (use psd-inverse on dynamics subspace)
    F = QH  # z = F*x
    Finv = pinv(F)  # pseudoinverse
    E_tilde = E*Finv
    J, R, G = sys.J, sys.R, sys.G
    Qe_tilde = I
    return pHDescriptorSystem(E_tilde, J, R, Qe_tilde, G; QH = QH, rep = :z_state)
end

# If E is invertible, produce an ODE pH in the same coordinates:
# dot(x) = (J-R) * (E \ Q) * x + (E \ G) * u
function to_pHODE(sys::pHDescriptorSystem)
    if sys.E isa Diagonal
        any(iszero, diag(sys.E)) && error("to_pHODE: E is singular; cannot convert to ODE.")
    else
        U, S, V = svd(sys.E; full = false)
        tol = max(1e-10, Base.eps(eltype(S))^(2/3) * opnorm(sys.E, Inf))
        minimum(S) > tol || error("to_pHODE: E is singular; cannot convert to ODE.")
    end
    Qtil = sys.E \ sys.Qe
    Gtil = sys.E \ sys.G
    return pHSystem(sys.J, sys.R, Qtil, Gtil)
end

end
