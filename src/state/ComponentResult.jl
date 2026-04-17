import Term


FloatOrRef = Union{Float64,Ref{Float64}}

struct ComponentResult
    dissipation::AbstractVector{FloatOrRef}
    mass::AbstractVector{FloatOrRef}
    x0::AbstractVector{FloatOrRef}
    id_to_index::Dict{String,Int}
    port_to_index::Dict{String,Int}
    functions::AbstractVector{StateFunction}
    namespace::Namespace

    function ComponentResult()
        new(
            Vector{FloatOrRef}(),
            Vector{FloatOrRef}(),
            Vector{FloatOrRef}(),
            Dict{String,Int}(),
            Dict{String,Int}(),
            Vector{StateFunction}(),
            Dict{String,Any}()
        )
    end
end

function pprint(result::ComponentResult)
    Term.tprintln(Term.highlight("ComponentResult", :type))
    Term.tprintln("Number of components: ", length(result.id_to_index))
    Term.tprintln("Number of functions: ", length(result.functions))

    Term.tprint(Term.Tree(result.id_to_index; title="ID to Index"))
    Term.tprint(Term.Tree(result.port_to_index; title="Port to Index"))
    pprint(result.dissipation, header="Dissipation")
    pprint(result.mass, header="Mass")
    pprint(result.x0, header="Initial Conditions")
    println()
end


function get_index(result::ComponentResult, id::String)
    id_map = merge(result.id_to_index, result.port_to_index)
    haskey(id_map, id) || error("ID not found: $id")
    return id_map[id]
end

function has_index(result::ComponentResult, id::String)
    id_map = merge(result.id_to_index, result.port_to_index)
    return haskey(id_map, id)
end