# Product Requirements Document — SMoReVerse.jl

> **Purpose:** This document defines the complete feature set of SMoReVerse in behavioral terms. It is the authoritative answer to "what should this system do?" Read this at the start of any feature session to establish alignment between intent and implementation plan.

---

## Product Overview

**Vision:** SMoReVerse provides a Julia-native pipeline in which a fast surrogate model (SM) is trained on complex-model (CM) outputs and then used as a bridge to real-world data: fitting the SM to CM output, quantifying uncertainty in SM parameters, calibrating CM parameters against real-world observations via the SM, and analyzing CM behavior through the SM lens.

**Target Users:** Computational modelers who have a slow CM (e.g., an ABM) and want to extract a fast, interpretable surrogate that can be compared to real-world data and analyzed statistically to understand the CM's parameter space.

**Relationship to MATLAB SMoReParS:** SMoReVerse is a port and generalization. The "complex model" is not limited to agent-based models — it is any slow simulator.

**Sub-packages:**
- `SMoReBase` — SM fitting + UQ of SM parameters *(this PRD section)*
- `SMoReParS` — posterior on CM parameter space *(future)*
- `SMoReGloS` — global sensitivity analysis *(future)*

---

## SMoReBase Features

---

### Feature: CMData

**One-line description:** Structured container for CM simulation summary statistics used to train a surrogate model.

**Priority:** Must-have

**Behavioral specification:**
- `abstract type AbstractCMData end` — base type for CM observation containers
- `CMData{T<:Real} <: AbstractCMData` — summary statistics (mean + uncertainty) from CM simulation runs:
  - `μ` — mean observations (shape: flexible; initial concrete shape is `[n_times × n_outputs]` per cohort/condition pair, stored as a matrix or array)
  - `σ` — pointwise standard deviations (same shape as `μ`)
  - `Σ` — optional full covariance matrix (`Union{Nothing, ...}`); `nothing` means independent observations
  - `times::Vector{T}` — shared time grid
  - `variable_names::Vector{String}` — names of observable output variables
  - `condition_labels::Vector{String}` — labels for experimental conditions (e.g., drug doses)
  - `cohort_labels::Vector{String}` — labels for CM parameter vectors (each cohort = one SM fit)
- Note: `CMData` holds CM-generated output only. Real-world observational data enters the pipeline in `SMoReParS` (as the target against which the fitted SM is calibrated), not here.
- The keyword constructor accepts both Unicode and ASCII aliases for the data fields:
  - `μ` or `mean` — mean observations
  - `σ` or `sd` — standard deviations
  - `Σ` or `cov` — covariance (optional)
  - If both Unicode and ASCII forms are supplied for the same field, throw an `ArgumentError`.
- Constructor validates that `μ` and `σ` have matching shapes; if `Σ` is supplied, validates it is positive semidefinite per time point.

**Supporting types:**
- `ConditionSpec{T<:Real}` — experimental conditions:
  - `values::Matrix{T}` — `[n_conditions × n_condition_params]`
  - `param_names::Vector{String}`
  - Convenience constructor: `ConditionSpec(v::AbstractVector)` wraps single-param conditions
- `ParameterBounds{T<:Real}` — optimization bounds:
  - `lower::Vector{T}`, `upper::Vector{T}`, `names::Vector{String}`

**Acceptance criteria:**
- `CMData(μ=..., σ=..., times=t)` and `CMData(mean=..., sd=..., times=t)` both construct successfully with scalar condition/cohort defaults.
- Supplying both `μ=` and `mean=` (or both `σ=`/`sd=`, or both `Σ=`/`cov=`) throws a descriptive `ArgumentError`.
- Mismatched `μ` / `σ` shapes throw a descriptive `ArgumentError`.
- `ConditionSpec([1.0, 2.0, 4.0])` produces a 3×1 condition matrix.

**Out of scope (v0):**
- Raw cell-level data (variable-length per time point) — defer to a future `CellTableCMData` subtype.

---

### Feature: SurrogateModel Types

