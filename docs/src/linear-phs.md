# Port-Hamiltonian Systems

## General port-Hamiltonian systems

The Hamiltonian (or total energy of the system) of a general port-Hamiltonian
system is a continuously differentiable function $H: \mathcal{X} \to \mathbb{R}$, for
some domain $\mathcal{X}\subseteq \mathbb{R}^n$. The Hamiltonian flow of energy
is described by the gradient of the Hamiltonian $H$, i.e.

```math
\frac{\partial H}{\partial x}(x) = \nabla H(x) = \left[\begin{matrix}
\frac{\partial H}{\partial x_1}\\
\vdots\\
\frac{\partial H}{\partial x_n}
\end{matrix}\right].
```

By definition, port-Hamiltonian systems are (cyclo-)passive as a consequence of their system formulation. First, we define an input-state-output port-Hamiltonian system following Definition 6.1.1 in [AvdS2000l2Gain](@cite).

!!! note "Definition: Input-state-output port-Hamiltonian system"
    An input-state-output port-Hamiltonian system (ISOPHS) with $n$-dimensional state space manifold $\mathcal{X}$, input and output spaces $U=Y=\mathbb{R}^m$, and Hamiltonian $H:\mathcal{X}\to\mathbb{R}$, is given by

    ```math
    \begin{aligned}
    \dot{x} &= [J(x) - R(x)]\nabla H(x) + g(x)u\\
    y &= g^T(x) \nabla H(x)
    \end{aligned}
    ```

    where the $n\times n$-matrices $J(x), R(x)$ satisfy $J(x) = -J^T(x)$ and $R(x) = R^T(x)\geq 0$.

By the properties of $J(x)$ and $R(x)$, it immediately follows that

```math
\frac{d H}{dt}(x(t)) = \frac{\partial^T H}{\partial x}(x(t))\dot{x}(t) = -\frac{\partial^T H}{\partial x}(x(t))R(x(t))\frac{\partial H}{\partial x}(x(t)) + y^T(t)u(t) \leq u^T(t)y(t),
```

implying cyclo-passivity and passivity if $H\geq 0$. An input-state-output pHS with non-linear resistive structure is given as

```math
\begin{aligned}
\dot{x} &= J(x)z - R(x, z) + g(x)u,\quad z = \nabla H(x),\\
y &= g^T(x) z
\end{aligned}
```

where $J(x) = -J^T(x)$, and the resistive mapping $R(x,\cdot):\mathbb{R}^n\to\mathbb{R}^n$ satisfies

```math
z^TR(x,z)\geq 0,\quad\text{for all}\; z\in\mathbb{R}^n,\;x\in\mathcal{X}.
```

### Definition: pHS with feedthrough

!!! note "Definition: pHS with feedthrough"
    An input-state-output port-Hamiltonian system with feedthrough terms is specified by an $n$-dimensional state space manifold $\mathcal{X}$, input and output spaces $U=Y=\mathbb{R}^m$, Hamiltonian $H:\mathcal{X}\to\mathbb{R}$, and dynamics

    ```math
    \begin{aligned}
    \dot{x} &= [J(x) - R(x)]\nabla H(x) + [G(x) - P(x)]u,\\
    y &= [G(x) - P(x)]^T\nabla H(x) + [M(x) + S(x)]u,
    \end{aligned}
    ```

    where the matrices $J(x), M(x), R(x), P(x), S(x)$ satisfy the skew-symmetry conditions $J(x) = -J^T(x)$, $M(x) = -M^T(x)$, and the nonnegativity condition

    ```math
    \left[\begin{matrix}
    R(x) & P(x) \\
    P^T(x) & S(x)
    \end{matrix}\right]\geq 0,\quad x\in\mathcal{X}.
    ```

## Properties of port-Hamiltonian systems

