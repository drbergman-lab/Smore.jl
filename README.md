# SMoReVerse.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://drbergman-lab.github.io/SMoReVerse.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://drbergman-lab.github.io/SMoReVerse.jl/dev/)
[![Build Status](https://github.com/drbergman-lab/SMoReVerse.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/drbergman-lab/SMoReVerse.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/drbergman-lab/SMoReVerse.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/drbergman-lab/SMoReVerse.jl)

Surrogate modeling tools for reconstructing parameter surfaces of complex computational models.

SMoReVerse is a Julia port and generalization of [SMoReParS](https://github.com/drbergman/SMoReParS) (MATLAB). The surrogate model (SM) sits between a slow, expensive complex model (CM) — such as an agent-based model — and real-world data: the SM is trained on CM output, then used as a fast proxy to calibrate CM parameters against real-world observations and to analyze CM behavior through sensitivity analysis.

The package is organized as a monorepo with three sub-packages:

| Sub-package | Description |
|-------------|-------------|
| `SMoReBase` | Fit a surrogate model to data; quantify uncertainty of SM parameters |
| `SMoReParS` | Build posterior distributions on CM parameter space given data + SM UQ |
| `SMoReGloS` | Sensitivity analysis of SM outputs; lift sensitivity to CM parameter space |

## Quick Start

```julia
using SMoReVerse
using SMoReVerse.SMoReBase
using OrdinaryDiffEq   # activates ODE-solving extension

# Define your surrogate model (ODE-based example)
sm = ODESurrogateModel(
    ode_fn = (du, u, p, t) -> (du[1] = p[1] * u[1] * (1 - u[1] / p[2])),
    y0 = [0.01],
    solver = Tsit5(),
)

# Supply summary statistics from your complex model
# Unicode (μ, σ, Σ) and ASCII (mean, sd, cov) keyword forms are both accepted
data = CMData(
    mean = ...,   # mean observations [n_times × n_outputs] per cohort/condition
    sd   = ...,   # standard deviations
    times = t,
)

# Fit SM parameters
bounds = ParameterBounds(lower=[0.0, 0.0], upper=[2.0, 10.0], names=["r", "K"])
P0 = [0.5 5.0]   # initial guess [n_cohorts × n_params]
fit = fitSurrogate(sm, data, P0, bounds)
```

---

## Implementation Status

> For Claude Code sessions: this section is the authoritative record of what has been built. Update it as features are completed. See [PRD.md](PRD.md) for behavioral specifications and [progress.md](progress.md) for decision rationale.

### Completed

_(none yet — implementation begins in subsequent sessions)_

### Remaining

**SMoReBase**
- [ ] `CMData` / `AbstractCMData` — summary statistics type for CM observations
- [ ] `ConditionSpec`, `ParameterBounds` — supporting types
- [ ] `ODESurrogateModel`, `AnalyticalSurrogateModel` — surrogate model types with `_evaluate` dispatch
- [ ] ODE extension (`SMoReBaseOrdinaryDiffEqExt`) — ODE solving via `OrdinaryDiffEq.jl`
- [ ] `AbstractLoss`, `GaussianNLL`, `CustomLoss` — loss function types
- [ ] `fitSurrogate` — fit SM to CM output data via bounded optimization (parallel over cohorts)
- [ ] `SMFitResult` — result type for SM fitting
- [ ] UQ of SM parameters — `ProfileLikelihood` method; `_uq` internal dispatch
- [ ] `ProfileLikelihoodResult`, `ProfileCurve` — result types for UQ
- [ ] `sampleSMPredictions` — LHS-based MC sampling within UQ-defined parameter region

**SMoReParS**
- [ ] `buildPosterior` — posterior on CM parameter space given data + SM UQ

**SMoReGloS**
- [ ] `runSensitivity` — EFAST and Morris sensitivity of SM outputs to CM parameters (via `GlobalSensitivity.jl`)
- [ ] Lift SM sensitivity to CM parameter space