**One-line description:** Abstract type hierarchy for surrogate models with ODE and analytical concrete subtypes.

**Priority:** Must-have

**Behavioral specification:**
- `abstract type AbstractSurrogateModel end`
- `ODESurrogateModel{F,Pre,Post,Solve,Err} <: AbstractSurrogateModel`:
  - `ode_fn::F` — in-place ODE RHS: `f!(du, u, p, t)` (SciML convention)
  - `y0::Union{Vector{Float64}, Base.Callable}` — initial conditions; if callable, called as `y0(condition) -> Vector`
  - `solver::Any` — ODE algorithm (e.g., `Tsit5()`); typed `Any` to avoid hard compile-time dependency on ODE packages
  - `output_variables::Union{Nothing,Vector{Int}}` — indices of state variables that correspond to observables; `nothing` means all state variables are observed
  - `pre_processor::Pre` — `Union{Nothing,Function}` applied to inputs before evaluation
  - `post_processor::Post` — `Union{Nothing,Function}` applied to ODE output before returning predictions
  - `custom_solve_fn::Solve` — `Union{Nothing,Function}` — if supplied, replaces the default ODE solve step entirely
  - `custom_error_fn::Err` — `Union{Nothing,Function}` — if supplied, replaces the default loss computation
  - `abstol::Float64 = 1e-6`, `reltol::Float64 = 1e-3`
- `AnalyticalSurrogateModel{F,Pre,Post,Err} <: AbstractSurrogateModel`:
  - `fn::F` — analytical solution: `(t::Vector, p::Vector, condition) -> Matrix{Float64}` where rows are time points, columns are output variables
  - `pre_processor::Pre`, `post_processor::Post`, `custom_error_fn::Err`
- Internal dispatch: `_evaluate(sm::AbstractSurrogateModel, t, p, condition) -> Matrix{Float64}` — the primary internal evaluation entry point used by fitting and UQ code
- ODE extension: `ODESurrogateModel._evaluate` is implemented in `ext/SMoReBaseOrdinaryDiffEqExt.jl`; loading `using OrdinaryDiffEq` activates the extension. Calling `_evaluate` on an `ODESurrogateModel` without the extension loaded throws a descriptive error.

**Acceptance criteria:**
- `_evaluate(sm::AnalyticalSurrogateModel, t, p, c)` calls `sm.fn(t, p, c)` and returns a matrix.
- `_evaluate(sm::ODESurrogateModel, t, p, c)` solves the ODE and returns predictions at `t`.
- `pre_processor` is applied to `(t, p, c)` before solve; `post_processor` is applied to the prediction matrix after solve.
- If `custom_solve_fn` is supplied, it is called instead of the default ODE solver.

---

### Feature: Loss Functions

**One-line description:** Pluggable loss functions for comparing SM predictions to CM data.

**Priority:** Must-have

**Behavioral specification:**
- `abstract type AbstractLoss end`
- `GaussianNLL <: AbstractLoss` — default; Gaussian negative log-likelihood:
  - If `Σ` is `nothing`: `NLL = 0.5 * sum((A_pred - μ)² / σ²) + 0.5 * sum(log(2π * σ²))`
  - If `Σ` is supplied: uses the full multivariate Gaussian NLL
- `CustomLoss{F} <: AbstractLoss` — user-supplied loss:
  - `fn::F` — called as `fn(A_pred, data::CMData, cohort_idx, condition_idx) -> Float64`
- Internal: `_computeLoss(loss, A_pred, data, cohort_idx, condition_idx) -> Float64`

**Acceptance criteria:**
- `_computeLoss(GaussianNLL(), A_pred, data, 1, 1)` returns a scalar.
- `CustomLoss(fn)` where `fn` returns a scalar integrates transparently with `fitSurrogate`.

**Ruled out:**
- A separate `WeightedSSE` type — `GaussianNLL` (without the log-determinant term, or with constant `σ`) already covers this; adding a separate type creates confusion about when each applies.

---

### Feature: Surrogate Model Fitting

