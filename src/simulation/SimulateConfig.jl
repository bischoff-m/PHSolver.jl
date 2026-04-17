import Term
import Symbolics as Sym
import Logging: global_logger
import TerminalLoggers: TerminalLogger
global_logger(TerminalLogger(right_justify=120))

struct StateFunction
    func::Function
    dependencies::Vector{Symbol}
    result_ref::Ref{Float64}
end

function StateFunction(def::Definition)
    # Sort variables alphabetically for consistent function signatures
    vars_set = union(def.rhs_vars, def.lhs_vars)
    vars = sort(collect(vars_set))
    sym_vars = Sym.variable.(vars)

    # Build the function
    func = Sym.build_function(def.eq.rhs, sym_vars...; expression=false)
    return StateFunction(func, vars, Ref{Float64}(0.0))
end

function evaluate(sf::StateFunction, values::Dict{Symbol,<:Real})
    args = map(sf.dependencies) do sym
        haskey(values, sym) || error("Missing value for dependency: $sym")
        Float64(values[sym])
    end
    return sf.func(args...)
end

function update!(sf::StateFunction, values::Dict{Symbol,<:Real})
    sf.result_ref[] = evaluate(sf, values)
end

FloatOrRef = Union{Float64,Ref{Float64}}

struct CollectResult
    dissipation::AbstractVector{FloatOrRef}
    mass::AbstractVector{FloatOrRef}
    x0::AbstractVector{FloatOrRef}
    id_to_index::Dict{String,Int}
    port_to_index::Dict{String,Int}
    functions::AbstractVector{StateFunction}

    function CollectResult()
        new(
            Vector{FloatOrRef}(),
            Vector{FloatOrRef}(),
            Vector{FloatOrRef}(),
            Dict{String,Int}(),
            Dict{String,Int}(),
            Vector{StateFunction}()
        )
    end
end

function pprint(result::CollectResult)
    Term.tprintln(Term.highlight("CollectResult", :type))
    Term.tprintln("Number of components: ", length(result.id_to_index))
    Term.tprintln("Number of functions: ", length(result.functions))

    Term.tprint(Term.Tree(result.id_to_index; title="ID to Index"))
    Term.tprint(Term.Tree(result.port_to_index; title="Port to Index"))
    pprint(result.dissipation, header="Dissipation")
    pprint(result.mass, header="Mass")
    pprint(result.x0, header="Initial Conditions")
    println()
end


function get_index(result::CollectResult, id::String)
    id_map = merge(result.id_to_index, result.port_to_index)
    haskey(id_map, id) || error("ID not found: $id")
    return id_map[id]
end

function has_index(result::CollectResult, id::String)
    id_map = merge(result.id_to_index, result.port_to_index)
    return haskey(id_map, id)
end


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

function iter_config!(
    config::Component,
    handler::Function,
    name_stack=String[]
)
    name_stack = push!(name_stack, config.id)
    current_id = join(name_stack, ".")
    handler(config, current_id)

    pop!(name_stack)
    return Dict(config.id => nothing)
end


function iter_config!(
    config::SystemConfig,
    handler::Function,
    name_stack=String[]
)
    name_stack = push!(name_stack, config.id)
    current_id = join(name_stack, ".")

    namespace = Dict{String,Any}()
    for sys in config.systems
        subspace = iter_config!(sys, handler, name_stack)
        namespace = merge(namespace, subspace)
    end

    handler(config, current_id)
    pop!(name_stack)
    return Dict(config.id => namespace)
end

function print_namespace(namespace::Dict; prefix="")
    Term.tprintln(Term.highlight("Namespace", :symbol))
    function inner(subspace, prefix)
        keys_sorted = sort(collect(keys(subspace)))
        for (i, key) in enumerate(keys_sorted)
            val = subspace[key]
            color = isnothing(val) ? :number : :code
            if i == length(keys_sorted)
                Term.tprintln(
                    prefix *
                    Term.highlight("└─ ", :emphasis) *
                    Term.highlight(key, color)
                )
                isnothing(val) || inner(val, prefix * "   ")
            else
                Term.tprintln(
                    Term.highlight(prefix * "├─ ", :emphasis) *
                    Term.highlight(key, color)
                )
                isnothing(val) || inner(val, prefix * "│  ")
            end
        end
    end
    inner(namespace, prefix)
    println()
end

function encode_symbolic(sym::Symbol, val::Union{Float64,String}, defs::Definitions; keep::Set{Symbol}=Set{Symbol}())
    if isa(val, Number)
        return Float64(val)
    elseif !isa(val, String)
        error("Unsupported type for $sym: $(typeof(val)). " *
              "Expected Number or String expression.")
    end

    # Parse string to symbolic expression
    def = Definition(sym, val)
    def = resolve_definition(def, defs; keep=keep)

    # Check if rhs is fully resolved to a constant
    if isempty(def.rhs_vars)
        f = Sym.build_function(def.eq.rhs; expression=false)
        return Float64(f())
    end

    free_vars = union(def.rhs_vars, def.lhs_vars)
    if !isempty(setdiff(free_vars, keep))
        error("Definition $(def.eq) has dependencies that are " *
              "not fixed variables.")
    end
    return StateFunction(def)
