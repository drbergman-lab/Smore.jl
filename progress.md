# progress.md — SMoReVerse.jl Session Journal

> **Purpose:** Session-level decisions, rejected approaches, and open questions.
> Unlike [PRD.md](PRD.md) (specification) and [README.md](README.md) (completion status), this file captures the *reasoning* behind decisions — things that would otherwise exist only in ended chat history.

---

## Session: Initialization — Package architecture and documentation (2026-05-19)

### Goal
Scaffold the SMoReVerse.jl repo: rename it from SMoRe, define the monorepo structure, write documentation (README, CLAUDE.md, PRD, progress), and create stub source files. No implementation code in this session.

### Key Design Decisions

**Monorepo with three independent sub-packages**
The original SMoReParS MATLAB repo has three major components (SM fitting, profile likelihood, sensitivity). Rather than a single flat package, SMoReVerse is structured as a monorepo where `SMoReBase`, `SMoReParS`, and `SMoReGloS` are each proper Julia packages with their own `Project.toml` and UUIDs, living under the repo root. The root `Project.toml` defines a `SMoReVerse` meta-package (like `DifferentialEquations.jl`) that re-exports all three, and uses Julia's `[workspace]` feature so they resolve locally. Each sub-package can be registered and split into its own repo independently when the time comes — no structural refactor needed, just move the directory.

**"Complex model" not "ABM"**
The package is named around the concept of a slow, expensive "complex model" (CM) rather than specifically an agent-based model. In all known use cases the CM is an ABM, but the framework is general. Field names, type names, and documentation use "CM" consistently.

**`camelCase` for functions**
Consistent with ModelManager.jl. `camelCase` distinguishes function calls (`fitSurrogate(...)`) from variable names and field accesses, which is especially useful in Julia where both use similar syntax. Would require a deliberate migration to change to `snake_case` in ModelManager; keeping them consistent is the right call.

**Unicode field names in `CMData`**
`μ`, `σ`, `Σ` for mean, standard deviation, and covariance. Julia supports Unicode identifiers and mathematical notation is standard practice in scientific Julia packages (e.g., Turing.jl, DifferentialEquations.jl). Makes the correspondence to mathematical notation explicit.

**`OrdinaryDiffEq` as a weak dependency (package extension)**
The full `OrdinaryDiffEq.jl` is a large transitive dependency. For users who only use `AnalyticalSurrogateModel`, there is no reason to pay that cost. The ODE-solving logic lives in `ext/SMoReBaseOrdinaryDiffEqExt.jl` and activates only when the user loads `using OrdinaryDiffEq`. This follows the Julia 1.9+ package extensions mechanism.

**`ProfileLikelihood` as one UQ method under `AbstractUQMethod`**
Profile likelihood is the first UQ method implemented (ported from MATLAB SMoReParS), but the API is designed for extensibility. The internal dispatch function `_uq(sm, data, fitResult, method; ...)` takes the method as a type argument. Users will call higher-level pipeline functions (API TBD in a future session) rather than `_uq` directly.

**Confidence interval formula: Wilks' theorem**
`CI = {θ_i : PL(θ_i) ≥ L* − 0.5 × χ²₁,α}` — verified against Wilks (1938). By the theorem, `−2(PL(θ_i) − L*) ~ χ²_1` asymptotically, so the threshold `L* − 0.5 × quantile(Chisq(1), α)` correctly identifies the confidence region at level `α`. For 95%: threshold = `L* − 1.92`.

**`GlobalSensitivity.jl` for sensitivity analysis (SMoReGloS)**
Rather than native EFAST/Morris implementations, SMoReGloS will wrap `GlobalSensitivity.jl`. The SM is callable (unlike the CM which is external), so the GSA library's interface fits naturally. This avoids reimplementing FFT-based EFAST index computation. The only caveat: `GlobalSensitivity.jl` uses a function-evaluation interface; SMoReGloS provides the wrapper that calls `_evaluate(sm, ...)` at the required sample points.

