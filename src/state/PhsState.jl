
struct PhsState
    J::AbstractMatrix{Float64}
    R::AbstractMatrix{Float64}
    E::AbstractMatrix{Float64}
    B::AbstractMatrix{Float64}
    u::AbstractVector{Float64}
    y::AbstractVector{Float64}
    system::PhsSystem
    sim_config::SimConfig

    function PhsState(system::PhsSystem, sim_config::SimConfig, free_vars::Dict{Symbol,Float64}=Dict())
        # Use sparse matrices and vectors for all
        size = length(system.ids)
        J = spzeros(Float64, size, size)
        R = spzeros(Float64, size, size)
        E = spzeros(Float64, size, size)
        B = spzeros(Float64, size, size)
        u = spzeros(Float64, size)
        y = spzeros(Float64, size)
        state = new(J, R, E, B, u, y, system, sim_config)

        # Evaluate ref functions
        update(state, free_vars)

        return state
    end
end

function update(state::PhsState, params::Dict{Symbol,Float64})
    # Evaluate all ref functions with current parameters
    for func in state.system.functions
        update_ref!(func, params)
    end

    # Evaluate FloatOrRef fields
    eval_refs!(state.J, state.system.interaction)
    eval_refs!(state.R, spdiagm(state.system.dissipation))
    eval_refs!(state.E, spdiagm(state.system.mass))
    eval_refs!(state.B, spdiagm(state.system.input))
    eval_refs!(state.u, state.system.signal)
end

function dynamics_rhs(state::PhsState, x::AbstractVector{T}) where {T<:Real}
    return (state.J - state.R) * x + state.B * state.u
end

function dynamics_lhs(state::PhsState, dx::AbstractVector{T}) where {T<:Real}
    return state.E * dx
end

function dynamics_output(state::PhsState, x::AbstractVector{T}) where {T<:Real}
    return transpose(state.B) * x
end

function residual(state::PhsState, x::AbstractVector{T}, dx::AbstractVector{T}) where {T<:Real}
    return dynamics_lhs(state, dx) - dynamics_rhs(state, x)
end

function hamiltonian(state::PhsState, x::AbstractVector{T}) where {T<:Real}
    return 0.5 * transpose(x) * state.E * x
end


function pprint(state::PhsState)
    Term.tprintln(Term.highlight("PhsState", :type))
    Term.tprintln("State dimension:", length(state.system.ids))
    pprint(
        state.system.ids,
        state.R[diagind(state.R)],
        state.E[diagind(state.E)],
        state.B[diagind(state.B)],
        state.u,
        state.y,
        ;
        header=["id", "R", "E", "B", "u", "y"],
        title="System (R, E, B, u, y)",
    )
    pprint(
        state.system.ids,
        state.J;
        header=["id"; string.(1:size(state.J, 2))...],
        title="Interaction (J)",
    )
end