
import OrdinaryDiffEq as DE
import Plots
import Sundials

function f2(out, du, u, p, t)
    out[1] = -0.04u[1] + 1e4 * u[2] * u[3] - du[1]
    out[2] = +0.04u[1] - 3e7 * u[2]^2 - 1e4 * u[2] * u[3] - du[2]
    out[3] = u[1] + u[2] + u[3] - 1.0
end

u₀ = [1.0, 0, 0]
du₀ = [-0.04, 0.04, 0.0]
tspan = (0.0, 1000.0)

differential_vars = [true, true, false]
prob = DE.DAEProblem(f2, du₀, u₀, tspan, differential_vars=differential_vars)

sol = DE.solve(prob, Sundials.IDA())


Plots.plot(sol.t, sol[1, :], label="Species 1", xlabel="Time", ylabel="Concentration", lw=2)
Plots.plot!(sol.t, sol[2, :], label="Species 2", lw=2)
Plots.plot!(sol.t, sol[3, :], label="Species 3", lw=2, title="Robertson Problem Solution")