**`sampleSMPredictions` is not a sensitivity method**
LHS-based Monte Carlo sampling within the profile-likelihood CI region is uncertainty propagation (spreading SM parameter uncertainty to prediction uncertainty), not global sensitivity analysis. It lives in `SMoReBase` as a utility, not in `SMoReGloS`.

**`GaussianNLL` only (no separate `WeightedSSE`)**
The default loss is `GaussianNLL`. `WeightedSSE` (sum of squared errors divided by variance) is a special case of `GaussianNLL` (dropping the log-determinant term, which is constant when `σ` does not depend on `p`). Adding a separate type would create ambiguity. Power users can supply a `CustomLoss` if they want a different form.

### Open Questions

- **Higher-level pipeline API**: users should call something like `runSMoReBase(sm, data, ...)` that orchestrates fitting + UQ in one call. What does this API look like? What keyword arguments does it expose? Defer to implementation session.
- **`CMData` shape for multiple cohorts and conditions**: should cohort/condition be axes of the data arrays (requiring a 4D structure), or should `CMData` hold a single (condition × time × output) block and be used in a vector-per-cohort pattern? The current spec is deliberately vague on this — revisit when implementing `CMData`.
- **`SMUQResult` abstract type**: should `ProfileLikelihoodResult` subtype `AbstractSMUQResult`, or just be a standalone struct? If `Bootstrap` and `MCMC` UQ methods are added, a common abstract type would enable generic downstream code.
- **Repo rename timing**: the directory `~/.julia/dev/SMoRe` should be renamed to `~/.julia/dev/SMoReVerse` and the GitHub repo renamed. Do this before the next implementation session.

### Status
Branch `claude/funny-mendeleev-b87754`. All documentation files written, stub source structure created. No implementation code. Ready for first implementation session on `SMoReBase`.

---

## Session: SMoReBase Implementation (2026-05-19)

### Goal
Implement all SMoReBase stub files (types, fitting, profile likelihood, sampling, ODE extension) and tests.

### Key Design Decisions

**Conditions are categorical labels only**
Decided in planning: `ConditionSpec` wraps `Vector{String}`. The SM function encodes the numeric effect of each condition internally. Eliminates the `ConditionSpec.values::Matrix` field from the original PRD.

**`ParameterBounds` → `ParameterPrior`**
Generalized from box bounds to a `Vector{<:UnivariateDistribution}`. Box bounds are represented as `Uniform(lb, ub)`. Convenience constructor `ParameterPrior(lower, upper; names)` wraps pairs into `Uniform`. Optimization bounds derived from `support(d)` via `_lowerBounds`/`_upperBounds`. This makes the type directly useful for SMoReParS posterior inference.

**"cohort" → "param_set" throughout**
More precise terminology: one param_set = one CM parameter vector whose runs generated training data for the SM. `CMData` axis 1 is `n_param_sets`; field name `param_set_labels`.

**CMData canonical shape: 4-D `[n_param_sets, n_conditions, n_times, n_outputs]`**
Resolves the open question from the init session. 2-D and 3-D inputs are promoted automatically in the keyword constructor. This resolves all axis ambiguity.

**`ForwardDiff` added as a direct dependency**
`Optimization.jl` v5 requires an explicit ADType (`AutoForwardDiff()`) for gradient-based optimization — there is no implicit fallback. `ForwardDiff` was already a transitive dependency in the manifest; adding it to `Project.toml` does not install any new packages.

**Profile likelihood: fixed-parameter optimization via projection**
`_profileLL` builds a reduced `(n_params-1)`-vector objective: captures the full objective in a closure, projects free parameters back into the full space, fixes `p[fixed_idx] = fixed_val`. The inner closure correctly handles `ForwardDiff.Dual` elements by using `T = eltype(p_free)` for the full parameter vector.

