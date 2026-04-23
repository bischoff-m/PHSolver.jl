
struct PhsState
    x::AbstractVector{Float64}
    dx::AbstractVector{Float64}
    J::AbstractMatrix{Float64}
    R::AbstractMatrix{Float64}
    Q::AbstractMatrix{Float64}
    B::AbstractMatrix{Float64}
    u::AbstractVector{Float64}
    y::AbstractVector{Float64}
    system::PhsSystem

    function PhsState(system::PhsSystem)
        # Use sparse matrices and vectors for all
        size = length(system.ids)
        x = spzeros(Float64, size)
        dx = spzeros(Float64, size)
        J = spzeros(Float64, size, size)
        R = spzeros(Float64, size, size)
        Q = spzeros(Float64, size, size)
        B = spzeros(Float64, size, size)
        u = spzeros(Float64, size)
        y = spzeros(Float64, size)
        return new(x, dx, J, R, Q, B, u, y, system)
    end
end

function evolve!(state::PhsState, params::Dict{Symbol,Float64})
    # Evaluate all ref functions with current parameters
    for func in state.system.functions
        update_ref!(func, params)
    end

    # Evaluate FloatOrRef fields
    eval_float_or_ref!(state.J, state.system.interaction)
    eval_float_or_ref!(state.R, spdiagm(state.system.dissipation))
    eval_float_or_ref!(state.Q, spdiagm(state.system.mass))
    eval_float_or_ref!(state.B, spdiagm(state.system.input))
    eval_float_or_ref!(state.u, state.system.signal)

    # Compute output
    state.y .= transpose(state.B) * state.Q * state.x
end


function pprint(state::PhsState)
    Term.tprintln(Term.highlight("PhsState", :type))
    Term.tprintln("State dimension:", length(state.x))
    pprint(
        state.system.ids,
        state.x,
        state.dx,
        state.R[diagind(state.R)],
        state.Q[diagind(state.Q)],
        state.B[diagind(state.B)],
        state.u,
        state.y,
        ;
        header=["id", "x", "dx", "R", "Q", "B", "u", "y"],
        title="System (R, Q, B, u, y)",
    )
    pprint(
        state.system.ids,
        state.J;
        header=["id"; string.(1:size(state.J, 2))...],
        title="Interaction (J)",
    )
end