!!! note "Definition: Casimir functions"
    A Casimir function for an input-state-output port-Hamiltonian system is any function $C:\mathcal{X}\to\mathbb{R}$ satisfying

    ```math
    \frac{\partial^TC}{\partial x}(x)[J(x) - R(x)] = 0,\quad x\in\mathcal{X}.
    ```

A Casimir is a conserved quantity of the system for $u=0$, independently of the Hamiltonian $H$.
In many cases of interest, the desired setpoint of a pHS is not equal to the
minimum of the Hamiltonian function $H$, but instead is a steady-state value
corresponding to a nonzero constant input. This motivates the following proposition by [AvdS2000l2Gain](@cite) and terminology of **shifted passivity**.

!!! note "Shifted passivity"
    Consider an input-state-output pHS with feedthrough terms, together with a constant input $\bar{u}$ with corresponding steady-state $\bar{x}$ determined by

    ```math
    0 = [J(\bar{x}) - R(\bar{x})]\nabla H(\bar{x}) + [G(\bar{x}) - P(\bar{x})]\bar{u}.
    ```

    Denote

    ```math
    \bar{y} = [G(\bar{x})+P(\bar{x})]^T\nabla H(\bar{x}) + [M(\bar{x}) + S(\bar{x})]\bar{u}.
    ```

    Suppose we can find coordinates $x$ in which the system matrices $J(x), M(x), R(x), P(x), S(x), G(x)$ are all constant. Then the system can be rewritten as

    ```math
    \begin{aligned}
    \dot{x} &= [J-R]\nabla \hat{H}_{\bar{x}}(x) + [G - P](u-\bar{u})\\
    y - \bar{y} &= [G + P]^T\nabla\hat{H}_{\bar{x}}(x) + [M+S](u-\bar{u})
    \end{aligned}
    ```

    with respect to the shifted Hamiltonian defined as

    ```math
    \hat{H}_{\bar{x}}(x) := H(x) - \nabla^T H(\bar{x})(x-\bar{x}) - H(\bar{x}).
    ```

    If $H$ is convex in the coordinates $x$, then $\hat{H}_{\bar{x}}$ has a minimum at $x=\bar{x}$ (with value $0$), and the pHS is passive with respect to the shifted supply rate $s(u,y) = (u- \bar{u})^T(y - \bar{y})$, with storage function $\hat{H}_{\bar{x}}$.

## Linear port-Hamiltonian systems

Linear port-Hamiltonian systems arise when the underlying Hamiltonian (or total energy of the system) is a quadratic function in the state, i.e.

```math
H(x) = \frac{1}{2}x^TQx.
```

for some state $x\in\mathbb{R}^n$ with entries $x_i$, $i=1,\ldots, n$ and square matrix $Q\in\mathbb{R}^{n\times n}$.

!!! note "Definition: port-Hamiltonian system"

    Consider a time interval $\mathbb{T}:=[0,T]\subset\mathbb{R}$, $T>0$, a state space $\mathcal{X}\subseteq\mathbb{R}^n$ and extended state space $\mathcal{S}:=\mathbb{T}\times\mathcal{X}$. A port-Hamiltonian system (or pHS) is a system of ordinary differential equations of the form

    ```math
    \begin{aligned}
    \dot{x} &= (J-R)\nabla H(x) + Gu + Kd,\\
    y &= G^T\nabla H(x),\\
    z &= K^T\nabla H(x),
    \end{aligned}
    ```

    with a Hamiltonian function $\mathcal{H}(x):\mathcal{X}\to\mathbb{R}$, where $x(t)\in\mathcal{X}$ is the state, $u(t)\in\mathbb{R}^{m_1}, y(t)\in\mathbb{R}^{m_1}$, are the controllable input and output, $d(t)\in\mathbb{R}^{m_2}, z(t)\in\mathbb{R}^{m_2}$ are the uncontrollable interaction ports. Furthermore, $E\in\mathbb{R}^{\ell\times n}$ TODO
