# Fit the surrogate model for a single param_set.
# Returns (fitted_params, error_val, converged, raw_result).
function _fitOneParamSet(
    sm::AbstractSurrogateModel,
    data::AbstractCMData,
    p0_row::AbstractVector,
    prior::ParameterPrior,
    conditions::ConditionSpec,
    loss::AbstractLoss,
    optimOptions::NamedTuple,
    param_set_idx::Int,
)
    obj = _buildObjective(sm, data, conditions, loss, param_set_idx)
    opt_fn  = OptimizationFunction(obj, Optimization.AutoForwardDiff())
    lb = _lowerBounds(prior)
    ub = _upperBounds(prior)
    prob = OptimizationProblem(opt_fn, collect(Float64, p0_row), nothing; lb, ub)
    sol  = solve(prob, Fminbox(LBFGS()); optimOptions...)
    converged = !isnan(sol.objective) && !isinf(sol.objective)
    return sol.u, sol.objective, converged, sol
end

# Fit all param_sets, optionally in parallel via Threads.@threads.
function _fitAllParamSets(
    sm::AbstractSurrogateModel,
    data::AbstractCMData,
    P0::AbstractMatrix,
    prior::ParameterPrior,
    conditions::ConditionSpec,
    loss::AbstractLoss,
    optimOptions::NamedTuple,
    parallel::Bool,
)
    n_ps     = size(P0, 1)
    n_params = size(P0, 2)
    params     = Matrix{Float64}(undef, n_ps, n_params)
    errors     = Vector{Float64}(undef, n_ps)
    converged  = BitVector(undef, n_ps)
    opt_results = Vector{Any}(undef, n_ps)

    if parallel
        Threads.@threads for i in 1:n_ps
            p, e, c, r = _fitOneParamSet(sm, data, P0[i, :], prior, conditions, loss, optimOptions, i)
            params[i, :]   = p
            errors[i]      = e
            converged[i]   = c
            opt_results[i] = r
        end
    else
        for i in 1:n_ps
            p, e, c, r = _fitOneParamSet(sm, data, P0[i, :], prior, conditions, loss, optimOptions, i)
            params[i, :]   = p
            errors[i]      = e
            converged[i]   = c
            opt_results[i] = r
        end
    end

    return params, errors, converged, opt_results
end
