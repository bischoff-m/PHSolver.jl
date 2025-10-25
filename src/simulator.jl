"""
The SimulatorModule contains the Simulator struct for simulating the structs from portHamiltonianSystem.jl using different 
simulation specifications (i.e. implemented solvers). Currently there are two simulator structs, namely

    - Simulator: For simulating corresponding pHSystem struct (for pHODEs). The properties include:
            -> SYS::pHSystem
            -> dt::AbstractFloat (time stepping)
            -> method::Symbol
                -> Implemented: :Euler

    - DescriptorSimulator: For simulating corresponding pHDescriptorSystem struct (for pHDAEs)
            -> sys::pHDescriptorSystem
            -> dt::AbstractFloat (time stepping)
            -> method::Symbol
                -> Implemented: :Midpoint/:Gauss1 [1], :Gauss2 [1]
            -> project_ic::Bool 
                -> projects initial condition for index-1 consistency onto the constraint manifold of the DAE
            -> eps_reg::T      
                -> Regularization parameter for solver to work with non-singular matrices (better, numerical stability increased as well as error by O(eps_reg))


[1] Mehrmann, Volker, and Riccardo Morandin. "Structure-preserving discretization for port-Hamiltonian descriptor systems." 
    2019 IEEE 58th Conference on Decision and Control (CDC). IEEE, 2019.


Implementation specifications of solver
    -> :Gauss1 (Midpoint rule/ Gauss-Legendre collocation method with stage s = 1), 
        -> Convergence for ODEs: p = 2
        -> Convergence for DAEs with index 1: p = 2

    -> :Gauss2 (Gauss-Legendre collocation method with stage s = 2)
        -> Convergence for ODEs: p = 4
        -> Convergence for DAEs with index 1: p = 4
"""

