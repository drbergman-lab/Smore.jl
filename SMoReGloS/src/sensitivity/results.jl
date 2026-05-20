"""
    SensitivityResult{R}

Result of a global sensitivity analysis via `runSensitivity`.

# Fields
- `method` — the GSA method used
- `cm_parameter_names` — names of the CM parameters (from `cm_prior.names`)
- `output_labels` — labels for each scalar output from `outputFn`
- `gsa_result` — raw result from `GlobalSensitivity.gsa`; access via `sensitivity_S1` / `sensitivity_ST`
"""
struct SensitivityResult{R}
    method              :: GlobalSensitivity.GSAMethod
    cm_parameter_names  :: Vector{String}
    output_labels       :: Vector{String}
    gsa_result          :: R
end

"""
    sensitivity_S1(result::SensitivityResult) -> Matrix

First-order sensitivity indices in native `GlobalSensitivity.jl` layout `[n_outputs × n_cm_params]`.

- `EFAST`: Sobol first-order index S1.
- `Morris`: absolute mean elementary effects µ* (`means_star`).
"""
sensitivity_S1(r::SensitivityResult{<:GlobalSensitivity.eFASTResult})  = r.gsa_result.S1
sensitivity_S1(r::SensitivityResult{<:GlobalSensitivity.MorrisResult}) = r.gsa_result.means_star

"""
    sensitivity_ST(result::SensitivityResult) -> Union{Matrix, Nothing}

Total-order sensitivity indices `[n_outputs × n_cm_params]`, or `nothing` for Morris.

- `EFAST`: Sobol total-order index ST.
- `Morris`: `nothing` (not computed by the method).
"""
sensitivity_ST(r::SensitivityResult{<:GlobalSensitivity.eFASTResult})  = r.gsa_result.ST
sensitivity_ST(r::SensitivityResult{<:GlobalSensitivity.MorrisResult}) = nothing

# Number of scalar outputs — used internally to build output_labels after GSA.
_n_outputs(r::GlobalSensitivity.eFASTResult)  = size(r.S1, 1)
_n_outputs(r::GlobalSensitivity.MorrisResult) = size(r.means_star, 1)