**`sampleSMPredictions` v0: first condition only**
LHS sampling evaluates the SM at `conditions[1]` only. Multi-condition sampling deferred to when `SMoReParS` integration clarifies the expected output shape.

**QuasiMonteCarlo 0.3.x: no `rng` kwarg for `LatinHypercubeSample`**
The `rng` keyword is not supported in the installed version. For reproducibility, users should call `Random.seed!` before `sampleSMPredictions`.

### Status
Branch `feature/smorebase-implementation`. All 11 stub files implemented, `sampling.jl` added, `SMoReBase.jl` updated. All tests pass (`julia --project=. -e 'using Pkg; Pkg.test()'`). Ready to open PR.

---

## Session: SMoReGloS — `runSensitivity` (2026-05-20)

### Goal
Implement `runSensitivity` in SMoReGloS: GSA of CM output with respect to CM parameters, using the SM as a fast proxy for the CM.

### Key Design Decisions

**Sensitivity is of CM output to CM parameters (not SM parameters)**
Initial plan considered varying SM parameters directly. Clarified with user: the SM acts as a fast CM proxy. For any CM parameter vector requested by the GSA algorithm, the SM is evaluated by (1) interpolating SM parameter CI bounds from the nearest known cohort, (2) LHS-sampling within the resulting box, (3) averaging SM outputs over LHS draws. This mirrors MATLAB `sampleFromSMProfiles.m`.

**ICDF transform inside the callable; unit bounds to GlobalSensitivity.jl**
`ParameterPrior` stores full `Distributions.jl` distributions for CM parameters. The callable `f(u)` accepts `u ∈ [0,1]^n_cm` and applies `θ_CM[i] = quantile(cm_prior.distributions[i], u[i])` (inverse CDF). `GlobalSensitivity.gsa` is given `[[0.0, 1.0] for _ in 1:n_cm]` as bounds. This correctly handles non-uniform CM priors for both EFAST and Morris.

**Nearest-neighbor interpolation of CI bounds (v1)**
For arbitrary CM parameter vectors, the CI bounds are taken from the closest known cohort (Euclidean distance in CM parameter space). No interpolation library needed; the inner loop is O(n_cohorts) and n_cohorts is typically small. Richer interpolation (linear, RBF) deferred.

**`LatinHypercubeSample(rng=rng)` works in QuasiMonteCarlo 0.3.x**
The progress note from the SMoReBase session was outdated. The installed QMC version (`sBroe`, v0.3.x) does support `LatinHypercubeSample(rng=...)` via `@kwdef`.

**`_runSensitivity` takes `n_cm::Int`, not bounds**
Since bounds are always `[0,1]^n_cm` (ICDF is inside the callable), the internal dispatch functions construct unit bounds from `n_cm` directly. No bounds need to be threaded through from `runSensitivity`.

**Morris `total_num_trajectory` default**
When `nothing`, we pass `10 × num_trajectory` to `GlobalSensitivity.Morris`. This matches GlobalSensitivity.jl's effective default and makes the behavior explicit.

**`ST = nothing` for Morris**
Morris does not compute total-order indices; `SensitivityResult.ST` is `Union{Nothing, Matrix{T}}` to accommodate this cleanly.

### Status
Branch `feature/smoregloss-run-sensitivity`. All 6 source files implemented, module and Project.toml updated. All 5 test sets pass (20 assertions). Ready to open PR.

---

## Session: MLE-anchored profile grid (2026-05-20)

### Problem
The profile likelihood grid was built as a regular `range(lb, ub; length=n_points)`, which almost never includes the exact MLE value. When a parameter is sharply identified, the LL can drop below the CI threshold within a single grid step of the MLE. If no grid point has `ll >= threshold`, `_computeCI` returns `nothing` for both bounds — a false unidentifiability result.

Reported symptom: `ci_lower = nothing, ci_upper = nothing` when profiling K in a logistic growth model with T_final=50 (dynamics reach carrying capacity, so K is well-identified).

