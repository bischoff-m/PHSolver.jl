using Test

using HamiltonSim

@testset "PortHamSystem construction" begin
    # small valid PH system (n=2, m=1)
    interconnection = [0.0 -1.0; 1.0 0.0]
    dissipation = [0.1 0.0; 0.0 0.1]
    energy = [1.0 0.0; 0.0 1.0]
    input = reshape([1.0, 0.0], 2, 1)

    sys = PortHamSystem(interconnection, dissipation, energy, input)

    @test sys isa PortHamSystem
    @test sys.interconnection == interconnection
    @test sys.dissipation == dissipation
    @test sys.mass == energy
    @test sys.input == input
end
