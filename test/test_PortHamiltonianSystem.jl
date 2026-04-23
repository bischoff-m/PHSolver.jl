using Test

using PHSolver

@testset "PortHamSystem construction" begin
    # small valid PH system (n=2, m=1)
    J = [0.0 -1.0; 1.0 0.0]
    R = [0.1 0.0; 0.0 0.1]
    E = [1.0 0.0; 0.0 1.0]
    B = reshape([1.0, 0.0], 2, 1)

    sys = PortHamSystem(J, R, E, B)

    @test sys isa PortHamSystem
    @test sys.connections == J
    @test sys.dissipation == R
    @test sys.mass == E
    @test sys.input == B
end