module SimulatorModule

    export Simulator, simulate
    export DescriptorSimulator, simulate

    using LinearAlgebra
    # Parent module (needed for Simulator struct)
    using ..pHModule


    # --------------------------------------------------
    # Everything for pH ODE system of form x' = (J-R)Qx + Gu
    # Available solvers: Euler (explicit)
    # --------------------------------------------------
    struct Simulator{T<:AbstractFloat, SYS}
        sys::SYS
        dt::T
        method::Symbol
    end

    # Only Convert descriptor to ode system if E is invertible
    Simulator(sys::pHModule.pHDescriptorSystem, dt::T, method::Symbol) where {T<:AbstractFloat} = _E_full_rank(sys.E) ? Simulator(pHModule.to_pHODE(sys), dt, method) : error("E is singular; use DescriptorSimulator(sys, dt, :Midpoint or :Gauss2).")

    # rank check for E (pHDAE)
    @inline function _E_full_rank(E; atol=1e-10)
        if E isa Diagonal
            return all(abs.(diag(E)) .> atol)
        else
            U,S,V = svd(E; full=false)
            tol = max(atol, Base.eps(eltype(S))^(2/3) * opnorm(E, Inf))
            return minimum(S) > tol
        end
    end

    # --- helpers to call u and coerce to vector length m ---
    @inline function _as_vec(uv, m::Int)
        if uv isa Number
            return fill(uv, m)
        elseif uv isa AbstractVector
            @assert length(uv) == m "u must have length $m, got $(length(uv))"
            return uv
        else
            error("u(t) or u(t,x) must return a Number or a Vector of length $m")
        end
    end

    @inline function _call_u(u::Function, t, x)
        # try u(t,x); if that method doesn't exist, fall back to u(t)
        try
            return u(t, x)
        catch
            return u(t)
        end
    end

    # ---------- input access helpers (must appear before simulate) ----------
    # constant vector
    _getu(u::AbstractVector, i, t, x, m::Int) = u
    # m×nt time series (column i)
    _getu(u::AbstractMatrix, i, t, x, m::Int) = @view u[:, i]
    # function u(t) or u(t,x); returns Number or Vector
    _getu(u::Function, i, t, x, m::Int) = _as_vec(_call_u(u, t, x), m)
    # scalar constant
    _getu(u::Number,   i, t, x, m::Int) = fill(u, m)
    # fallback
    _getu(u,           i, t, x, m::Int) = u

    function simulate(sim::Simulator, x0::AbstractVector, u, tspan::AbstractVector)

        @assert eltype(tspan) <: Real
        n = sim.sys.n
        m = sim.sys.m
        nt = length(tspan)

        X = similar(x0, n, nt); X[:, 1] = x0
        Y = fill(zero(eltype(x0)), m, nt)

        x = copy(x0)
        dx = similar(x0)
        Qx = similar(x0)

        for i in 1:nt
            t = tspan[i]
            ui = _getu(u, i, t, x, m)
            @assert length(ui) == m

            # Save state & output
            X[:, i] = x
            Y[:, i] = pHModule.output(sim.sys, x)

            # step
            if i < nt
                if sim.method === :Euler
                    pHModule.dynamics!(dx, sim.sys, x, ui, Qx)
                    @. x = x + sim.dt * dx
                else
                    error("Unknown solver: $(sim.method). Allowed: :Euler")
                end
            end
        end
        return tspan, X, Y
    end

    # ------------------------------------------------------------------------------------------------------------------------------------------------------------------
    # Everything for pH DAE system of form Ex' = (J-R)x + Gu
    # Existing solvers: :Midpoint, :Gauss1, :Gauss2
    # ------------------------------------------------------------------------------------------------------------------------------------------------------------------
    
    struct DescriptorSimulator{T<:AbstractFloat, SYS}
        sys::SYS
        dt::T
        method::Symbol   # :Midpoint (recommended), or :BE (BackwardEuler)
        project_ic::Bool # project initial condition for index-1 consistency
        eps_reg::T      # Regularization for solver to work with non-singular matrices
    end

    # Convenience constructor
    DescriptorSimulator(sys, dt, method::Symbol, project_ic::Bool = true; eps_reg = 0.0) = 
        DescriptorSimulator(sys, float(dt), method, project_ic, float(eps_reg))

    # Regularization helper
    function _regularize_M(sys, M::AbstractMatrix, eps_reg::Real)
        # projector onto Null(E'): Nnull * Nnull' (via thin SVD)
        U,S,V = svd(sys.E; full=false)
        tol = max(1e-10, Base.eps(eltype(S))^(2/3) * opnorm(sys.E, Inf))
        r = count(>(tol), S)
        if r == size(sys.E,1)
            return M  # full rank: nothing to do
        end
        Nnull = U[:, r+1:end]
        return M + eps_reg * (Nnull * Nnull')
    end

    # Average u between steps for Midpoint; fallbacks if i==nt
    function _u_half(u, i, t, dt, x, m::Int, nt::Int)
        if i < nt && u isa AbstractMatrix
            return 0.5 .* (@view u[:, i]) .+ 0.5 .* (@view u[:, i+1])
        elseif u isa Function
            # use helpers to support u(t) and u(t,x), and coerce Number→Vector
            return _as_vec(_call_u(u, t + dt/2, x), m)
        else
            return _getu(u, i, t, x, m)  # constant vector/number
        end
    end

    # Gauss Runge-Kutta tableaux (s = 1, 2)
    function _gauss_tableau(s::Int)
        if s == 1
            A = reshape(0.5, 1, 1)
            b = [1.0]
            c = [0.5]
        elseif s == 2
            a11 = 1/4; a22 = 1/4
            a12 = 1/4 - sqrt(3)/6
            a21 = 1/4 + sqrt(3)/6
            A = [a11 a12; a21 a22]
            b = [0.5, 0.5]
            c = [0.5 - sqrt(3)/6, 0.5 + sqrt(3)/6]
        else 
            error("Gauss s must be 1 or 2 for this implementation.")
        end
        return A, b, c
    end

    # Building the stage matrix
    function _build_stage_matrix(sys::pHDescriptorSystem, dt, A_rk)
        A = (sys.J - sys.R) * sys.Qe    # or using state_matrix(sys)
        s = size(A_rk, 1)
        return kron(Matrix(I, s, s), sys.E) .- dt .* kron(A_rk, A)
    end

    # Regularization for stage matrix (similar to _regularize_M)
    # Adds eps_reg * (I_S ⊗ P_null) with P_null projector onto Null(E')
    function _regularize_stage(sys::pHDescriptorSystem, Ms, s, eps_reg::Real)
        U,S,V = svd(sys.E; full=false)
        tol = max(1e-10, Base.eps(eltype(S))^(2/3)* opnorm(sys.E, Inf))
        r = count(>(tol), S)
        if r == size(sys.E, 1)
            return Ms
        end
        Nnull = U[:, r+1:end]
        P = Nnull * Nnull'
        return Ms .+ eps_reg .* kron(Matrix(I, s, s), P)
    end

    # Evaluate u at Gauss nodes (for :Gauss2)
    function _u_gauss_nodes(u, t_k, dt, x_k, m::Int, s::Int, c::AbstractVector, i_step::Int, nt::Int)
        Us = Matrix{Float64}(undef, m, s)  # or Matrix{eltype(dt)} if you prefer
        for j in 1:s
            tj = t_k + c[j]*dt
            if u isa Function
                uj = _as_vec(_call_u(u, tj, x_k), m)
            elseif u isa AbstractMatrix
                if i_step < nt
                    u0 = @view u[:, i_step]
                    u1 = @view u[:, i_step+1]
                    uj = (1 - c[j]) .* u0 .+ c[j] .* u1
                else
                    uj = @view u[:, i_step]
                end
            elseif u isa AbstractVector
                uj = u
            elseif u isa Number
                uj = fill(u, m)
            else
                uj = _getu(u, i_step, t_k, x_k, m)
            end
            @assert length(uj) == m "u at Gauss node must have length $m"
            Us[:, j] = uj
        end
        return Us
    end

    # Core Gauss stepper (s=1 or 2). Returns updated x and (optionally) stage effort y_nodes if you want them.
    function _step_gauss!(x, sys, dt, A_rk, b, c, F, s, u_nodes)
        n = sys.n; m = sys.m
        A = state_matrix(sys)

        # RHS: vec( (1_s ⊗ A) x_k + (1_s ⊗ G) u_nodes )
        rhs = zeros(eltype(x), s*n)
        Ax = A * x
        for j in 1:s
            rhs[(j-1)*n+1 : j*n] .= Ax .+ sys.G * @view(u_nodes[:,j])
        end

        # Solve for stacked K (sn-vector)
        K = F \ rhs

        # Update x_{k+1} = x_k + dt * sum_j b_j * K_j
        # with K_j being the j-th n-block of K
        acc = zero(eltype(x))
        x_new = similar(x)
        x_new .= x
        for j in 1:s
            Kj = @view K[(j-1)*n+1 : j*n]
            @. x_new = x_new + dt * b[j] * Kj
        end
        return x_new
    end

    
    # One-shot IC projection to the constraint manifold for index-1 DAEs:
    # Enforce N' * ((J-R)Q x + G u) = 0 with a cheap Newton correction Δx.
    function _project_ic!(x::AbstractVector, sys::pHDescriptorSystem, u::AbstractVector;
                        atol::Real=1e-10)
        E = sys.E
        # Null space of E' via thin SVD (cheap for moderate n)
        U,S,V = svd(E; full=false)
        r = sum(S .> max(atol, eps(eltype(S))^(2/3) * opnorm(E, Inf)))
        if r == size(E,1) || r == size(E,2)
            return x  # full rank -> no algebraic constraints
        end
        N = U[:, r+1:end]              # columns span Null(E')
        A = state_matrix(sys)
        g = A * x + sys.G * u
        rhs = - N' * g
        M = N' * A
        # least-norm Δx to satisfy N'*(A (x + Δx) + G u) = 0
        delta_x = M \ rhs
        x .+= delta_x
        return x
    end

    function simulate(sim::DescriptorSimulator, x0::AbstractVector, u, tspan::AbstractVector)
        sys = sim.sys
        n, m = sys.n, sys.m
        nt = length(tspan)
        dt = sim.dt
        A = pHModule.state_matrix(sys)

        # outputs
        X = similar(x0, n, nt)
        Y = fill(zero(eltype(x0)), m, nt)

        method = sim.method
        is_gauss = method === :Gauss1 || method === :Gauss2 || method === :Midpoint

        # Precompute/factorize
        F_mid = nothing
        if method === :BE || method === :Midpoint || method === :Gauss1
            # Midpoint/Gauss1 (same stage matrix), BE keep your previous code path if you like
            if method === :BE
                M = sys.E - dt * A
                N = sys.E
                F_mid = try
                    lu(M)
                catch e
                    if e isa SingularException && sim.eps_reg > 0
                        Mreg = _regularize_stage(sys, M, 1, sim.eps_reg)
                        lu(Mreg)
                    else
                        rethrow()
                    end
                end
            else
                # Gauss1 / Midpoint stage matrix
                M = sys.E - (dt/2) * A
                F_mid = try
                    lu(M)
                catch e
                    if e isa SingularException && sim.eps_reg > 0
                        Mreg = _regularize_stage(sys, M, 1, sim.eps_reg)
                        lu(Mreg)
                    else
                        rethrow()
                    end
                end
            end
        elseif method === :Gauss2
            A_rk, b, c = _gauss_tableau(2)
            Ms = _build_stage_matrix(sys, dt, A_rk)
            Ms = (sim.eps_reg > 0) ? _regularize_stage(sys, Ms, 2, sim.eps_reg) : Ms
            F_mid = lu(Ms)
        else
            error("Unknown method $(sim.method). Allowed: :BE, :Midpoint, :Gauss1, :Gauss2")
        end

        # IC
        x = copy(x0)
        if sim.project_ic
            ui = _getu(u, 1, tspan[1], x, m)
            _project_ic!(x, sys, ui)
        end

        # Time loop
        for i in 1:nt
            t = tspan[i]
            X[:, i] = x
            Y[:, i] = pHModule.output(sys, x)

            if i == nt; break; end

            if method === :BE
                unext = _getu(u, i+1, t + dt, x, m)
                rhs = sys.E * x + dt * (sys.G * unext)
                x = F_mid \ rhs

            elseif method === :Midpoint || method === :Gauss1
                # 1-stage Gauss
                # K = (E - dt/2 A)^{-1} (A x + G u_{mid}), x_{k+1} = x + dt K
                uhalf = _u_half(u, i, t, dt, x, m, nt)
                rhs = (A * x) + sys.G * uhalf
                K = F_mid \ rhs
                @. x = x + dt * K

            elseif method === :Gauss2
                # 2-stage Gauss
                A_rk, b, c = _gauss_tableau(2)
                # u at Gauss nodes
                U_nodes = _u_gauss_nodes(u, t, dt, x, m, 2, c, i, nt)  # m×2
                x = _step_gauss!(x, sys, dt, A_rk, b, c, F_mid, 2, U_nodes)

            else
                error("Unknown method $(sim.method)")
            end
        end

        return tspan, X, Y
    end



    # End of module
end