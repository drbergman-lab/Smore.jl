# Product Requirements Document — Smore.jl

> **Purpose:** This document defines the complete feature set of Smore in behavioral terms. It is the authoritative answer to "what should this system do?" Read this at the start of any feature session to establish alignment between intent and implementation plan.

---

## Product Overview

**Vision:** Smore provides a Julia-native pipeline in which a fast surrogate model (SM) is trained on complex-model (CM) outputs and then used as a bridge to real-world data: fitting the SM to CM output, quantifying uncertainty in SM parameters, calibrating CM parameters against real-world observations via the SM, and analyzing CM behavior through the SM lens.

**Target Users:** Computational modelers who have a slow CM (e.g., an ABM) and want to extract a fast, interpretable surrogate that can be compared to real-world data and analyzed statistically to understand the CM's parameter space.

**Relationship to MATLAB SMoReParS:** Smore is a port and generalization. The "complex model" is not limited to agent-based models — it is any slow simulator.

**This is a thin meta-package.** Smore.jl has no pipeline features of its own — it bundles and re-exports three independently versioned sub-packages, each maintaining its own `PRD.md` as the sole source of truth for its behavioral spec:

| Sub-package | Role | Behavioral spec |
|---|---|---|
| `SmoreBase` | SM fitting + UQ of SM parameters | [SmoreBase.jl PRD.md](https://github.com/drbergman-lab/SmoreBase.jl/blob/main/PRD.md) |
| `SmoreFit`  | Posterior inference on CM parameter space from real-world data | [SmoreFit.jl PRD.md](https://github.com/drbergman-lab/SmoreFit.jl/blob/main/PRD.md) |
| `SmoreGSA`  | Global sensitivity analysis of CM outputs to CM parameters | [SmoreGSA.jl PRD.md](https://github.com/drbergman-lab/SmoreGSA.jl/blob/main/PRD.md) |

A sibling package `SmoreExamples.jl` holds worked examples; it is not a dependency of this package.

---

## Feature: Meta-package re-export

**One-line description:** `using Smore` brings every public symbol from all three sub-packages into scope, with no re-export list to maintain by hand.

**Priority:** Must-have

**Behavioral specification:**
- `src/Smore.jl` re-exports each sub-package via `Reexport.jl`: `@reexport using SmoreBase`, `@reexport using SmoreFit`, `@reexport using SmoreGSA`.
- No manual per-symbol export list — a new public export added to any sub-package is automatically available via `using Smore` once `Project.toml`'s compat floor covers the version that introduced it.
- `Project.toml`'s `[compat]` entries for `SmoreBase`/`SmoreFit`/`SmoreGSA` must be bumped whenever the corresponding sub-package ships a breaking release, so `Pkg.up` in downstream repos (e.g. `SmoreExamples`) resolves to a version that actually has the symbols/behavior their code expects.

**Acceptance criteria:**
- `using Smore` makes every symbol exported by `SmoreBase`, `SmoreFit`, and `SmoreGSA` available without qualification.
- `Pkg.test()` — which delegates to each sub-package's own test suite (see `test/runtests.jl`) — passes.

---

## Ruled Out / Deferred

- **Duplicating sub-package specs here.** This document previously carried a full copy of every sub-package's behavioral spec (types, algorithms, acceptance criteria). That duplication went stale silently — surviving mentions of `custom_error_fn`, `ParameterBounds`, and a since-removed Makie extension long after those changed or were removed in the actual sub-packages — and created two sources of truth that had to be kept in sync by hand. Sub-package `PRD.md` files are now the only source of truth for their own behavior; this file covers only what's true of the meta-package itself.
