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
  - `μ` — mean observations; canonical shape `[n_param_sets, n_conditions, n_times, n_outputs]`; 2-D and 3-D inputs promoted automatically
  - `σ` — pointwise standard deviations (same shape as `μ`)
  - `Σ` — optional full covariance `[n_outputs, n_outputs, n_times]`; `nothing` means independent observations; time is the trailing axis so each `[:, :, ti]` slice is contiguous in memory
  - `times::Vector{T}` — shared time grid
  - `variable_names::Vector{String}` — names of observable output variables
  - `condition_labels::Vector{String}` — labels for experimental conditions
  - `param_set_labels::Vector{String}` — labels for CM parameter vectors (one SM fit per param_set)
- Note: `CMData` holds CM-generated output only. Real-world observational data enters the pipeline in `SMoReParS` (as the target against which the fitted SM is calibrated), not here.
- The keyword constructor accepts both Unicode and ASCII aliases for the data fields:
  - `μ` or `mean` — mean observations
  - `σ` or `sd` — standard deviations
  - `Σ` or `cov` — covariance (optional)
  - If both Unicode and ASCII forms are supplied for the same field, throw an `ArgumentError`.
- Constructor validates that `μ` and `σ` have matching shapes; if `Σ` is supplied, validates it is positive semidefinite per time point.

**Supporting types:**
- `ConditionSpec` — experimental conditions as categorical labels:
  - `labels::Vector{String}` — condition labels; the SM function encodes the numeric effect of each condition
  - Convenience constructors: `ConditionSpec("label")`, `ConditionSpec()` (defaults to `["default"]`)
- `ParameterPrior` — SM parameter priors:
  - `distributions::Vector{<:UnivariateDistribution}` — one prior per SM parameter
  - `names::Vector{String}` — parameter names
  - Convenience constructor: `ParameterPrior(lower, upper; names)` wraps pairs into `Uniform` distributions
  - Box bounds derived via `_lowerBounds(prior)` / `_upperBounds(prior)` from distribution support

**Acceptance criteria:**
- `CMData(μ=..., σ=..., times=t)` and `CMData(mean=..., sd=..., times=t)` both construct successfully with default param_set/condition labels.
- Supplying both `μ=` and `mean=` (or both `σ=`/`sd=`, or both `Σ=`/`cov=`) throws a descriptive `ArgumentError`.
- Mismatched `μ` / `σ` shapes throw a descriptive `ArgumentError`.
- `ConditionSpec(["control", "treated"])` stores 2 condition labels.

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
  - `y0::Vector{Float64}` — initial conditions; TODO: extend to `Dict{String,Vector{Float64}}` for condition-specific ICs
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
  - `conditions::ConditionSpec = ConditionSpec()` — experimental conditions
  - `loss::AbstractLoss = GaussianNLL()`
  - `parallel::Bool = false` — if true, fits param_sets in parallel using `Threads.@threads`
  - `optimOptions::NamedTuple = (;)` — forwarded to `Optimization.jl` `solve()`
- Implementation: `Fminbox(LBFGS())` via `OptimizationOptimJL` + `ForwardDiff`; one optimizer call per param_set
- `SMFitResult{T<:Real}`:
  - `parameters::Matrix{T}` — `[n_param_sets × n_sm_params]` — fitted parameters
  - `errors::Vector{T}` — objective value per param_set
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
- For each SM parameter `θ_i`: sweep a grid of `n_points` values anchored at the MLE, fix `θ_i`, re-optimize all other parameters, record the log-likelihood at each grid point
  - Grid is split proportionally: `n_left` points from `lb_i` to `θ_i*` and `n_right` points from `θ_i*` to `ub_i`, where `n_left/n_right ≈ (θ_i* − lb_i)/(ub_i − θ_i*)` and `n_left + n_right − 1 = n_points` (the MLE point is shared)
  - Each half is scanned outward from the MLE (warm-starting from the previous point), guaranteeing that the MLE value is evaluated and the inner optimizer always starts near the best-known solution
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
- The MLE value is always a grid point; its profile LL matches `reference_ll` to optimizer tolerance.

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

