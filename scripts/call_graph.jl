#!/usr/bin/env julia
# Manually maintained GraphViz call tree for HamiltonSim.simulate_file.
#
# This is intentionally NOT a parser or static analyzer.
# Edit the NODES / EDGES sections to keep it in sync with the code.
#
# Usage:
#   julia scripts/callgraph_simulate_file_manual.jl --out ./output/callgraph.dot
#   julia scripts/callgraph_simulate_file_manual.jl --out ./output/callgraph.dot --render svg
#
# Rendering requires GraphViz (the `dot` executable) if you pass --render.

module ManualSimulateFileCallGraph

struct Node
    id::String          # DOT node id, e.g. "HamiltonSim.simulate_file" or "Eq.solve"
    title::String       # display name
    signature::String   # parameters + types (best-effort)
    description::String # short description
    file::String        # source file for grouping
end

struct Edge
    from::String
    to::String
    label::String       # "1" or "n"
end

function parse_args(args::Vector{String})
    opts = Dict{String,Any}(
        "out" => joinpath(pwd(), "output", "callgraph_simulate_file.dot"),
        "render" => nothing, # svg|png|pdf
    )

    i = 1
    while i <= length(args)
        a = args[i]
        if a in ("-o", "--out")
            i += 1
            opts["out"] = args[i]
        elseif a == "--render"
            i += 1
            opts["render"] = args[i]
        elseif a in ("-h", "--help")
            println("Generate a GraphViz call tree for HamiltonSim.simulate_file")
            println("\nOptions:")
            println("  --out <file.dot>        Output DOT path (default: ./output/callgraph_simulate_file.dot)")
            println("  --render <svg|png|pdf>  Render using GraphViz 'dot' if installed")
            exit(0)
        else
            error("Unknown argument: $a (try --help)")
        end
        i += 1
    end

    return opts
end

# ------------------------------
# NODES / EDGES (manual)
# ------------------------------

