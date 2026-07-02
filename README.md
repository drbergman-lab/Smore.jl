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
using Smore.SmoreBase
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
    mean = ...,   # mean observations [n_times × n_outputs] per CM param_set/condition
    sd   = ...,   # standard deviations
    times = t,
)

# Fit SM parameters
bounds = ParameterBounds(lower=[0.0, 0.0], upper=[2.0, 10.0], names=["r", "K"])
P0 = [0.5 5.0]   # initial guess [n_cm_param_sets × n_params]
fit = fitSurrogate(sm, data, P0, bounds)
```

---

## Implementation Status

> For Claude Code sessions: this section tracks what has been built across the sub-packages. Feature work lives in the sub-package repos; this file reflects overall pipeline status. See [PRD.md](PRD.md) for behavioral specifications and [progress.md](progress.md) for decision rationale.

### Completed

**SmoreBase**
- [x] `CMData` / `AbstractCMData` — summary statistics type for CM observations (4-D layout: `[n_cm_param_sets, n_conditions, n_times, n_outputs]`)
- [x] `ConditionSpec`, `ParameterPrior` — supporting types (`ParameterPrior` holds `Distributions.jl` priors; box bounds via `Uniform`)
- [x] `ODESurrogateModel`, `AnalyticalSurrogateModel` — surrogate model types with `_evaluate` dispatch
- [x] ODE extension (`SmoreBaseOrdinaryDiffEqExt`) — ODE solving via `OrdinaryDiffEq.jl`
- [x] `AbstractLoss`, `GaussianNLL`, `CustomLoss` — loss function types
- [x] `fitSurrogate` — fit SM to CM output data via bounded LBFGS optimization (parallel over cm_param_sets)
- [x] `SMFitResult` — result type for SM fitting
- [x] UQ of SM parameters — `ProfileLikelihood` method; `quantifyUncertainty` dispatch; MLE-anchored grid with proportional split and outward warm-start
- [x] `ProfileLikelihoodResult`, `ProfileCurve` — result types for UQ
- [x] `sampleSMPredictions` — LHS-based MC sampling within UQ-defined parameter region
- [x] `SampledPredictions` — result type for prediction sampling (stores `times` for standalone plotting)
- [x] Plotting recipes (`RecipesBase.jl`) — `plot(SMFitPlot(sm, data, fit))`, `plot(fit_result)`, `plot(uq_result)`, `plot(sampled_preds)`

### Remaining

**SmoreBase**
- [ ] `ODESurrogateModel.y0` — extend to `Dict{String,Vector{Float64}}` for condition-specific initial conditions

**SmoreFit**
- [ ] `buildPosterior` — posterior on CM parameter space given data + SM UQ

**SmoreGSA**
- [x] `runSensitivity` — EFAST and Morris sensitivity of CM outputs to CM parameters, using SM as fast CM proxy (via `GlobalSensitivity.jl`)
- [x] Plotting recipes (`RecipesBase.jl`) — `plot(sens_result)` grouped bar chart of S1/ST indices