### Feature: Pipeline Persistence (Nextflow-compatible)

**One-line description:** Optional disk serialization of each pipeline step's output, enabling Nextflow-style dataflow pipelines where steps are decoupled by files on disk.

**Priority:** Should-have

**Motivation:**
The SMoReVerse pipeline has discrete steps whose outputs are natural checkpoints: CM simulation → `CMData`, SM fitting → `SMFitResult`, UQ → `ProfileLikelihoodResult`, prediction sampling → `SampledPredictions`. Making each step able to write its result to disk and read it back enables:
- Nextflow / workflow-manager integration (each process writes one file, the next reads it)
- Resuming long-running pipelines without re-running earlier steps
- Sharing intermediate results across collaborators

**Behavioral specification:**
- Each major result type (`CMData`, `SMFitResult`, `ProfileLikelihoodResult`, `SampledPredictions`) must be serializable to and from a standard on-disk format.
- Default format: **HDF5** (`.h5`) via `HDF5.jl`; chosen for language-agnostic interop (Python, MATLAB, R can all read HDF5).
- Each pipeline function gains a `save_path::Union{Nothing,AbstractString} = nothing` keyword argument. When non-`nothing`, the result is written to that path before being returned.
- A symmetric `load_*` function (e.g., `loadSMFitResult(path)`) reads the file and reconstructs the result struct.
- Extensibility: the serialization backend is abstracted behind an `AbstractSerializer` interface so users can plug in alternate formats (e.g., JLD2, Arrow, CSV+JSON sidecar). The default `HDF5Serializer` is provided out of the box.

**Proposed API sketch (subject to design):**
```julia
# Writing
result = fitSurrogate(sm, data, P0, prior; save_path = "fit_result.h5")

# Reading
result = loadSMFitResult("fit_result.h5")

# Explicit serializer override (future)
result = fitSurrogate(sm, data, P0, prior; save_path = "fit.jld2", serializer = JLD2Serializer())
```

**Acceptance criteria:**
- Round-trip (write then read) reproduces the result struct exactly (field-by-field equality).
- `save_path = nothing` (default) leaves behavior unchanged — no file I/O.
- HDF5 files are self-describing: dataset names match field names of the struct; units/metadata stored as HDF5 attributes where applicable.
- The `AbstractSerializer` interface is documented so users can implement custom backends.

**Out of scope (v0):**
- `CMData` persistence (CM simulation output likely originates from an external tool and is ingested, not produced, by SMoReVerse — format TBD).
- Streaming / incremental writes during optimization.
- Automatic dependency tracking between files (that belongs in the workflow manager, e.g., Nextflow).

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

## SMoReGloS Features

---

### Feature: Sensitivity Analysis of CM Outputs

**One-line description:** GSA of CM outputs with respect to CM parameters, using the SM as a fast CM proxy.

**Priority:** Must-have

**Behavioral specification:**
- `runSensitivity(sm, uqResults, cm_params, cm_prior, method; times, conditions, outputFn, n_sm_samples, rng) -> SensitivityResult`
  - `sm::AbstractSurrogateModel` — the fitted surrogate model
  - `uqResults::Vector{ProfileLikelihoodResult}` — one profile likelihood UQ result per CM parameter set (cohort)
  - `cm_params::AbstractMatrix` — CM parameter values at each cohort `[n_cohorts × n_cm_params]`
  - `cm_prior::ParameterPrior` — CM parameter distributions/bounds for the GSA sweep; full distributions are used via inverse-CDF transform
  - `method::AbstractGSAMethod` — `EFAST(n_samples)` or `Morris(num_trajectory, ...)`
  - `times::AbstractVector` — time grid for SM evaluation (required keyword)
  - `conditions::ConditionSpec` — experimental conditions (default: `ConditionSpec()`)
  - `outputFn::Function` — maps SM prediction `[n_times × n_outputs]` → `Vector{Float64}`; default: last time point of each output variable
  - `n_sm_samples::Int` — LHS draws per CM parameter point to average over SM parameter uncertainty (default: 16)
  - `rng::AbstractRNG` — RNG for LHS sampling (default: `Random.default_rng()`)
