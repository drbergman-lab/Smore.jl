# CLAUDE.md — Smore.jl

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

Smore.jl is a Julia port and generalization of the MATLAB [SMoReParS](https://github.com/drbergman/SMoReParS) framework (Surrogate Modeling for Reconstructing Parameter Surfaces). The SM sits between the CM and the real world: it is trained on CM-generated output, then used as a fast proxy for comparing against real-world data and analyzing CM behavior.

**This repo is a thin meta-package.** The three sub-packages that implement successive steps of the pipeline each live in their own repository and are declared as regular registered dependencies here:
- **`SmoreBase`** — abstract types, SM fitting, UQ of SM parameters
- **`SmoreFit`** — posterior inference on CM parameter space
- **`SmoreGSA`** — global sensitivity analysis of SM outputs

A sibling package `SmoreExamples.jl` holds worked examples and model-specific code. Do **not** add model-specific code to this repo.

## Repository Structure

This repo contains only the meta-package entry point. All feature code lives in the sub-package repos.

```
Project.toml    # Smore meta-package; lists SmoreBase, SmoreFit, SmoreGSA as [deps]
src/
└── Smore.jl   # re-exports: `using SmoreBase, SmoreFit, SmoreGSA`
test/
└── runtests.jl
docs/
```

## Scope

Work in this repo is limited to:
- `src/Smore.jl` (re-export list)
- `Project.toml` (dependency versions)
- Documentation (`README.md`, `docs/`)
- CI configuration (`.github/workflows/`)

Feature work on SmoreBase, SmoreFit, or SmoreGSA belongs in their respective repos. Do **not** access or edit files in `SmoreExamples.jl` or any other repo.

## Worktree Sessions

When Claude Code launches a session inside a git worktree (primary working directory ends with `.claude/worktrees/<name>`), **all file reads and writes must use paths rooted at the worktree, not the main repo root.** The main repo may appear as an "Additional working directory" in the environment block — ignore it for file edits.

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
- **Internal helpers:** `_camelCase` prefix (e.g., `_evaluate`, `_buildObjective`, `_computeCI`)
- **Types / Structs:** `PascalCase` (e.g., `CMData`, `ODESurrogateModel`, `SMFitResult`)
- **Constants / module-level refs:** `snake_case` for internal refs; `SCREAMING_SNAKE_CASE` for env vars
- **Files:** `snake_case.jl` (e.g., `cm_data.jl`, `surrogate_model.jl`)
- **Exported vs internal:** public API exported from the relevant sub-package entrypoint; internal helpers prefixed `_`
- **Unicode field names:** use mathematical Unicode in structs where unambiguous (e.g., `μ`, `σ`, `Σ` in `CMData`)

## Git Rules

**Never stage or commit without explicit instruction.**
The human reviews diffs and stages files themselves. Do not run `git add`, `git stage`, or `git commit` unless the human explicitly asks you to. You may run read-only git commands (`git status`, `git diff`, `git log`, `git branch`) freely.

## Required Workflow for Any Change

1. Generate a **design brief** in the assistant response **before any code changes**.
2. Wait for human approval.
   1. Update PRD.md to include new feature or changes.
   2. Open a new entry in progress.md and log design process, decisions, open questions.
3. Create the feature branch: `git checkout -b feature/<desc>`.
4. Implement in the feature branch only.
5. Update [README.md](README.md) Implementation Status when a feature is complete.
6. Trim PRD.md and progress.md to reflect final implementation before merging.
7. Tell the human the branch is ready; they will review, stage, and commit.

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

- Meta-package entrypoint: `src/Smore.jl` — update this when a sub-package adds a new public export that should be re-exported.
- Run meta-package tests: `julia --project=. -e 'using Pkg; Pkg.test()'`

## Julia Environment Rules

- Always run Julia with `--project=.`
- Preferred test command: `julia --project=. -e 'using Pkg; Pkg.test()'`
- Do not edit `Manifest.toml` or add/bump dependencies without explicit approval.
