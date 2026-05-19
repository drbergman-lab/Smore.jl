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
