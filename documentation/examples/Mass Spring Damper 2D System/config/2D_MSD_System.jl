"""
Config file for 2-dimensional Mass-Spring-Damper system
"""

using LinearAlgebra

# params
m = 1.0
k = 2.0
d = 0.5

# Matrices
J = [0.0 1.0; -1.0 0.0]
R = [0.0 0.0; 0.0 d]
Qe = Diagonal([k, 1/m])     # k=2, m=1
G = [0.0; 1.0]

# For the simulator
u(t) = sin(t)
x0 = [1.0; -4.0]
dt = 0.002
tspan = 0.0:dt:20.0
descriptor = false 
method = :Euler

return (; J, R, Qe, G, u, x0, dt, tspan, descriptor, method, project_ic=true, eps_reg=1e-8)