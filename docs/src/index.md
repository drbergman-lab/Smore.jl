```@meta
CurrentModule = Smore
```

# Smore

Documentation for [Smore](https://github.com/drbergman-lab/Smore.jl).

## Pipeline Overview

| Step | Sub-package | API |
|------|-------------|-----|
| 1–4  | `SmoreBase` | `SMFitProblem`, `fitSurrogate` |
| 5    | `SmoreBase` | `quantifyUncertainty` (profile likelihood) |
| 6    | `SmoreBase` | `sampleSMPredictions` |
| 7    | `SmoreGSA`  | `runSensitivity` |
| 8    | `SmoreFit`  | `buildPosterior`, `posteriorScore`, `inPosterior` |

Steps 1–6 fit a surrogate model (SM) to complex model (CM) output and quantify its parameter
uncertainty. The shared backbone from there is a per-CM-parameter-set `ProfileLikelihoodResult`:

- **Step 7 (`SmoreGSA`)** treats those profiles as an uncertainty envelope and asks how SM output
  varies as CM parameters change.
- **Step 8 (`SmoreFit`)** treats those profiles as one side of a comparison and asks which CM
  parameter values are consistent with real-world data.

Same upstream cost, two complementary downstream answers. See
[SmoreExamples.jl](https://github.com/drbergman-lab/SmoreExamples.jl) for a full walkthrough —
`logistic_growth_pipeline.jl` for Steps 1–7, `cm_posterior_pipeline.jl` for Step 8.

```@index
```

```@autodocs
Modules = [Smore]
```