- **Algorithm:** For each CM parameter vector `θ` that the GSA algorithm requires:
  1. Apply inverse-CDF to unit-cube input `u`: `θ_CM[i] = quantile(cm_prior.distributions[i], u[i])`
  2. Find nearest known cohort in `cm_params` (Euclidean distance)
  3. Use that cohort's profile likelihood CI bounds as the SM parameter box; fall back to fit bounds when CI is `nothing`
  4. LHS-sample `n_sm_samples` points within the SM parameter box
  5. Evaluate SM at each LHS draw; return mean `outputFn` result
- This mirrors MATLAB `sampleFromSMProfiles.m`.
- `GlobalSensitivity.gsa` is called with `[[0, 1] for each CM param]` as bounds (ICDF is inside the callable).

**Types:**
- `abstract type AbstractGSAMethod end`
- `EFAST(; n_samples=1000) <: AbstractGSAMethod` — wraps `GlobalSensitivity.eFAST`; computes S1 and ST
- `Morris(; num_trajectory=10, p_steps=nothing, total_num_trajectory=nothing) <: AbstractGSAMethod` — computes µ* elementary effects; no ST
- `SensitivityResult{T<:Real}`:
  - `method::AbstractGSAMethod`
  - `cm_parameter_names::Vector{String}` — from `cm_prior.names`
  - `output_labels::Vector{String}` — one per `outputFn` element
  - `S1::Matrix{T}` — first-order indices `[n_cm_params × n_outputs]`
  - `ST::Union{Nothing, Matrix{T}}` — total-order indices; `nothing` for Morris
  - `gsa_result::Any` — raw `GlobalSensitivity.jl` result

**Acceptance criteria:**
- `runSensitivity(sm, uqResults, cm_params, cm_prior, EFAST(); times=t)` returns `SensitivityResult` with `size(S1) == (n_cm_params, n_outputs)` and `ST !== nothing`.
- `runSensitivity(sm, uqResults, cm_params, cm_prior, Morris(); times=t)` returns `SensitivityResult` with `ST === nothing`.
- When a profile CI bound is `nothing`, the implementation falls back to the fit bounds without error.
- Custom `outputFn` returning a length-2 vector produces `size(S1) == (n_cm_params, 2)`.

**Future (not in v1):**
- Richer CM parameter interpolation (linear, RBF) instead of nearest-neighbor.
- Multi-condition averaging (v1 uses first condition only).
- Adaptive n_sm_samples based on CI width.

---

### Feature: Lift Sensitivity to CM Parameter Space (Future)

> Not yet implemented. Specification will be added when work begins.

- Given SM sensitivity indices, propagate back through the SM parameter → CM parameter mapping to obtain CM-space sensitivity.

---

## Ruled Out / Deferred

- **Raw cell-level CM data in `CMData`**: CM outputs that are variable-length tables (e.g., per-cell trajectories) are out of scope for v0. A future `CellTableCMData` subtype will handle this.
- **`LHSSensitivity` as a formal GSA method type**: LHS-based prediction sampling is a utility (`sampleSMPredictions`) for uncertainty propagation, not a global sensitivity analysis method. Keeping it separate from `SMoReGloS` avoids confusing UQ with GSA.
- **`GlobalSensitivity.jl` inside `SMoReBase`**: SM sensitivity lives in `SMoReGloS`. Within `SMoReBase`, only `sampleSMPredictions` (MC, not GSA) is provided.
- **Full `OrdinaryDiffEq` as a direct dependency**: The package is a weak dependency to keep `SMoReVerse` lean. Users who use `ODESurrogateModel` must load `OrdinaryDiffEq` themselves. This activates the `SMoReBaseOrdinaryDiffEqExt` extension.
- **Separate `WeightedSSE` loss type**: `GaussianNLL` already subsumes weighted SSE; a duplicate type would create ambiguity.
