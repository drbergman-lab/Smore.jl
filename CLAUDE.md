# CLAUDE.md — SMoReVerse.jl

## About the User
Assistant professor working on computational modeling of cancer-immune interactions. Research involves mechanistic modeling and agent-based modeling (ABM) frameworks. The "complex model" (CM) in this codebase is typically an ABM, but can be any slow, expensive simulator.

## Key Documents — Read These First

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Project overview + **Implementation Status** (what is built, what remains) |
| [PRD.md](PRD.md) | Behavioral specification for every feature — acceptance criteria and edge cases |
| [progress.md](progress.md) | Session journal: decisions made, approaches rejected, open questions |

Start any feature session by reading the relevant PRD entry and the Implementation Status section of `README.md`.

## Project Overview

SMoReVerse.jl is a Julia port and generalization of the MATLAB [SMoReParS](https://github.com/drbergman/SMoReParS) framework (Surrogate Modeling for Reconstructing Parameter Surfaces). The SM sits between the CM and the real world: it is trained on CM-generated output, then used as a fast proxy for comparing against real-world data and analyzing CM behavior. The three sub-packages implement successive steps of this pipeline.

The package is a monorepo with three Julia submodules:
- **`SMoReBase`** — abstract types, SM fitting, UQ of SM parameters
- **`SMoReParS`** — posterior inference on CM parameter space
- **`SMoReGloS`** — global sensitivity analysis of SM outputs

A sibling package `SMoReExamples.jl` holds worked examples and model-specific code. Do **not** add model-specific code to this repo.

## Monorepo Structure

Three independent Julia packages sharing one repo. Each has its own `Project.toml` and can be registered and split into its own repo independently. The root `Project.toml` defines the `SMoReVerse` meta-package and declares a `[workspace]` so all three packages resolve locally.

```
Project.toml              # SMoReVerse meta-package; [workspace] lists sub-packages
src/
└── SMoReVerse.jl         # meta-package module: `using SMoReBase, SMoReParS, SMoReGloS`
SMoReBase/
├── Project.toml          # SMoReBase package (own UUID); owns all core deps
├── src/
│   ├── SMoReBase.jl
│   ├── types/            # CMData, SurrogateModel, ConditionSpec, loss, results
│   ├── fitting/          # fitSurrogate implementation
│   └── profile/          # UQ (profile likelihood) implementation
├── test/
│   └── runtests.jl
└── ext/
    └── SMoReBaseOrdinaryDiffEqExt.jl  # ODE solving; activated when OrdinaryDiffEq loaded
SMoReParS/
├── Project.toml          # depends on SMoReBase
├── src/SMoReParS.jl
└── test/runtests.jl
SMoReGloS/
├── Project.toml          # depends on SMoReBase + GlobalSensitivity
├── src/
│   ├── SMoReGloS.jl
│   └── sensitivity/      # runSensitivity implementation
└── test/runtests.jl
```

## Scope

All work must remain strictly inside this repository folder (`~/.julia/dev/SMoReVerse/`).
Do **not** access or edit files in `SMoReExamples.jl` or any other repo.

> **Repo rename note:** The local directory is currently named `SMoRe` and will be renamed to `SMoReVerse` by the user at the end of the initialization session. Adjust paths accordingly once the rename is done.

## Worktree Sessions

When Claude Code launches a session inside a git worktree (primary working directory ends with `.claude/worktrees/<name>`), **all file reads and writes must use paths rooted at the worktree, not the main repo root.** The main repo may appear as an "Additional working directory" in the environment block — ignore it for file edits.

**Concretely:** if the worktree is at `~/.julia/dev/SMoRe/.claude/worktrees/foo`, edit `~/.julia/dev/SMoRe/.claude/worktrees/foo/src/SMoReBase/types/cm_data.jl`, NOT the main repo path.

**Pitfall — resumed sessions:** When a session is resumed from a compacted summary, the summary may cite main-repo paths from prior reads. Discard those paths and re-derive the correct worktree-rooted path before making any edits.

## Git Workflow

Claude Code (the CLI tool) runs directly on your machine and can freely run `git add`, `git commit`, `git checkout`, and all other git operations. No restrictions apply.

### Branching Rules
- Never modify `main` directly.
- Default base branch is `main` unless specified otherwise.
- Branch names: `feature/<short-desc>`.
- After merging, delete the feature branch.

## Naming Conventions

- **Functions:** `camelCase` (e.g., `fitSurrogate`, `runSensitivity`, `buildPosterior`)
  - `camelCase` distinguishes function calls from variable/field names, consistent with ModelManager.jl
- **Internal helpers:** `_camelCase` prefix (e.g., `_evaluate`, `_buildObjective`, `_uq`)
- **Types / Structs:** `PascalCase` (e.g., `CMData`, `ODESurrogateModel`, `SMFitResult`)
- **Constants / module-level refs:** `snake_case` for internal refs; `SCREAMING_SNAKE_CASE` for env vars
- **Files:** `snake_case.jl` (e.g., `cm_data.jl`, `surrogate_model.jl`)
- **Exported vs internal:** public API exported from the relevant submodule file; internal helpers prefixed `_`
- **Unicode field names:** use mathematical Unicode in structs where unambiguous (e.g., `μ`, `σ`, `Σ` in `CMData`)

## Required Workflow for Any Change

1. Generate a **design brief** in the assistant response **before any code changes**.
2. Wait for human approval.
   1. Update PRD.md to include new feature or changes.
   2. Open a new entry in progress.md and log design process, decisions, open questions.
3. Create the feature branch: `git checkout -b feature/<desc>`.
4. Implement in the feature branch only.
5. Update [README.md](README.md) Implementation Status when a feature is complete.
6. Trim PRD.md and progress.md to reflect final implementation before merging.
7. Commit and open a PR.

**Design brief template:**
```
# Design Brief: [Feature/Refactor Name]

## Motivation
[1-2 sentences: why is this change needed?]

## Scope
- **Files affected:** `src/...`
- **New files:** (if applicable)
- **Breaking changes:** Yes/No

## Proposed Architecture
[2-3 paragraphs or diagram]

## Testing Strategy
- Unit tests for: [list]
- Integration tests: [if applicable]

## Estimated Effort
- Lines of code: ~[estimate]
- Risk level: Low / Medium / High
```

## Definition of Done

A feature is complete when **all** of the following are true:

1. **Tests pass:** `julia --project=. -e 'using Pkg; Pkg.test()'` runs green.
2. **Docstrings written:** Every exported function has a docstring with description, arguments, return value, and at least one example.
3. **README updated:** Implementation Status marks the feature complete.
4. **PRD reflects reality:** If implementation deviated, update the PRD entry.
5. **No regressions:** Full test suite has no new failures.

## Integration Essentials

- Meta-package entrypoint: `src/SMoReVerse.jl`
- SMoReBase entrypoint: `SMoReBase/src/SMoReBase.jl`
- SMoReParS entrypoint: `SMoReParS/src/SMoReParS.jl`
- SMoReGloS entrypoint: `SMoReGloS/src/SMoReGloS.jl`
- ODE extension: `SMoReBase/ext/SMoReBaseOrdinaryDiffEqExt.jl` (activated by loading `OrdinaryDiffEq`)
- When adding new source files, add the `include(...)` call to the relevant package entrypoint **and** update the `export` list.
- Run tests for a sub-package: `julia --project=SMoReBase -e 'using Pkg; Pkg.test()'`
- Run all tests via the meta-package: `julia --project=. -e 'using Pkg; Pkg.test()'`

## Julia Environment Rules

- Always run Julia with `--project=.`
- Preferred test command: `julia --project=. -e 'using Pkg; Pkg.test()'`
- Do not edit `Manifest.toml` or add dependencies without explicit approval.
- The `OrdinaryDiffEq` dependency is a weak dep; users must load it explicitly to use `ODESurrogateModel`.
