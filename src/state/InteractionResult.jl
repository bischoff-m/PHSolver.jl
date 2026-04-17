import Term


struct SignedRef
    ref::Ref{Float64}
    sign::Float64
end

Base.getindex(x::SignedRef) = x.sign * x.ref[]
Base.setindex!(x::SignedRef, v) = (x.ref[] = x.sign * Float64(v))

function Base.show(io::IO, x::SignedRef)
    if x.sign == -1.0
        print(io, "-")
        show(io, x.ref)
    elseif x.sign == 1.0
        show(io, x.ref)
    else
        print(io, x.sign, "*")
        show(io, x.ref)
    end
end


struct InteractionResult
    interaction::AbstractMatrix{Union{Float64,SignedRef}}
    input::AbstractVector{FloatOrRef}

    function InteractionResult(
        interaction::AbstractMatrix{Union{Float64,SignedRef}},
        input::AbstractVector{FloatOrRef}
    )
        new(interaction, input)
    end

    function InteractionResult(n::Int)
        interaction = Matrix{Union{Float64,SignedRef}}(undef, n, n)
        input = Vector{FloatOrRef}(undef, n)
        fill!(interaction, 0.0)
        fill!(input, 0.0)
        return new(interaction, input)
    end
end

function pprint(result::InteractionResult)
    Term.tprintln(Term.highlight("InteractionResult", :type))
    pprint(result.interaction, header="Interaction")
    pprint(result.input, header="Input")
    println()
end