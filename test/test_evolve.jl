# This test can be run as part of the package test suite or executed directly.
# To run directly: `julia test/test_evolve.jl` (the script will activate the project)

if abspath(PROGRAM_FILE) == @__FILE__
    import Pkg
    Pkg.activate(joinpath(@__DIR__, ".."))
end

using Test
using PHSolver: PortHamSystem, HamiltonState, evolve_step

@testset "evolve single step" begin
    # small valid PH system (n=2, m=1)
    J = [0.0 -1.0; 1.0 0.0]
    R = [0.1 0.0; 0.0 0.1]
    Q = [1.0 0.0; 0.0 1.0]
    B = reshape([1.0, 0.0], 2, 1)

    sys = PortHamSystem(J, R, Q, B)

    # initial evolvable
    x0 = [1.0, 0.0]
    xdot0 = zeros(2)
    y0 = zeros(1)
    ev = HamiltonState(x0, xdot0, y0)

    # step parameters
    dt = 0.1
    u = [0.0]

    # expected calculations (use initial state before evolve mutates it)
    dH_dx = Q * x0
    expected_xdot = (J - R) * dH_dx + B * u
    expected_x = x0 .+ expected_xdot * dt
    expected_y = transpose(B) * dH_dx

    # call evolve (signature: system first, evolvable second)
    evolve_step(sys, ev, dt, u)
    evolve_step(sys, ev, dt, u)
    evolve_step(sys, ev, dt, u)

    println("State: ", ev.state)
    println("Derivative: ", ev.state_derivative)
    println("Output: ", ev.output)

    # @test isapprox(ev.state_derivative, expected_xdot; atol=1e-12)
    # @test isapprox(ev.state, expected_x; atol=1e-12)
    # @test isapprox(ev.output, expected_y; atol=1e-12)
end
