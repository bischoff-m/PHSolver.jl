using Test
import PHSolver

@testset "Definition parsing and graph construction" begin
    defs = PHSolver.parse_defs([
        "a = 3.0",
        "expr(t) = g(2.0 * t) + sin(a * t) - b^2",
        # = 32t + sin(3t) - 2.5
        "g(x) = x * f + a / 2.0",
        # = 16x + 1.5
        "f = 2.0 * a + 5.0 * b",
        # = 16
        "b = 2.0",
        "l = sqrt(a)",
        "h(x, a) = expr(x) + x * f / a + a * expr(l)",
        "i(j, k) = h(j, k) + l + h(j, l)",
        "j(x) = expr(2.0 * expr(x / 2.0))"
    ])

    graph = PHSolver.DefinitionGraph()
    PHSolver.add_defs!(graph, defs)
    PHSolver.resolve_parameters!(graph; keep=Set([:t]), verbose=false)
end

@testset "Definition parsing" begin
    defs = PHSolver.parse_defs([
        "a = 3",
        "l = sqrt(a)",
        "h(x, y) = x + y",
        "i(j, k) = h(j, k) + l + h(j, l)",
        # = k + 2j + 2sqrt(3)
        "f(x) = (2 * x^2 + 5 * a) / pi + x"
    ])

    graph = PHSolver.DefinitionGraph()
    PHSolver.add_defs!(graph, defs)
    @show graph

    PHSolver.resolve_parameters!(graph; keep=Set([:t]), verbose=false)
    println()
    @show graph
end