function define_graph()
    nodes = Dict{String,Node}()

    # Entry point + HamiltonSim internals (signatures copied from src/*)
    nodes["HamiltonSim.simulate_file"] = Node(
        "HamiltonSim.simulate_file",
        "HamiltonSim.simulate_file",
        "simulate_file(yaml_path::String)",
        "Complete workflow: read config, assemble network, solve DAE.",
        "src/NetworkSolver.jl",
    )

    nodes["HamiltonSim.read_config"] = Node(
        "HamiltonSim.read_config",
        "HamiltonSim.read_config",
        "read_config(filepath::String)::RootConfigSchema",
        "Load YAML, validate schema, parse into typed structs.",
        "src/YAMLParser.jl",
    )

    nodes["HamiltonSim.validate_config"] = Node(
        "HamiltonSim.validate_config",
        "HamiltonSim.validate_config",
        "validate_config(config_dict::Dict)",
        "Validate YAML configuration against JSON schema.",
        "src/YAMLParser.jl",
    )

    nodes["HamiltonSim.load_network_from_yaml"] = Node(
        "HamiltonSim.load_network_from_yaml",
        "HamiltonSim.load_network_from_yaml",
        "load_network_from_yaml(config::RootConfigSchema, ::Type{T}=Float64)",
        "Build NetworkGraph metadata from validated schema.",
        "src/YAMLParser.jl",
    )

    nodes["HamiltonSim.create_network_nodes_from_schema"] = Node(
        "HamiltonSim.create_network_nodes_from_schema",
        "HamiltonSim.create_network_nodes_from_schema",
        "create_network_nodes_from_schema(systems_schema::Vector{SystemSchema}, ::Type{T})",
        "Create PHSNode instances from schema objects.",
        "src/YAMLParser.jl",
    )

    nodes["HamiltonSim.assemble_network"] = Node(
        "HamiltonSim.assemble_network",
        "HamiltonSim.assemble_network",
        "assemble_network(graph::NetworkGraph{T})",
        "Assemble network into one PortHamSystem and initial state.",
        "src/NetworkAssembly.jl",
    )

    nodes["HamiltonSim.assemble_initial_state"] = Node(
        "HamiltonSim.assemble_initial_state",
        "HamiltonSim.assemble_initial_state",
        "assemble_initial_state(graph::NetworkGraph{T}, Q::Matrix{T})",
        "Compute x0 and differential variable indicators.",
        "src/NetworkAssembly.jl",
    )

    nodes["HamiltonSim.assemble_block_diagonal_matrix"] = Node(
        "HamiltonSim.assemble_block_diagonal_matrix",
        "HamiltonSim.assemble_block_diagonal_matrix",
        "assemble_block_diagonal_matrix(\n    nodes::Dict{String,PHSNode{T}},\n    matrix_getter::Function,\n)",
        "Collect per-node matrices into a block-diagonal matrix.",
        "src/Interconnection.jl",
    )

    nodes["HamiltonSim.create_block_diagonal"] = Node(
        "HamiltonSim.create_block_diagonal",
        "HamiltonSim.create_block_diagonal",
        "create_block_diagonal(matrices::Vector{Matrix{T}})",
        "Create a block diagonal matrix.",
        "src/Interconnection.jl",
    )

    nodes["HamiltonSim.apply_connection!"] = Node(
        "HamiltonSim.apply_connection!",
        "HamiltonSim.apply_connection!",
        "apply_connection!(\n    J_global::Matrix{T},\n    nodes::Dict{String,PHSNode{T}},\n    edge::ConnectionEdge{T},\n)",
        "Dispatch to connection-type-specific coupling.",
        "src/Interconnection.jl",
    )

    nodes["HamiltonSim.apply_direct_connection!"] = Node(
        "HamiltonSim.apply_direct_connection!",
        "HamiltonSim.apply_direct_connection!",
        "apply_direct_connection!(\n    J_global::Matrix{T},\n    node_source::PHSNode{T},\n    node_target::PHSNode{T},\n    edge::ConnectionEdge{T},\n)",
        "Apply direct interconnection: u_target = y_source.",
        "src/Interconnection.jl",
    )

    nodes["HamiltonSim.apply_negative_feedback_connection!"] = Node(
        "HamiltonSim.apply_negative_feedback_connection!",
        "HamiltonSim.apply_negative_feedback_connection!",
        "apply_negative_feedback_connection!(\n    J_global::Matrix{T},\n    node_source::PHSNode{T},\n    node_target::PHSNode{T},\n    edge::ConnectionEdge{T},\n)",
        "Apply negative feedback: u_target = -y_source.",
        "src/Interconnection.jl",
    )

    nodes["HamiltonSim.apply_skew_symmetric_connection!"] = Node(
        "HamiltonSim.apply_skew_symmetric_connection!",
        "HamiltonSim.apply_skew_symmetric_connection!",
        "apply_skew_symmetric_connection!(\n    J_global::Matrix{T},\n    node1::PHSNode{T},\n    node2::PHSNode{T},\n    edge::ConnectionEdge{T},\n)",
        "Apply K-based skew-symmetric power-conserving coupling.",
        "src/Interconnection.jl",
    )

    nodes["HamiltonSim.create_external_input_function"] = Node(
        "HamiltonSim.create_external_input_function",
        "HamiltonSim.create_external_input_function",
        "create_external_input_function(graph::NetworkGraph{T}, B::Matrix{T})",
        "Build global u(t) from YAML external input specs.",
        "src/NetworkSolver.jl",
    )

    nodes["HamiltonSim.create_external_input_function.u_network"] = Node(
        "HamiltonSim.create_external_input_function.u_network",
        "create_external_input_function.u_network",
        "u_network(t::Real)",
        "Global input function u(t) built from external inputs.",
        "src/NetworkSolver.jl",
    )

    nodes["HamiltonSim.parse_input_function"] = Node(
        "HamiltonSim.parse_input_function",
        "HamiltonSim.parse_input_function",
        "parse_input_function(expr::String)",
        "Parse a string expression into an input function u(t).",
        "src/YAMLParser.jl",
    )

    nodes["HamiltonSim.solve_phs"] = Node(
        "HamiltonSim.solve_phs",
        "HamiltonSim.solve_phs",
        "solve_phs(\n    system::PortHamSystem{T},\n    x0::Vector{T},\n    differential_vars::Vector{Bool},\n    u_func::Function;\n    sim_config::SimulationConfigSchema = SimulationConfigDefault,\n)",
        "Set up and solve the DAE using OrdinaryDiffEq/Sundials.",
        "src/NetworkSolver.jl",
    )

    nodes["HamiltonSim.solve_phs.dae_residual!"] = Node(
        "HamiltonSim.solve_phs.dae_residual!",
        "solve_phs.dae_residual!",
        "dae_residual!(out, dx, x, p, t)",
        "DAE residual: Q*dx - (J-R)*x - B*u(t).",
        "src/NetworkSolver.jl",
    )

    nodes["HamiltonSim.get_dae_solver"] = Node(
        "HamiltonSim.get_dae_solver",
        "HamiltonSim.get_dae_solver",
        "get_dae_solver(solver_name::String)",
        "Map solver name to a DAE algorithm instance.",
        "src/NetworkSolver.jl",
    )

    nodes["HamiltonSim.input_dimension"] = Node(
        "HamiltonSim.input_dimension",
        "HamiltonSim.input_dimension",
        "input_dimension(sys::PortHamSystem)",
        "Return input dimension m.",
        "src/PortHamSystem.jl",
    )

    nodes["HamiltonSim.state_dimension"] = Node(
        "HamiltonSim.state_dimension",
        "HamiltonSim.state_dimension",
        "state_dimension(sys::PortHamSystem)",
        "Return number of state variables.",
        "src/PortHamSystem.jl",
    )

    nodes["HamiltonSim.PortHamSystem"] = Node(
        "HamiltonSim.PortHamSystem",
        "HamiltonSim.PortHamSystem",
        "PortHamSystem(\n    interconnection::AbstractMatrix{T},\n    dissipation::AbstractMatrix{T},\n    mass::AbstractMatrix{T},\n    input::AbstractMatrix{T},\n)",
        "Validated constructor for a port-Hamiltonian system.",
        "src/PortHamSystem.jl",
    )

    nodes["HamiltonSim.PHSNode"] = Node(
        "HamiltonSim.PHSNode",
        "HamiltonSim.PHSNode",
        "PHSNode(\n    id::String,\n    system::PortHamSystem{T},\n    initial_state::Vector{T},\n    state_offset::Int = 0,\n)",
        "Network node holding one PHS and its state mapping.",
        "src/Network.jl",
    )

    nodes["HamiltonSim.ConnectionEdge"] = Node(
        "HamiltonSim.ConnectionEdge",
        "HamiltonSim.ConnectionEdge",
        "ConnectionEdge(from_node::String, to_node::String, type::Symbol; from_indices=nothing, to_indices=nothing, coupling_matrix=nothing)",
        "Edge describing how two nodes are interconnected.",
        "src/Network.jl",
    )

    nodes["HamiltonSim.ExternalInput"] = Node(
        "HamiltonSim.ExternalInput",
        "HamiltonSim.ExternalInput",
        "ExternalInput(system::String, indices::Union{Nothing,Vector{Int}}, function_expr::String)",
        "External input specification for a node.",
        "src/Network.jl",
    )

    nodes["HamiltonSim.NetworkGraph"] = Node(
        "HamiltonSim.NetworkGraph",
        "HamiltonSim.NetworkGraph",
        "NetworkGraph(\n    name::String,\n    nodes::Dict{String,PHSNode{T}},\n    edges::Vector{ConnectionEdge{T}},\n    external_inputs::Vector{ExternalInput},\n)",
        "Network metadata used during assembly.",
        "src/Network.jl",
    )

    nodes["HamiltonSim.SimulationResult"] = Node(
        "HamiltonSim.SimulationResult",
        "HamiltonSim.SimulationResult",
        "SimulationResult(system::PortHamSystem{T}, solution::Any, graph::NetworkGraph{T})",
        "Return bundle from simulate_file.",
        "src/NetworkSolver.jl",
    )

    # External / non-builtin libraries (excluding Term; omitted by request)

    nodes["YAML.load_file"] = Node(
        "YAML.load_file",
        "YAML.load_file",
        "load_file(filepath::AbstractString)",
        "Read a YAML file into a Dict-like structure.",
        "external",
    )

    nodes["JSON3.read"] = Node(
        "JSON3.read",
        "JSON3.read",
        "read(input; kwargs...)",
        "Parse JSON into Julia data or typed structs.",
        "external",
    )

    nodes["JSON3.write"] = Node(
        "JSON3.write",
        "JSON3.write",
        "write(x; kwargs...)",
        "Serialize a Julia object to JSON.",
        "external",
    )

    nodes["JSONSchema.Schema"] = Node(
        "JSONSchema.Schema",
        "JSONSchema.Schema",
        "Schema(schema_dict)",
        "Create a JSON schema validator.",
        "external",
    )

    nodes["JSONSchema.validate"] = Node(
        "JSONSchema.validate",
        "JSONSchema.validate",
        "validate(schema, instance)",
        "Validate an instance against a schema.",
        "external",
    )

    nodes["Eq.DAEProblem"] = Node(
        "Eq.DAEProblem",
        "Eq.DAEProblem",
        "DAEProblem(dae_residual!, dx0, x0, tspan; differential_vars=...)",
        "Define a DAE initial value problem.",
        "external",
    )

    nodes["Eq.BrownFullBasicInit"] = Node(
        "Eq.BrownFullBasicInit",
        "Eq.BrownFullBasicInit",
        "BrownFullBasicInit()",
        "Initialization algorithm for DAEs.",
        "external",
    )

    nodes["Eq.solve"] = Node(
        "Eq.solve",
        "Eq.solve",
        "solve(prob, alg; initializealg=..., saveat=...)",
        "Solve the DAE problem.",
        "external",
    )

    nodes["Sundials.IDA"] = Node(
        "Sundials.IDA",
        "Sundials.IDA",
        "IDA()",
        "SUNDIALS IDA DAE solver algorithm.",
        "external",
    )

    nodes["Eq.DFBDF"] = Node(
        "Eq.DFBDF",
        "Eq.DFBDF",
        "DFBDF()",
        "OrdinaryDiffEq DFBDF algorithm.",
        "external",
    )

    nodes["Eq.DABDF2"] = Node(
        "Eq.DABDF2",
        "Eq.DABDF2",
        "DABDF2()",
        "OrdinaryDiffEq DABDF2 algorithm.",
        "external",
    )

    nodes["Eq.DImplicitEuler"] = Node(
        "Eq.DImplicitEuler",
        "Eq.DImplicitEuler",
        "DImplicitEuler()",
        "OrdinaryDiffEq implicit Euler algorithm.",
        "external",
    )

    edges = Edge[]

    # simulate_file workflow
    push!(edges, Edge("HamiltonSim.simulate_file", "HamiltonSim.read_config", "1"))
    push!(edges, Edge("HamiltonSim.simulate_file", "HamiltonSim.load_network_from_yaml", "1"))
    push!(edges, Edge("HamiltonSim.simulate_file", "HamiltonSim.assemble_network", "1"))
    push!(edges, Edge("HamiltonSim.simulate_file", "HamiltonSim.create_external_input_function", "1"))
    push!(edges, Edge("HamiltonSim.simulate_file", "HamiltonSim.solve_phs", "1"))
    push!(edges, Edge("HamiltonSim.simulate_file", "HamiltonSim.SimulationResult", "1"))

    # read_config
    push!(edges, Edge("HamiltonSim.read_config", "YAML.load_file", "1"))
    push!(edges, Edge("HamiltonSim.read_config", "HamiltonSim.validate_config", "1"))
    push!(edges, Edge("HamiltonSim.read_config", "JSON3.write", "1"))
    push!(edges, Edge("HamiltonSim.read_config", "JSON3.read", "1"))

    # validate_config
    push!(edges, Edge("HamiltonSim.validate_config", "JSON3.read", "1"))
    push!(edges, Edge("HamiltonSim.validate_config", "JSONSchema.Schema", "1"))
    push!(edges, Edge("HamiltonSim.validate_config", "JSONSchema.validate", "1"))

    # load_network_from_yaml
    push!(edges, Edge("HamiltonSim.load_network_from_yaml", "HamiltonSim.create_network_nodes_from_schema", "1"))
    push!(edges, Edge("HamiltonSim.load_network_from_yaml", "HamiltonSim.ConnectionEdge", "n"))
    push!(edges, Edge("HamiltonSim.load_network_from_yaml", "HamiltonSim.ExternalInput", "n"))
    push!(edges, Edge("HamiltonSim.load_network_from_yaml", "HamiltonSim.NetworkGraph", "1"))

    # create_network_nodes_from_schema
    push!(edges, Edge("HamiltonSim.create_network_nodes_from_schema", "HamiltonSim.PortHamSystem", "n"))
    push!(edges, Edge("HamiltonSim.create_network_nodes_from_schema", "HamiltonSim.state_dimension", "n"))
    push!(edges, Edge("HamiltonSim.create_network_nodes_from_schema", "HamiltonSim.PHSNode", "n"))

    # assemble_network
    push!(edges, Edge("HamiltonSim.assemble_network", "HamiltonSim.assemble_block_diagonal_matrix", "n"))
    push!(edges, Edge("HamiltonSim.assemble_network", "HamiltonSim.apply_connection!", "n"))
    push!(edges, Edge("HamiltonSim.assemble_network", "HamiltonSim.assemble_initial_state", "1"))
    push!(edges, Edge("HamiltonSim.assemble_network", "HamiltonSim.PortHamSystem", "1"))

    # assemble_block_diagonal_matrix
    push!(edges, Edge("HamiltonSim.assemble_block_diagonal_matrix", "HamiltonSim.create_block_diagonal", "1"))

    # apply_connection! dispatch
    push!(edges, Edge("HamiltonSim.apply_connection!", "HamiltonSim.apply_direct_connection!", "1"))
    push!(edges, Edge("HamiltonSim.apply_connection!", "HamiltonSim.apply_negative_feedback_connection!", "1"))
    push!(edges, Edge("HamiltonSim.apply_connection!", "HamiltonSim.apply_skew_symmetric_connection!", "1"))

    # create_external_input_function
    push!(edges, Edge("HamiltonSim.create_external_input_function", "HamiltonSim.parse_input_function", "n"))
    push!(edges, Edge("HamiltonSim.create_external_input_function", "HamiltonSim.input_dimension", "n"))

    # solve_phs
    push!(edges, Edge("HamiltonSim.solve_phs", "HamiltonSim.solve_phs.dae_residual!", "1"))
    push!(edges, Edge("HamiltonSim.solve_phs", "HamiltonSim.get_dae_solver", "1"))
    push!(edges, Edge("HamiltonSim.solve_phs", "Eq.DAEProblem", "1"))
    push!(edges, Edge("HamiltonSim.solve_phs", "Eq.BrownFullBasicInit", "1"))
    push!(edges, Edge("HamiltonSim.solve_phs", "Eq.solve", "1"))

    # dae_residual!
    push!(edges, Edge("HamiltonSim.solve_phs.dae_residual!", "HamiltonSim.create_external_input_function.u_network", "n"))

    # get_dae_solver
    push!(edges, Edge("HamiltonSim.get_dae_solver", "Sundials.IDA", "1"))
    push!(edges, Edge("HamiltonSim.get_dae_solver", "Eq.DFBDF", "1"))
    push!(edges, Edge("HamiltonSim.get_dae_solver", "Eq.DABDF2", "1"))
    push!(edges, Edge("HamiltonSim.get_dae_solver", "Eq.DImplicitEuler", "1"))

    return (nodes=nodes, edges=edges)