### Design decisions

**MLE-anchored grid with proportional split**
Always include `p_mle[i]` as a grid point. Split the remaining `n_points - 1` points in proportion to the distance from the MLE to each boundary:
- `frac_left = (mle_val - lb) / (ub - lb)`
- `n_left = max(1, round(Int, frac_left * (n_points - 1)) + 1)` (includes MLE)
- `n_right = n_points - n_left + 1` (includes MLE; deduped when concatenating)

Equal split (`ceil(n_points/2)`) was rejected: when the MLE is near a boundary, it wastes most points on the infeasible side.

**Outward warm-start**
Each half is scanned outward from the MLE (left half: MLE → lb; right half: MLE → ub), warm-starting the inner optimizer from the previous grid point. This keeps the warm start near the region of high LL and improves convergence of the re-optimization step.

**Test data range extended to t=50**
The existing ProfileLikelihood test used t ∈ [0, 5], which leaves K completely unidentifiable (N(5) ≈ 0.19 ≪ K=4). The test's conditional CI check masked this. Changed to t ∈ [0:5:50] so K is visible in the data, allowing the CI assertion to be made unconditional.

### Status
All SMoReBase tests pass (16 assertions in ProfileLikelihood). Branch `feature/mle-anchored-profile` ready for review.

---

## Session: Plotting Recipes (RecipesBase.jl) (2026-05-21)

### Goal
Add backend-agnostic plot recipes to `SMoReBase` and `SMoReGloS` so users can assess every pipeline stage: fit quality, profile likelihood curves, prediction uncertainty bands, and sensitivity bar charts.

### Key Design Decisions

**RecipesBase as a direct dep (not an extension)**
RecipesBase.jl is ~60 lines with zero transitive dependencies. It is explicitly designed to be included as a direct dep so that `plot(result)` works as soon as any Plots.jl-compatible backend is loaded. Packages like Distributions.jl, DataFrames.jl, and StatsBase.jl all follow this pattern. Using a package extension (activated by Plots.jl) would be heavier and would break the dispatch chain when users call `plot(result)` without loading Plots explicitly first.

**`SMFitPlot` wrapper struct instead of `@userplot`**
`@userplot` is a Plots.jl macro (not RecipesBase). For the multi-arg fit recipe `(sm, data, fit)`, a plain struct `SMFitPlot` is used. Users call `plot(SMFitPlot(sm, data, fit))`. This is idiomatic RecipesBase and requires no Plots.jl at recipe definition time.

**Standalone `plot(SMFitResult)` for parameter diagnostics**
`SMFitResult` holds all param_sets in one struct (`parameters` is `[n_param_sets × n_sm_params]`). The recipe shows fitted values on y, param_set index on x, one subplot per SM parameter, colored by convergence. Colorblind-friendly colors: `#0072B2` (converged) / `#D55E00` (not converged) from the Wong/Paul Tol palette. Two separate series handle the two states so Plots.jl handles color consistently; empty series are omitted.

**`SampledPredictions.times` field added**
`sampleSMPredictions` already uses `uqResult.times` internally; adding it to the struct is a minimal, zero-breaking change that enables `plot(sampled)` to work standalone without passing times externally. The field is `Union{Nothing,Vector{T}}` to handle future construction paths where times may be absent.

**`ProfileLikelihoodResult` delegates to `ProfileCurve` recipe**
The top-level recipe sets `layout := (1, n_params)` and uses `@series begin; subplot := i; pc; end` to delegate each panel to the `ProfileCurve` recipe. Plots.jl's recipe dispatch chain handles the second level automatically.

**Sensitivity bar chart: CM parameters on x-axis**
With `S1 :: [n_outputs × n_cm_params]` (native GlobalSensitivity.jl layout), the most common presentation puts CM parameter names on the x-axis and groups bars by output. ST bars are shown alongside S1 bars (same x positions, lighter fill) when `show_ST=true` (default) and `sensitivity_ST` is not `nothing`.