**One-line description:** Fit SM parameters to CM summary statistics for each cohort.

**Priority:** Must-have

**Behavioral specification:**
- `fitSurrogate(sm, data, P0, bounds; conditions, loss, parallel, optimOptions) -> SMFitResult`
  - `sm::AbstractSurrogateModel`
  - `data::AbstractCMData`
  - `P0::AbstractMatrix` — initial parameter guesses `[n_cohorts × n_sm_params]`
  - `bounds::ParameterBounds`
  - `conditions::ConditionSpec = ConditionSpec([1.0])` — experimental conditions
  - `loss::AbstractLoss = GaussianNLL()`
  - `parallel::Bool = false` — if true, fits cohorts in parallel using `Threads.@threads`
  - `optimOptions::NamedTuple = (;)` — forwarded to `Optimization.jl` `solve()`
- Implementation: `Fminbox(LBFGS())` via `OptimizationOptimJL`; one optimizer call per cohort
- `SMFitResult{T<:Real}`:
  - `parameters::Matrix{T}` — `[n_cohorts × n_sm_params]` — fitted parameters
  - `errors::Vector{T}` — objective value per cohort
  - `initial_parameters::Matrix{T}`
  - `lower_bounds::Vector{T}`, `upper_bounds::Vector{T}`
  - `converged::BitVector`
  - `optim_results::Vector{Any}` — raw `Optimization.jl` solution objects
  - `parameter_names::Vector{String}`

**Acceptance criteria:**
- `fitSurrogate` returns an `SMFitResult` with `parameters` in `[lb, ub]` for each cohort.
- With `parallel=true`, results are identical to `parallel=false` (modulo floating point).
- If a cohort fails to converge, `converged[i] = false` and `parameters[i, :]` contains the best point found.

---

### Feature: UQ of SM Parameters

**One-line description:** Quantify uncertainty in fitted SM parameters via pluggable UQ methods.

**Priority:** Must-have

**Behavioral specification:**
- `abstract type AbstractUQMethod end`
- `ProfileLikelihood <: AbstractUQMethod`:
  - `n_points::Int = 50` — number of grid points per parameter profile
  - `confidence_level::Float64 = 0.95`
  - `bounds::Union{Nothing, ParameterBounds} = nothing` — profile range; defaults to `SMFitResult` bounds
- Internal dispatch: `_uq(sm, data, fitResult, method::AbstractUQMethod; conditions, cohort_index) -> SMUQResult`
  - Users do not call `_uq` directly; it is called by higher-level pipeline functions (API TBD)

**Profile likelihood method:**
- For each SM parameter `θ_i`: sweep a grid of `n_points` values over `[lb_i, ub_i]`, fix `θ_i`, re-optimize all other parameters, record the log-likelihood at each grid point
- Confidence interval by Wilks' theorem: `CI = {θ_i : PL(θ_i) ≥ L* − 0.5 × χ²₁,α}`
  - `L*` = log-likelihood at the MLE (from `fitResult`)
  - `χ²₁,α = quantile(Chisq(1), confidence_level)` (from `Distributions.jl`)
  - For 95% CI: threshold = `L* − 1.92`
- `ProfileCurve{T<:Real}`:
  - `parameter_index::Int`, `parameter_name::String`
  - `profile_values::Vector{T}` — the swept parameter values
  - `log_likelihoods::Vector{T}` — profile LL at each value
  - `ci_lower::Union{Nothing,T}`, `ci_upper::Union{Nothing,T}` — CI bounds (`nothing` if profile does not cross threshold)
  - `threshold::T` — `L* − 0.5 × χ²₁,α`
  - `reference_ll::T` — `L*`
- `ProfileLikelihoodResult{T<:Real} <: SMUQResult`:
  - `profiles::Vector{ProfileCurve{T}}`
  - `fit_result::SMFitResult{T}`
  - `cohort_index::Int`
  - `n_profile_points::Int`