end

# ------------------------------
# DOT output
# ------------------------------

function dot_escape(s::String)
    # DOT labels use backslash-escapes like \n for line breaks.
    # We want to escape literal backslashes, but preserve the DOT escapes.
    s = replace(s, "\\" => "\\\\")
    s = replace(s, "\\\\n" => "\\n")
    s = replace(s, "\\\\l" => "\\l")
    s = replace(s, "\\\\r" => "\\r")
    s = replace(s, "\"" => "\\\"")
    return s
end

function node_label(n::Node)
    desc = n.file == "external" ? "$(n.description) (external)" : n.description
    dot_escape("$(n.title)\\n$(n.signature)\\n$desc")
end

function write_dot(path::String, nodes::Dict{String,Node}, edges::Vector{Edge})
    mkpath(dirname(path))

    referenced = Set{String}()
    for e in edges
        push!(referenced, e.from)
        push!(referenced, e.to)
    end

    open(path, "w") do io
        println(io, "digraph CallTree {")
        println(io, "  rankdir=LR;")
        println(io, "  node [shape=box, fontsize=10];")
        println(io, "  edge [fontsize=9];")

        # Group nodes by source file
        file_groups = Dict{String,Vector{String}}()
        for id in referenced
            haskey(nodes, id) || error("Missing node definition for '$id' (add it in define_graph())")
            file = nodes[id].file
            push!(get!(file_groups, file, String[]), id)
        end

        for file in sort(collect(keys(file_groups)))
            if file == "external"
                for id in sort(file_groups[file])
                    n = nodes[id]
                    lbl = node_label(n)
                    style = startswith(id, "HamiltonSim.") ? "" : ", style=rounded"
                    println(io, "  \"$id\" [label=\"$lbl\"$style];")
                end
                continue
            end

            cluster_id = replace(file, r"[^A-Za-z0-9_]" => "_")
            println(io, "  subgraph cluster_$cluster_id {")
            println(io, "    label=\"$file\";")
            println(io, "    style=rounded;")
            for id in sort(file_groups[file])
                n = nodes[id]
                lbl = node_label(n)
                style = startswith(id, "HamiltonSim.") ? "" : ", style=rounded"
                println(io, "    \"$id\" [label=\"$lbl\"$style];")
            end
            println(io, "  }")
        end

        for e in edges
            println(io, "  \"$(e.from)\" -> \"$(e.to)\" [label=\"$(e.label)\"];")
        end

        println(io, "}")
    end
end

function try_render(dot_path::String, fmt::String)
    dot = Sys.which("dot")
    dot === nothing && error("GraphViz 'dot' not found on PATH; install graphviz or omit --render")

    out_path = replace(dot_path, r"\\.dot$" => ".$fmt")
    out_path == dot_path && (out_path = dot_path * ".$fmt")

    run(`$dot -T$fmt -o $out_path $dot_path`)
    return out_path
end

function main(args::Vector{String})
    opts = parse_args(args)
    out = abspath(String(opts["out"]))
    render = opts["render"] === nothing ? nothing : String(opts["render"])

    g = define_graph()
    write_dot(out, g.nodes, g.edges)
    println("Wrote DOT: $out")

    if render !== nothing
        out_rendered = try_render(out, render)
        println("Rendered: $out_rendered")
    end
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    ManualSimulateFileCallGraph.main(ARGS)
end
