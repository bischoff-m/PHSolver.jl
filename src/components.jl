"""
components.jl includes models of components of A-grids. Every component is modelled as a parametrized port-Hamiltonian system

"""


module componentsModule

export inductor, capacitor

using ..pHModule

# One port inductor with a port orientation s either (receiving: +1, giving: -1)
function inductor(L::AbstractFloat; s::Int = +1)
    @assert s == 1 || s == -1
    @assert L > 0 "Inductance needs to be a positive value."
    E = [1.0;;]
    J = zeros(1, 1)
    R = zeros(1, 1)
    Qe = [1.0/L;;]
    G = [1.0;;]
    G .= s .* G
    return pHDescriptorSystem(E, J, R, Qe, G; QH = Qe, rep = :x_state)
end

# One port Capacitor with a port orientation s either (receiving: +1, giving: -1)
function capacitor(C::AbstractFloat; s::Int = +1)
    @assert s == 1 || s == -1
    @assert C > 0 "Capacitance needs to be a positive value."
    E = [1.0;;]
    J = zeros(1, 1)
    R = zeros(1, 1)
    Qe = [1.0/C;;]
    G = [1.0;;]
    G .= s .* G
    return pHDescriptorSystem(E, J, R, Qe, G; QH = Qe, rep = :x_state)
end

end
