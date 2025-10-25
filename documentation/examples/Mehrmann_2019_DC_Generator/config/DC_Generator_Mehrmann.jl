"""
Config file for DC generator from Mehrmann [1]

[1] Mehrmann, Volker, and Riccardo Morandin. "Structure-preserving discretization for port-Hamiltonian descriptor systems." 
    2019 IEEE 58th Conference on Decision and Control (CDC). IEEE, 2019.

"""

using LinearAlgebra

# --- parameters from the paper (Sec. 4.3) ---
L   = 2.0
C1  = 0.01
C2  = 0.02
R_L = 0.1
R_G = 6.0
R_R = 3.0

# --- pHDAE matrices (x = [I, V1, V2, IG, IR]) ---
E = Diagonal([L, C1, C2, 0.0, 0.0])

J = [ 0.0  -1.0   1.0   0.0   0.0;
      1.0   0.0   0.0  -1.0   0.0;
     -1.0   0.0   0.0   0.0  -1.0;
      0.0   1.0   0.0   0.0   0.0;
      0.0   0.0   1.0   0.0   0.0 ]

R = Diagonal([R_L, 0.0, 0.0, R_G, R_R])
Qe = I(5)
QH = Diagonal([L, C1, C2, 0, 0])
G = [0.0, 0.0, 0.0, 1.0, 0.0]

# --- simulation setup ---
# Input options (pick one in your runner):
u_nocontrol(t) = 0.0
# Smooth “ramp-to-ustar” used in Fig. 3 of the paper:
ustar = 9.1*sqrt(10/3)          # ≈ 16.614
u_ramp(t) = ustar * (atan(5*(t - 0.5))/pi + 0.5)

x0_nocontrol = [1.83, −5.66, −5.48, 1.83, −1.83]
x0_ramp = [0.0, 0.0, 0.0, 0.0, 0.0]  # consistent ICs; you can change this
dt = 1e-3
tspan = 0.0:dt:1.0
rep = :z_state

# package everything up
return (; E, J, R, Qe, G, QH, x0_nocontrol, x0_ramp, u_nocontrol, u_ramp, dt, tspan, rep,
         descriptor=true, method=:Gauss2,
         project_ic=true, eps_reg=0.0)