### Open Questions
- None; design is fully specified and approved.

### Status
Branch `feature/plot-recipes`. All 9 new test sets pass, no regressions. Ready for review.

---

## Session: Makie Plot Extensions (2026-05-21)

### Goal
Add optional Makie ecosystem plot support to `SMoReBase` and `SMoReGloS` as Julia package extensions, mirroring every existing RecipesBase recipe without making Makie a hard dependency.

### Key Design Decisions

**`Makie` as weak dep, not `MakieCore`**
`MakieCore` only provides the `@recipe` macro and abstract plot types. `Figure`, `Axis`, `lines!`, `scatter!`, `band!`, `barplot!`, `hlines!`, `vlines!`, `errorbars!`, `Legend`, etc. all live in `Makie`. The extensions create multi-panel figures, so `Makie` is the correct weak dep. All Makie backends (CairoMakie, GLMakie, WGLMakie) depend on and load `Makie`, so the extension fires for any backend.

**Single extension per package, not two**
An earlier idea proposed one `MakieCoreExt` (composable `@recipe` types) and one `MakieExt` (convenience figure builders). Rejected: both extensions would fire simultaneously when any backend is loaded (since backends load both MakieCore and Makie), creating redundancy. A single `MakieExt` per package using `Makie` as the weak dep provides both composability and convenience in one place.

**`Makie.plot(result)` methods, not `@recipe` types**
The Makie extensions define ordinary Julia methods `Makie.plot(r::SomeType; kwargs...) -> Figure` rather than `@recipe`-based custom plot types. This keeps the implementation simple and directly mirrors the RecipesBase recipes' return behavior. The `@recipe` approach would require restructuring each recipe as an observable-driven custom plot type drawing into a single axis — adding complexity without benefit for the initial implementation.

**`barplot!` with dodge for sensitivity chart**
Multiple `barplot!` calls at the same x positions, each specifying `dodge` (integer group index) and `n_dodge` (total groups). S1 and ST bars for the same output are interleaved: S1 at dodge=2v-1, ST at dodge=2v. ST bars use `alpha=0.45` for reduced opacity. The `n_dodge` keyword should be verified against the installed Makie version in the Manifest.

### Open Questions
- None; design approved.

### Status
Branch `feature/makie-extensions`. All files written; no tests added (Makie is a large dependency and not suitable for the test suite). The `barplot!` `n_dodge` keyword should be verified against the installed Makie version before the first live use. Ready for review.

---

## Session: RecipesBase → Package Extension (2026-05-21)

### Goal
Move the RecipesBase plot recipes from direct dependencies to package extensions (`SMoReBasePlotsExt`, `SMoReGloSPlotsExt`), so that all plotting backends (Plots.jl and Makie) are uniformly optional.

### Key Design Decisions

**`SMFitPlot` stays in the main package**
`SMFitPlot` is a plain struct that users construct before calling any plot function — both the Plots and Makie extensions dispatch on it. If the struct lived in the extension, Makie-only users would need to load RecipesBase just to construct it. The struct stays in `src/plots/fit_recipe.jl` and is exported from `SMoReBase`; only the `@recipe` implementations move to the extension.

**`using RecipesBase` removed from module entrypoints**
`SMoReBase.jl` and `SMoReGloS.jl` no longer `using RecipesBase`. Recipe registration happens inside the extension modules when the user loads RecipesBase (via any Plots-compatible backend). Tests already `using RecipesBase` at the top, so the extension fires automatically during test runs.

**`_evaluate` accessed via `SMoReBase._evaluate` in the extension**
`using SMoReBase` in the extension gives only exported symbols. The fit recipe calls `SMoReBase._evaluate(...)` with the explicit module prefix, consistent with the ODE extension pattern.

### Status
Branch `feature/plot-extensions`. All files written. Existing tests unchanged — `using RecipesBase` in each test file triggers the extension. Ready for review.
