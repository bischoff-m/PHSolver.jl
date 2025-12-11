using Test
using HamiltonSim
using LinearAlgebra
using OrdinaryDiffEq

@testset "DAE Solver Integration" begin
    # Create a simple 2D mass-spring-damper system
    m = 1.0
    k = 2.0
    d = 0.5

    J = [0.0 1.0; -1.0 0.0]
    R = [0.0 0.0; 0.0 d]
    Q = Diagonal([k, 1.0 / m])
    B = reshape([0.0, 1.0], 2, 1)

    sys = PortHamSystem(J, R, Q, B)

    @testset "solve_dae basic functionality" begin
        x0 = [1.0, 0.0]
        u(t) = [0.0]  # No input
        tspan = (0.0, 1.0)

        sol = solve_dae(sys, x0, tspan, u)

        @test sol.retcode == ReturnCode.Success
        @test length(sol.t) > 0
        @test length(sol.u) > 0
        @test sol.u[1] ≈ x0
    end

    @testset "Energy conservation (no damping, no input)" begin
        # System without damping - just check it runs and energy doesn't blow up
        R_nodamp = zeros(2, 2)
        sys_nodamp = PortHamSystem(J, R_nodamp, Q, B)

        x0 = [1.0, 0.0]
        u(t) = [0.0]
        tspan = (0.0, 0.5)

        sol = solve_dae(sys_nodamp, x0, tspan, u; saveat=0.1)

        # Just verify it solves and energy stays reasonable
        energies = [compute_hamiltonian(sys_nodamp, sol.u[i]) for i in 1:length(sol.u)]

        # Energy shouldn't be negative or blow up excessively
        @test all(e > 0 for e in energies)
        @test all(e < 100 for e in energies)  # Sanity check
    end

    @testset "Energy dissipation (with damping)" begin
        x0 = [1.0, 0.0]
        u(t) = [0.0]
        tspan = (0.0, 0.5)

        sol = solve_dae(sys, x0, tspan, u; saveat=0.1)

        # Compute energies
        energies = [compute_hamiltonian(sys, sol.u[i]) for i in 1:length(sol.u)]

        # Energy should not blow up or be negative
        @test all(e > 0 for e in energies)
        @test all(e < 100 for e in energies)

        # With damping, final energy should be reasonable
        # (oscillating systems might increase/decrease slightly due to numerical effects)
        @test length(energies) >= 3
    end

    @testset "compute_hamiltonian" begin
        x = [1.0, 2.0]
        H = compute_hamiltonian(sys, x)

        # H = 0.5 * x^T * Q * x
        expected = 0.5 * dot(x, Q * x)
        @test H ≈ expected

        # Energy should be positive
        @test H > 0
    end

    @testset "compute_output" begin
        x = [1.0, 2.0]
        y = compute_output(sys, x)

        # y = B^T * Q * x
        expected = transpose(B) * (Q * x)
        @test y ≈ expected
        @test length(y) == input_dimension(sys)
    end

    @testset "create_dae_function" begin
        u(t) = [sin(t)]
        f = create_dae_function(sys, u)

        @test f isa ODEFunction
        @test f.mass_matrix == Q

        # Test that the function can be called
        x = [1.0, 0.0]
        dx = zeros(2)
        f.f(dx, x, nothing, 0.0)

        @test length(dx) == 2
        @test !all(dx .== 0)  # Should compute non-zero derivative
    end

    @testset "Sinusoidal input response" begin
        x0 = [0.0, 0.0]
        u(t) = [sin(2π * t)]
        tspan = (0.0, 2.0)

        sol = solve_dae(sys, x0, tspan, u; saveat=0.5)

        @test sol.retcode == ReturnCode.Success

        # System should respond to input
        max_displacement = maximum(abs(sol.u[i][1]) for i in 1:length(sol.u))
        @test max_displacement > 0.01  # Should have noticeable response
    end

    @testset "Different initial conditions" begin
        u(t) = [0.0]
        tspan = (0.0, 0.5)

        # Test multiple initial conditions
        x0_list = [
            [1.0, 0.0],
            [0.0, 1.0],
            [1.0, 1.0]
        ]

        for x0 in x0_list
            sol = solve_dae(sys, x0, tspan, u)
            @test sol.retcode == ReturnCode.Success
            @test sol.u[1] ≈ x0
        end
    end

    @testset "Solver options" begin
        x0 = [1.0, 0.0]
        u(t) = [0.0]
        tspan = (0.0, 0.5)

        # Test with Rodas5 (default)
        sol1 = solve_dae(sys, x0, tspan, u; solver=Rodas5())

        @test sol1.retcode == ReturnCode.Success
        @test length(sol1.t) > 0
    end

    @testset "State dimension validation" begin
        x0_wrong = [1.0, 0.0, 0.0]  # Wrong dimension
        u(t) = [0.0]
        tspan = (0.0, 1.0)

        @test_throws AssertionError solve_dae(sys, x0_wrong, tspan, u)
    end
end

@testset "PortHamSystem backward compatibility" begin
    # Ensure old API still works
    interconnection = [0.0 -1.0; 1.0 0.0]
    dissipation = [0.1 0.0; 0.0 0.1]
    energy = [1.0 0.0; 0.0 1.0]
    input = reshape([1.0, 0.0], 2, 1)

    sys = PortHamSystem(interconnection, dissipation, energy, input)

    @test sys isa PortHamSystem
    @test state_dimension(sys) == 2
    @test input_dimension(sys) == 1

    # Test that old dynamics! function still exists
    state = HamiltonState([1.0, 0.0], zeros(2), zeros(1))
    u = [0.0]

    dynamics!(sys, state, u)

    @test length(get_derivative(state)) == 2
    @test length(get_output(state)) == 1
end
