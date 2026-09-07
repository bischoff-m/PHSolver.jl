
struct PhsState
    J::AbstractMatrix{Float64}
    R::AbstractMatrix{Float64}
    E::AbstractMatrix{Float64}
    B::AbstractMatrix{Float64}
    u::AbstractVector{Float64}
    y::AbstractVector{Float64}
    system::PhsSystem
    sim_config::SimConfig
    values::Dict{Symbol,Float64}
    state_keys::Vector{Symbol}
    # Cache symbolic matrices so update only refreshes values, not sparse structure.
    interaction_refs::AbstractMatrix
    dissipation_refs::AbstractMatrix
    mass_refs::AbstractMatrix
    input_refs::AbstractMatrix

    function PhsState(system::PhsSystem, sim_config::SimConfig, free_vars::Dict{Symbol,Float64}=Dict())
        # Use sparse matrices and vectors for all
        size = length(system.ids)
        J = spzeros(Float64, size, size)
        R = spzeros(Float64, size, size)
        E = spzeros(Float64, size, size)
        B = spzeros(Float64, size, size)
        u = spzeros(Float64, size)
        y = spzeros(Float64, size)
        values = Dict{Symbol,Float64}()
        state_keys = Symbol.(system.ids .* ".x")
        interaction_refs = system.interaction
        dissipation_refs = spdiagm(system.dissipation)
        mass_refs = spdiagm(system.mass)
        input_refs = spdiagm(system.input)
        state = new(
            J, R, E, B, u, y, system, sim_config, values, state_keys,
            interaction_refs, dissipation_refs, mass_refs, input_refs
        )

        x0 = zeros(Float64, size)
        update(state, free_vars, x0)
        eval_refs!(x0, system.x0)
        update(state, free_vars, x0)

        return state
    end
end

function update(
    state::PhsState,
    params::Dict{Symbol,Float64},
    x::AbstractVector{<:Real}=zeros(Float64, length(state.system.ids))
)
    values = state.values
    empty!(values)
    for (key, value) in params
        values[key] = value
    end
    for index in eachindex(state.state_keys)
        values[state.state_keys[index]] = Float64(x[index])
    end

    # Evaluate all ref functions with current parameters
    for func in state.system.functions
        update_ref!(func, values)
    end

    # Evaluate FloatOrRef fields
    eval_refs!(state.J, state.interaction_refs)
    eval_refs!(state.R, state.dissipation_refs)
    eval_refs!(state.E, state.mass_refs)
    eval_refs!(state.B, state.input_refs)
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

function residual!(
    out::AbstractVector{T},
    state::PhsState,
    x::AbstractVector{T},
    dx::AbstractVector{T}
) where {T<:Real}
    # Accumulate directly into out to avoid temporary products and extra vector passes.
    mul!(out, state.E, dx)
    mul!(out, state.J, x, -1.0, 1.0)
    mul!(out, state.R, x, 1.0, 1.0)
    mul!(out, state.B, state.u, -1.0, 1.0)
    return out
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