**Acceptance criteria:**
- For a well-identified parameter, `ci_lower < fitted_value < ci_upper`.
- For an unidentifiable parameter (flat likelihood), `ci_lower` and/or `ci_upper` is `nothing`.
- Profile values at the MLE grid point match `fit_result.errors[cohort_index]` to numerical tolerance.

**Future (not in v0):**
- Adaptive profile grid that expands toward the CI boundary (port of MATLAB "slowly expanding" algorithm).
- `Bootstrap <: AbstractUQMethod`, `MCMC <: AbstractUQMethod`.

---

### Feature: SM Prediction Sampling

**One-line description:** LHS-based Monte Carlo sampling of SM predictions within the UQ-defined parameter region.

**Priority:** Should-have

**Behavioral specification:**
- `sampleSMPredictions(sm, uqResult; nSamples, conditions, rng) -> SampledPredictions`
  - Samples SM parameters uniformly within the profile-likelihood CI region using LHS (`QuasiMonteCarlo.jl`)
  - Evaluates the SM at each sampled parameter vector
  - Returns a `SampledPredictions` struct with parameter samples and prediction trajectories
- This is Monte Carlo propagation of SM parameter uncertainty to output uncertainty — **not** a sensitivity analysis method.

**Acceptance criteria:**
- All sampled parameters lie within the CI bounds from `uqResult`.
- Prediction array has shape `[nSamples × n_times × n_outputs]`.

---

## SMoReParS Features (Future)

> Implementation not yet started. Specification will be added when work begins.

**Feature: CM Posterior Inference**
- This is where real-world observational data enters the pipeline. Given a fitted SM (from `SMoReBase`) and real-world observations, infer a posterior distribution over CM parameter space.
- Inputs:
  - Real-world observational data (type TBD — likely a sibling to `CMData`)
  - Fitted SM parameters (`SMFitResult`) and SM UQ (`SMUQResult`) from `SMoReBase`
  - CM parameter bounds
- Planned API: `buildPosterior(sm, realWorldData, uqResult, cmBounds; ...) -> CMPosteriorResult`

---

## SMoReGloS Features (Future)

> Implementation not yet started. Specification will be added when work begins.

**Feature: Sensitivity Analysis of SM Outputs**
- `runSensitivity(sm, fitResults, cmBounds, method; conditions, outputFn, parallel) -> SensitivityResult`
- `method` dispatch: `EFAST(...)`, `Morris(...)`
- Implementation: wrap `GlobalSensitivity.jl` — evaluate the SM as a callable at the required parameter samples, pass results to the GSA library for index computation
- `outputFn::Function` — maps SM prediction matrix → scalar(s) for sensitivity; default = final time point of each variable
- `SensitivityResult` wraps method-specific GSA result plus raw prediction array

**Feature: Lift Sensitivity to CM Parameter Space**
- Given SM sensitivity indices, propagate back through the SM parameter → CM parameter mapping to obtain CM-space sensitivity

---

## Ruled Out / Deferred

- **Raw cell-level CM data in `CMData`**: CM outputs that are variable-length tables (e.g., per-cell trajectories) are out of scope for v0. A future `CellTableCMData` subtype will handle this.
- **`LHSSensitivity` as a formal GSA method type**: LHS-based prediction sampling is a utility (`sampleSMPredictions`) for uncertainty propagation, not a global sensitivity analysis method. Keeping it separate from `SMoReGloS` avoids confusing UQ with GSA.
- **`GlobalSensitivity.jl` inside `SMoReBase`**: SM sensitivity lives in `SMoReGloS`. Within `SMoReBase`, only `sampleSMPredictions` (MC, not GSA) is provided.
- **Full `OrdinaryDiffEq` as a direct dependency**: The package is a weak dependency to keep `SMoReVerse` lean. Users who use `ODESurrogateModel` must load `OrdinaryDiffEq` themselves. This activates the `SMoReBaseOrdinaryDiffEqExt` extension.
- **Separate `WeightedSSE` loss type**: `GaussianNLL` already subsumes weighted SSE; a duplicate type would create ambiguity.
