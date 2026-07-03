# Smore.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://drbergman-lab.github.io/Smore.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://drbergman-lab.github.io/Smore.jl/dev/)
[![Build Status](https://github.com/drbergman-lab/Smore.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/drbergman-lab/Smore.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/drbergman-lab/Smore.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/drbergman-lab/Smore.jl)

Surrogate modeling tools for reconstructing parameter surfaces of complex computational models.

Smore is a Julia port and generalization of [SMoReParS](https://github.com/drbergman/SMoReParS) (MATLAB). The surrogate model (SM) sits between a slow, expensive complex model (CM) — such as an agent-based model — and real-world data: the SM is trained on CM output, then used as a fast proxy to calibrate CM parameters against real-world observations and to analyze CM behavior through sensitivity analysis.

`using Smore` loads all three sub-packages together. Each sub-package is also available as a standalone registered package:

| Sub-package | Description |
|-------------|-------------|
| `SmoreBase` | Fit a surrogate model to data; quantify uncertainty of SM parameters |
| `SmoreFit` | Build posterior distributions on CM parameter space given data + SM UQ |
| `SmoreGSA` | Sensitivity analysis of SM outputs; lift sensitivity to CM parameter space |

## Quick Start

```julia
using Smore
using OrdinaryDiffEq   # activates ODE-solving extension

# Define a surrogate model (ODE-based example: logistic growth)
sm = ODESurrogateModel(
    ode_fn = (du, u, p, t) -> (du[1] = p[1] * u[1] * (1 - u[1] / p[2])),
    y0 = [0.01],
    solver = Tsit5(),
)

# Supply summary statistics from your complex model runs
data = CMData(
    mean  = ...,   # [n_cm_param_sets × n_conditions × n_times × n_outputs]
    sd    = ...,   # same shape
    times = t,
)

# Bundle model, data, prior, and loss into a single problem object
prior   = ParameterPrior(lower=[0.0, 0.0], upper=[2.0, 10.0], names=["r", "K"])
problem = SMFitProblem(sm, data, prior)   # loss defaults to GaussianNLL()

# Fit SM parameters (one fit per cm_param_set)
P0  = [0.5 5.0]   # initial guess [n_cm_param_sets × n_sm_params]
fit = fitSurrogate(problem, P0)

# Quantify uncertainty via profile likelihood
uq = quantifyUncertainty(ProfileLikelihood(), problem, fit, 1)
```

See each sub-package's own README for its full Quick Start (`SmoreFit` for posterior inference
against real-world data, `SmoreGSA` for sensitivity analysis).

---

## Implementation Status

Each sub-package tracks its own implementation status — see their READMEs, linked below. This
repo has no pipeline features of its own beyond the meta-package re-export (see PRD.md); keeping
a duplicated checklist here went stale twice already (an already-shipped `SmoreFit` feature
listed as not-yet-built, and a `SmoreGSA` item filed under the wrong heading), so it isn't
maintained here anymore.

| Sub-package | Implementation Status |
|---|---|
| `SmoreBase` | [SmoreBase.jl README](https://github.com/drbergman-lab/SmoreBase.jl/blob/main/README.md#implementation-status) |
| `SmoreFit`  | [SmoreFit.jl README](https://github.com/drbergman-lab/SmoreFit.jl/blob/main/README.md#implementation-status) |
| `SmoreGSA`  | [SmoreGSA.jl README](https://github.com/drbergman-lab/SmoreGSA.jl/blob/main/README.md#implementation-status) |
