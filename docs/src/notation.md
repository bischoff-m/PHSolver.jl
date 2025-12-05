# Definitions & Notations

For the notations and definitions used in the main chapters of this documentation, we consider **state-space systems** $\Sigma$ with inputs and outputs of the general form

```math
\begin{aligned}
\dot{x} &= f(x,u),\quad u\in U\\
y &= h(x, u),\quad y\in Y
\end{aligned}
```

where $x=(x_1,\ldots,x_n)$ are local coordinates for an $n$-dimensional state space manifold $\mathcal{X}\subseteq\mathbb{R}^n$, and $U$ and $Y$ are linear spaces, of dimension $m$, respectively $p$. We assume that there exists a unique solution trajectory $x(\cdot)$ on $[0,\infty)$ of the differential equation for all initial conditions $x(0)$. On the combined space $U\times Y$ of inputs and outputs consider a function

```math
s:U\times Y\to\mathbb{R},
```

called **supply rate**.

!!! note "(Cyclo-)Dissipativity, conservative"
    A state-space system $\Sigma$ is said to be **dissipative** with respect to the supply rate $s$ if there exists a function $S:\mathcal{X}\to [0,\infty)$, called **storage function**, such that for all initial conditions $x(t_0) = x_0\in\mathcal{X}$ at any time $t_0$, and for all allowed input functions $u(\cdot)$ and all $t_1\geq t_0$ the following inequality holds

    ```math
    S(x(t_1))\leq S(x(t_0)) + \int_{t_0}^{t_1}s(u(t), y(t))dt
    ```

    If this inequality holds with equality for all $x_0$, $t_1\geq t_0$, and all $u(\cdot)$, then $\Sigma$ is **conservative** with respect to $s$. Finally, $\Sigma$ is called **cyclo-dissipative** with respect to $s$ if there exists a function $S:\mathcal{X}\to\mathbb{R}$ (not necessarily nonnegative) such that the inequality above holds.

The inequality above is called the **dissipation inequality**. It expresses the fact that the stored energy $S(x(t_1))$ of $\Sigma$ at any future time $t_1$ is at most equal to the stored energy $S(x(t_0))$ at present time $t_0$, plus the total externally supplied energy

```math
\int_{t_0}^{t_1}s(u(t), y(t))dt
```

during the time interval $[t_0,t_1]$.

!!! note "Passivity"
    A state space system $\Sigma$ with $U=Y=\mathbb{R}^m$ is **passive** if it is dissipative with respect to the supply rate $s(u,y) = u^Ty$. $\Sigma$ is **input strictly passive** if there exists $\delta>0$ such that $\Sigma$ is dissipative with respect to $s(u,y) = u^Ty - \delta\|u\|^2$. $\Sigma$ is **ouput strictly passive** if there exists $\varepsilon>0$ such that $\Sigma$ is dissipative with respect to $s(u,y) = u^Ty - \varepsilon\|y\|^2$. Finally, $\Sigma$ is **lossless** if it is conservative with respect to $s(u,y) = u^Ty$.

!!! note "$L_2$-Gain"
    A state space system $\Sigma$ with $U=\mathbb{R}^m$, $Y=\mathbb{R}^p$ has **$L_2$-gain $\leq\gamma$** if it is dissipative with respect to the supply rate $s(u,y) = \frac{\gamma^2}{2}\|u\|^2 - \frac{1}{2}\|y\|^2$. The $L_2$-gain of $\Sigma$ is defined as

    ```math
    \gamma(\Sigma) := \inf\{\gamma\;|\; \Sigma\;\text{has}\;L_2\text{-gain}\;\leq \gamma\}
    ```

    $\Sigma$ is said to have $L_2$-gain $<\gamma$ if there exists $\tilde{\gamma}<\gamma$ such that $\Sigma$ has $L_2$-gain $\leq\tilde{\gamma}$. Finally $\Sigma$ is called **inner** if it is conservative with respect to $s(u,y)= \frac{1}{2}\|u\|^2 - \frac{1}{2}\|y\|^2$.
