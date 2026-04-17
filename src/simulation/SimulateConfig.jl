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

struct PhsState
    dissipation::Vector{FloatOrRef}
    mass::Vector{FloatOrRef}
    x0::Vector{FloatOrRef}
    id_to_index::Dict{String,Int}
    functions::Vector{StateFunction}

    function PhsState()
        new(
            Vector{FloatOrRef}(),
            Vector{FloatOrRef}(),
            Vector{FloatOrRef}(),
            Dict{String,Int}(),
            Vector{StateFunction}()
        )
    end
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
    handler(config, current_id)

    namespace = Dict{String,Any}()
    for sys in config.systems
        subspace = iter_config!(sys, handler, name_stack)
        namespace = merge(namespace, subspace)
    end

    pop!(name_stack)
    return Dict(config.id => namespace)
end

function print_namespace(namespace::Dict; prefix="")
    keys_sorted = sort(collect(keys(namespace)))
    for (i, key) in enumerate(keys_sorted)
        val = namespace[key]
        if i == length(keys_sorted)
            println(prefix * "└───" * key)
            isnothing(val) || print_namespace(val; prefix=prefix * "    ")
        else
            println(prefix * "├───" * key)
            isnothing(val) || print_namespace(val; prefix=prefix * "│   ")
        end
    end
end


"""
    simulate_config(config::RootConfig)

Load, assemble, and solve a network configuration.

Returns a `SimulationResult` containing the solution, assembled system, and
network metadata.
"""
function simulate_config(config)
    fixed_vars = Set([:t])
    # TODO: Construct entire state matrix with refs in on pass over the config
    # Save functions to calculate state and link them with the matrix entries
    defs = parse_definitions(config.definitions)
    graph = DefinitionGraph()
    add_defs!(graph, defs)
    resolve_graph!(graph; keep=fixed_vars)


    # expr = :(scale(R_L + L) * R_G + 2t)

    # def = Definition(:u, expr)
    # def = resolve_definition(def, graph.definitions; keep=Set([:t]))
    # println("Resolved definition: $def")

    # func = StateFunction(def)
    # println("Function result ref: ", func.result_ref)
    # update!(func, Dict(:t => 5.0))
    # println("Function result ref: ", func.result_ref)


    state = PhsState()
    idx = 0
    # Build dict of dissipation, mass, and initial state -> definitions
    # Parse expr to symbolic
    # Find RHS dependencies
    # Apply substitutions for given dependencies
    # Build function with remaining dependencies as arguments (in order)
    # Create Ref, function, and dependencies tuple
    function handler(config, id)
        if isa(config, SystemConfig)
            println("System handler called for $id")
            return
        elseif !isa(config, Component)
            error("Unknown config type: $(typeof(config)) for id: $id")
        end

        println("Component handler called for $id")
        # Add id to index map
        state.id_to_index[id] = idx

        for sym in [:dissipation, :mass, :x0]
            val = getfield(config, sym)
            container = getfield(state, sym)
            if typeof(val) <: Number
                push!(container, val)
            elseif typeof(val) <: String
                # Parse string to symbolic expression
                def = Definition(sym, val)
                def = resolve_definition(def, graph.definitions; keep=fixed_vars)
                println("Resolved definition for $id.$sym: $def")

                # Check if rhs is a number or an expression with dependencies
                if isempty(def.rhs_vars)
                    f = Sym.build_function(def.eq.rhs; expression=false)
                    push!(container, Float64(f()))
                else
                    free_vars = union(def.rhs_vars, def.lhs_vars)
                    if !isempty(setdiff(free_vars, fixed_vars))
                        error("Definition $(def.eq) has dependencies that are " *
                              "not fixed variables.")
                    end
                    func = StateFunction(def)
                    push!(state.functions, func)
                    push!(container, func.result_ref)
                end
            else
                error("Unsupported type for $id.$sym: $(typeof(val)). " *
                      "Expected Number or String expression.")
            end
        end

        idx += 1
    end
    namespace = iter_config!(config, handler)

    @show state.id_to_index
    @show state.dissipation
    @show state.mass
    @show state.x0
    @show state.functions
    # println(namespace)
    # namespace = Dict(
    #     "DGU_example" => Dict(
    #         "controller_d" => Dict(
    #             "dissipation" => state.dissipation[1],
    #             "mass" => state.mass[1],
    #             "x0" => state.x0[1]
    #         )
    #     )
    # )
    print_namespace(namespace)
    nothing

    # @show config
    # for sys in iter_config(config)
    #     println("System: $(sys.id) isa $(typeof(sys))")
    # end

    # TODO: Construct PhsNodeNew instances and save in a tree
    # https://github.com/JuliaCollections/AbstractTrees.jl/tree/master

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
function simulate_file(config_path::String)
    config = read_config(config_path)
    println("Loaded configuration from: $config_path")
    return simulate_config(config)
end
# function simulate_file(config_path::String)
#     config = read_config(config_path)
#     println("Loaded configuration from: $config_path")
#     # return simulate_config(config)
#     println("Definitions: ", config.definitions)
#     # Split lines
#     lines = split(config.definitions, '\n')
#     defs = parse_definitions(lines)


#     graph = DefinitionGraph()
#     add_defs!(graph, defs)
#     @show graph

#     resolve_parameters!(graph; keep=Set([:t]), verbose=false)
#     println()
#     @show graph

#     u = Sym.value(graph.definitions[:u].eq.rhs)
#     println("u before evaluation: $u")
#     # u = Sym.evaluate(u, Dict("P" => 10.0, "t" => 5.0))
#     u = Sym.evaluate(u, Dict(Sym.variable(:P) => 10.0, Sym.variable(:t) => 50000.0))
#     println("u = $u")
#     nothing
# end
