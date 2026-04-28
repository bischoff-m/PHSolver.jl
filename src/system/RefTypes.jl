
using SparseArrays

abstract type AbstractRef end

Base.getindex(x::AbstractRef) = error("getindex not implemented for $(typeof(x))")
Base.setindex!(x::AbstractRef, v) = error("setindex! not implemented for $(typeof(x))")

struct SignedRef <: AbstractRef
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



FloatOrRef = Union{Float64,Ref{Float64},<:AbstractRef}

# SparseMatrixCSC getindex on absent entries calls zero(eltype(A))
Base.zero(::Type{Union{Float64,SignedRef}}) = 0.0
Base.zero(::Type{FloatOrRef}) = 0.0

tofloat(x::Float64) = x
tofloat(x::Union{Ref{Float64},AbstractRef}) = x[]

function eval_refs!(
    out::AbstractVecOrMat{Float64},
    v::AbstractVecOrMat{<:FloatOrRef}
)
    size(out) != size(v) && error("Size mismatch: size(out) = $(size(out)), size(v) = $(size(v))")
    @inbounds @simd for i in eachindex(v, out)
        out[i] = tofloat(v[i])
    end
    return out
end

function eval_refs!(
    out::AbstractVector{Float64},
    v::SparseVector{<:FloatOrRef}
)
    size(out) != size(v) && error("Size mismatch: size(out) = $(size(out)), size(v) = $(size(v))")
    I, V = findnz(v)
    @inbounds @simd for k in eachindex(V)
        out[I[k]] = tofloat(V[k])
    end
    return out
end

function eval_refs!(
    out::AbstractMatrix{Float64},
    v::SparseMatrixCSC{<:FloatOrRef}
)
    size(out) != size(v) && error("Size mismatch: size(out) = $(size(out)), size(v) = $(size(v))")
    I, J, V = findnz(v)
    @inbounds @simd for k in eachindex(V)
        out[I[k], J[k]] = tofloat(V[k])
    end
    return out
end
