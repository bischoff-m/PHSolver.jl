import Term

mutable struct PhsSystem
    # Initialized in first pass
    ids::AbstractVector{String}
    id_to_index::AbstractDict{String,Int}
    port_to_index::AbstractDict{String,Int}
    namespace::Namespace
    definitions::Definitions
    # Initialized in second pass
    dissipation::AbstractVector{FloatOrRef}
    mass::AbstractVector{FloatOrRef}
    input::AbstractVector{FloatOrRef}
    x0::AbstractVector{FloatOrRef}
    interaction::AbstractMatrix{Union{Float64,SignedRef}}
    signal::AbstractVector{FloatOrRef}
    functions::AbstractVector{RefFunction}

    function PhsSystem()
        new(
            String[],
            Dict{String,Int}(),
            Dict{String,Int}(),
            Dict{String,Any}(),
            Definitions(),
            FloatOrRef[],
            FloatOrRef[],
            FloatOrRef[],
            FloatOrRef[],
            spzeros(Union{Float64,SignedRef}, 0, 0),
            spzeros(FloatOrRef, 0),
            RefFunction[],
        )
    end
end

function init_size_dependent_fields!(result::PhsSystem)
    size = length(result.ids)
    result.interaction = spzeros(Union{Float64,SignedRef}, size, size)
    result.signal = spzeros(FloatOrRef, size)
end


function get_index(result::PhsSystem, id::String)
    id_map = merge(result.id_to_index, result.port_to_index)
    haskey(id_map, id) || error("ID not found: $id")
    return id_map[id]
end

function has_index(result::PhsSystem, id::String)
    id_map = merge(result.id_to_index, result.port_to_index)
    return haskey(id_map, id)
end


function pprint(result::PhsSystem)
    Term.tprintln(Term.highlight("PhsSystem", :type))
    Term.tprintln("State dimension:", length(result.ids))
    Term.tprintln("Number of functions:", length(result.functions))
    print_namespace(result.namespace)

    # Print mapping from port id to state id
    port_map = Dict(port => result.ids[id] for (port, id) in result.port_to_index)
    Term.tprint(Term.Tree(port_map; title="Port to ID"))

    pprint(
        result.ids,
        result.x0,
        result.dissipation,
        result.mass,
        result.input,
        result.signal,
        ;
        header=["id", "x0", "R", "E", "B", "u"],
        title="System (x0, R, E, B, u)",
    )
    pprint(
        result.ids,
        result.interaction;
        header=["id"; string.(1:size(result.interaction, 2))...],
        title="Interaction (J)",
    )
    println()
end