end

"""
    simulate_config(config::RootConfig)

Load, assemble, and solve a network configuration.

Returns a `SimulationResult` containing the solution, assembled system, and
network metadata.
"""
function simulate_config(config::SystemConfig; verbose=false)
    fixed_vars = Set([:t])

    defs = parse_definitions(config.definitions)
    graph = DefinitionGraph()
    add_defs!(graph, defs)
    resolve_graph!(graph; keep=fixed_vars)
    defs = graph.definitions

    result1 = CollectResult()
    idx = 1
    function handler1(config, id)
        if isa(config, SystemConfig)
            # Add ports as aliases
            for (port_name, target) in config.ports
                port_id = id * "." * port_name
                target_id = id * "." * target
                result1.port_to_index[port_id] = get_index(result1, target_id)
            end

            return
        elseif !isa(config, Component)
            error("Unknown config type: $(typeof(config)) for id: $id")
        end

        # Add id to index map
        result1.id_to_index[id] = idx

        for sym in [:dissipation, :mass, :x0]
            val = getfield(config, sym)
            id_sym = Symbol(id, ".", sym)
            encoded = encode_symbolic(id_sym, val, defs; keep=fixed_vars)

            container = getfield(result1, sym)
            if isa(encoded, StateFunction)
                push!(result1.functions, encoded)
                push!(container, encoded.result_ref)
            elseif isa(encoded, Float64)
                push!(container, encoded)
            else
                error("Unexpected return type from encode_symbolic: $(typeof(encoded))")
            end
        end
        idx += 1
    end
    namespace = iter_config!(config, handler1)

    # Parse connections and signals
    result2 = InteractionResult(length(result1.id_to_index))
    id_map = result1.id_to_index
    function handler2(config, id)
        !isa(config, SystemConfig) && return

        # Parse connections
        for conn in config.connections
            ids = Dict("from" => conn.from, "to" => conn.to)
            ids = Dict(k => id * "." * v for (k, v) in ids)

            for (key, val) in ids
                haskey(id_map, val) || error("Connection '$key' id not found: $val")
            end
            ids = Dict(k => id_map[v] for (k, v) in ids)
            from = ids["from"]
            to = ids["to"]

            if result2.interaction[to, from] != 0.0 || result2.interaction[from, to] != 0.0
                error("Duplicate connection from $from to $to")
            end

            encoded = encode_symbolic(:weight, conn.weight, defs; keep=fixed_vars)
            if isa(encoded, StateFunction)
                push!(result1.functions, encoded)
                result2.interaction[from, to] = SignedRef(encoded.result_ref, 1.0)
                result2.interaction[to, from] = SignedRef(encoded.result_ref, -1.0)
            elseif isa(encoded, Float64)
                result2.interaction[from, to] = encoded
                result2.interaction[to, from] = -encoded
            else
                error("Unexpected return type from encode_symbolic for " *
                      "connection weight: $(typeof(encoded))")
            end
        end

        # Parse signals
        for (signal_name, target) in config.signals
            signal_id = id * "." * signal_name
            target_idx = get_index(result1, signal_id)
            encoded = encode_symbolic(:signal, target, defs; keep=fixed_vars)

            if isa(encoded, StateFunction)
                push!(result1.functions, encoded)
                result2.input[target_idx] = encoded.result_ref
            elseif isa(encoded, Float64)
                result2.input[target_idx] = encoded
            else
                error("Unexpected return type from encode_symbolic for " *
                      "signal $signal_id: $(typeof(encoded))")
            end
        end


    end
    iter_config!(config, handler2)

    if verbose
        print_namespace(namespace)
        pprint(result1)
        pprint(result2)
    end

    nothing


    # Load network
    # network = network_from_config(config.network, Float64)
    # sim_config = config.simulation
    # Term.tprintln("  {bold green}✓{/bold green} Configuration: t=$(sim_config.time_span), solver={cyan}$(sim_config.solver){/cyan}")

    # # Assemble network
    # sim_input = dynamics_from_network(network)
    # n_nodes = length(network.nodes)
    # n_states = length(sim_input.x0)
    # Term.tprintln("  {bold green}✓{/bold green} Assembled {cyan}$n_nodes{/cyan} nodes → {cyan}$n_states{/cyan} state variables")

    # # Solve
    # sol = solve_phs(sim_input, sim_config=sim_config)
    # # sol = solve_phs_realtime(sim_input, sim_config=sim_config)
    # Term.tprintln("  {bold green}✓{/bold green} Solved DAE: {cyan}$(length(sol.t)){/cyan} time points, t_final={cyan}$(round(sol.t[end], digits=2)){/cyan}")

    # return SimulationResult(sol, sim_input.system, network)
end

"""
    simulate_file(config_path::String)

Complete workflow: read config, assemble the network, and solve it.

# Arguments
- `config_path::String`: Path to the YAML configuration file

# Returns
- `SimulationResult`: Struct containing system, solution, and network metadata
"""
function simulate_file(config_path::String; verbose=false)
    config = read_config(config_path)
    println("Loaded configuration from: $config_path")
    return simulate_config(config, verbose=verbose)
end
