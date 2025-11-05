"""
File for interconnection of port Hamiltonian systems.
"""

module interconnectionModule

export PortPair, build_K, connect, connect_resistor

using ..pHModule
using ..utilsModule: blockdiag


struct PortPair

    """
    Pair portA to portB
    """
    portA::Int
    portB::Int
end

function build_K(m1::Int, m2::Int, pairs::Vector{PortPair})
    K = zeros(AbstractFloat, m1+m2, m1+m2)
    for pp in pairs
        i = pp.portA
        j = pp.portB
        @assert 1 <= i <= m1 "A: port index out of range [1, m1]"
        @assert 1 <= j <= m2 "B: port index out of range [1, m2]"
        K[i, m1+j] = 1.0
        K[m1+j, i] = -1.0
    end
    return K
end

# pHODE + pHODE
function connect(PHS1::pHSystem, PHS2::pHSystem; pairs::Vector{PortPair} = PortPair[])
    # sizes
    m1 = size(PHS1.G, 2)
    m2 = size(PHS2.G, 2)

    # Stack
    Jb = blockdiag(PHS1.J, PHS2.J)
    Rb = blockdiag(PHS1.R, PHS2.R)
    Qeb = blockdiag(PHS1.Qe, PHS2.Qe)
    Gb = blockdiag(PHS1.G, PHS2.G)

    # Feedback K from pairs
    K = build_K(m1, m2, pairs)

    # Closed loop skew-symmetric interconnection
    Jcl = Jb + Gb * K * Gb'

    return pHSystem(Jcl, Rb, Qeb, Gb)
end

# pHDAE + pHDAE
function connect(
    PHS1::pHDescriptorSystem,
    PHS2::pHDescriptorSystem;
    pairs::Vector{PortPair} = PortPair[],
)
    @assert PHS1.rep == PHS2.rep "pH systems need to be in the same representation."

    m1 = size(PHS1.G, 2)
    m2 = size(PHS2.G, 2)

    Eb = blockdiag(PHS1.E, PHS2.E)
    Jb = blockdiag(PHS1.J, PHS2.J)
    Rb = blockdiag(PHS1.R, PHS2.R)
    Qeb = blockdiag(PHS1.Qe, PHS2.Qe)
    Gb = blockdiag(PHS1.G, PHS2.G)
    QHb = blockdiag(PHS1.QH, PHS2.QH)

    K = build_K(m1, m2, pairs)
    Jcl = Jb + Gb * K * Gb'

    return pHDescriptorSystem(Eb, Jcl, Rb, Qeb, Gb; QH = QHb, rep = PHS1.rep)
end

# Mixed overloads (promote to descriptor form by using identity E)
function connect(A::pHSystem, B::pHDescriptorSystem; pairs::Vector{PortPair} = PortPair[])
    A_d = pHDescriptorSystem(I(size(A.J, 1)), A.J, A.R, A.Q, A.G)
    connect(A_d, B; pairs = pairs)
end

function connect(A::pHDescriptorSystem, B::pHSystem; pairs::Vector{PortPair} = PortPair[])
    B_d = pHDescriptorSystem(I(size(B.J, 1)), B.J, B.R, B.Q, B.G)
    connect(A, B_d; pairs = pairs)
end

function connect_resistor(sys::pHDescriptorSystem, k::Int, R::AbstractFloat)
    @assert R > 0 "Resistance needs to be positive."
    n = size(sys.G, 2)   # number of ports
    @assert k <= n "Port k to put resistance not existing."
    delta_R = 1/R * (sys.G[:, k] * sys.G[:, k]')
    Rnew = sys.R + delta_R
    #Gnew = sys.G[:, setdiff(1:size(sys.G, 2), [k])]
    return pHDescriptorSystem(sys.E, sys.J, Rnew, sys.Qe, sys.G; QH = sys.QH)
end

end
