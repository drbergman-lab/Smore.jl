# Draw `n` samples from the marginal distribution defined by a profile LL curve using
# piecewise-linear inverse-CDF sampling. The unnormalized density at each grid point is
# proportional to exp(ll); a trapezoid-rule CDF is built over the profile grid and then
# inverted by linear interpolation.
function _sampleProfileCurve(
    rng::AbstractRNG,
    profile_values::AbstractVector,
    log_likelihoods::AbstractVector,
    n::Int,
)
    xs = profile_values
    w  = exp.(log_likelihoods .- maximum(log_likelihoods))

    # Trapezoid-rule CDF: cdf[i] = ∫_{xs[1]}^{xs[i]} w dx (unnormalized)
    m   = length(xs)
    cdf = Vector{Float64}(undef, m)
    cdf[1] = 0.0
    for i in 2:m
        cdf[i] = cdf[i-1] + 0.5 * (w[i-1] + w[i]) * (xs[i] - xs[i-1])
    end
    cdf ./= cdf[end]   # normalize to [0, 1]

    # Inverse-CDF: for each u ~ Uniform(0,1), find interval and interpolate
    samples = Vector{Float64}(undef, n)
    for k in 1:n
        u = rand(rng)
        # searchsortedlast returns largest i s.t. cdf[i] ≤ u
        i = searchsortedlast(cdf, u)
        i = clamp(i, 1, m - 1)
        Δc = cdf[i+1] - cdf[i]
        t  = Δc < eps(Float64) ? 0.0 : (u - cdf[i]) / Δc
        samples[k] = xs[i] + t * (xs[i+1] - xs[i])
    end
    return samples
end

"""
    sampleSMPredictions(sm, uqResult; nSamples, conditions, rng) -> SampledPredictions

Sample SM predictions by drawing parameter vectors from the distribution encoded in
`uqResult` and evaluating the SM at each draw.

For `ProfileLikelihoodResult`: each parameter is sampled independently from its marginal
profile-LL distribution using piecewise-linear inverse-CDF sampling. The unnormalized
density at each grid point is `exp(ll - max(ll))`; a trapezoid-rule CDF interpolates
between grid points so that samples are continuous rather than pinned to discrete grid
locations. This is a product-measure approximation — marginal LL shapes are respected but
correlations between parameters are ignored.

# Arguments
- `sm` — the fitted surrogate model
- `uqResult::ProfileLikelihoodResult` — UQ result from `_uq`

# Keyword arguments
- `nSamples::Int` — number of parameter samples (default: 100)
- `conditions::ConditionSpec` — conditions at which to evaluate the SM (default: `ConditionSpec()`)
- `rng` — random number generator (default: `Random.default_rng()`)

# Returns
`SampledPredictions` with:
- `parameters` — `[n_sm_params × nSamples]`
- `predictions` — `[n_times × n_outputs × nSamples]`

# Example
```julia
samples = sampleSMPredictions(sm, uq_result; nSamples=200)
```
"""
function sampleSMPredictions(
    sm::AbstractSurrogateModel,
    uqResult::ProfileLikelihoodResult;
    nSamples::Int             = 100,
    conditions::ConditionSpec = ConditionSpec(),
    rng::AbstractRNG          = Random.default_rng(),
)
    n_params = length(uqResult.profiles)

    params = Matrix{Float64}(undef, n_params, nSamples)
    for (i, pc) in enumerate(uqResult.profiles)
        params[i, :] = _sampleProfileCurve(rng, pc.profile_values, pc.log_likelihoods, nSamples)
    end

    # Evaluate SM at each sample (first condition only in v0)
    times      = uqResult.times
    cond_label = conditions[1]
    A_test     = _evaluate(sm, times, params[:, 1], cond_label)
    n_t, n_out = size(A_test)

    preds = Array{Float64,3}(undef, n_t, n_out, nSamples)
    preds[:, :, 1] = A_test
    for s in 2:nSamples
        preds[:, :, s] = _evaluate(sm, times, params[:, s], cond_label)
    end

    return SampledPredictions{Float64}(params, preds)
end
