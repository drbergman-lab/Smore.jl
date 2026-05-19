"""
    fitSurrogate(sm, data, P0, prior; conditions, loss, parallel, optimOptions) -> SMFitResult

Fit surrogate model parameters to CM summary statistics for each param_set.

One independent bounded optimization is run per param_set using `Fminbox(LBFGS())`
(via `Optimization.jl` + `OptimizationOptimJL`).

# Arguments
- `sm::AbstractSurrogateModel` — the surrogate model to fit
- `data::AbstractCMData` — CM summary statistics
- `P0::AbstractMatrix` — initial parameter guesses `[n_param_sets × n_sm_params]`
- `prior::ParameterPrior` — parameter priors (bounds derived from distribution support)

# Keyword arguments
- `conditions::ConditionSpec` — experimental conditions (default: single `"default"` condition)
- `loss::AbstractLoss` — loss function (default: `GaussianNLL()`)
- `parallel::Bool` — fit param_sets in parallel via `Threads.@threads` (default: `false`)
- `optimOptions::NamedTuple` — forwarded to `Optimization.jl` `solve()` (default: `(;)`)

# Returns
`SMFitResult` with fitted parameters in `[lb, ub]` for each param_set.

# Example
```julia
prior  = ParameterPrior([0.0, 0.0], [2.0, 10.0]; names=["r", "K"])
P0     = [0.5 5.0]
result = fitSurrogate(sm, data, P0, prior)
```
"""
function fitSurrogate(
    sm::AbstractSurrogateModel,
    data::AbstractCMData,
    P0::AbstractMatrix,
    prior::ParameterPrior;
    conditions::ConditionSpec  = ConditionSpec(),
    loss::AbstractLoss         = GaussianNLL(),
    parallel::Bool             = false,
    optimOptions::NamedTuple   = (;),
)
    n_ps     = n_param_sets(data)
    n_params = length(prior)

    size(P0, 1) == n_ps ||
        throw(ArgumentError("P0 has $(size(P0, 1)) rows but data has $n_ps param_sets"))
    size(P0, 2) == n_params ||
        throw(ArgumentError("P0 has $(size(P0, 2)) columns but prior has $n_params parameters"))
    length(conditions) == n_conditions(data) ||
        throw(ArgumentError(
            "conditions has $(length(conditions)) labels but data has $(n_conditions(data)) conditions"
        ))

    params, errors, conv, opt_results = _fitAllParamSets(
        sm, data, P0, prior, conditions, loss, optimOptions, parallel,
    )

    return SMFitResult{Float64}(
        params,
        errors,
        convert(Matrix{Float64}, P0),
        prior,
        conv,
        opt_results,
    )
end
