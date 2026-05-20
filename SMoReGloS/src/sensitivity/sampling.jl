_defaultOutputFn(pred::AbstractMatrix) = vec(pred[end, :])

# Validate that each CM prior distribution's support fits within the corresponding grid axis.
# Called once at _buildCMCallable time so no per-sample check is needed inside get_bounds.
_validatePriorVsGrid(::AbstractCMSample, ::ParameterPrior) = nothing

function _validatePriorVsGrid(cm_sample::GridCMSample, cm_prior::ParameterPrior)
    for d in eachindex(cm_sample.axes)
        dist = cm_prior.distributions[d]
        lo, hi = minimum(dist), maximum(dist)
        grid_lo, grid_hi = first(cm_sample.axes[d]), last(cm_sample.axes[d])
        if lo < grid_lo || hi > grid_hi
            throw(ArgumentError(
                "cm_prior dimension $d support [$lo, $hi] extends outside the CM parameter " *
                "grid [$grid_lo, $grid_hi]; either widen the grid or narrow the prior"
            ))
        end
    end
end

# Build a callable for GlobalSensitivity.gsa that uses the SM as a fast CM proxy.
#
# The returned function f(u) accepts u ∈ [0,1]^n_cm and:
#   1. Applies ICDF: θ_CM[i] = quantile(cm_prior.distributions[i], u[i])
#   2. Interpolates SM parameter CI bounds at θ_CM using the pre-built get_bounds closure
#   3. LHS-samples within the interpolated SM parameter CI box
#   4. Evaluates the SM at each LHS draw and returns the average outputFn result
#
# This mirrors the MATLAB sampleFromSMProfiles.m logic, with nearest-neighbor replaced by
# n-linear interpolation over the CM parameter grid.
function _buildCMCallable(
    sm           :: AbstractSurrogateModel,
    uqResults    :: Vector{<:ProfileLikelihoodResult},
    cm_sample    :: AbstractCMSample,
    cm_prior     :: ParameterPrior,
    conditions   :: ConditionSpec,
    times        :: AbstractVector,
    outputFn     :: Function,
    n_sm_samples :: Int,
    rng          :: AbstractRNG,
    interp       :: AbstractCIInterpolator,
)
    n_cohorts   = length(uqResults)
    n_sm_params = length(uqResults[1].profiles)
    cond_label  = conditions[1]   # v1: first condition only

    # Pre-extract CI bounds for every cohort; fall back to fit bounds when CI is nothing.
    lb_table = Matrix{Float64}(undef, n_cohorts, n_sm_params)
    ub_table = Matrix{Float64}(undef, n_cohorts, n_sm_params)
    for (k, uq) in enumerate(uqResults)
        prior_lb = [minimum(d) for d in uq.fit_result.prior.distributions]
        prior_ub = [maximum(d) for d in uq.fit_result.prior.distributions]
        for (i, pc) in enumerate(uq.profiles)
            lb_table[k, i] = something(pc.ci_lower, prior_lb[i])
            ub_table[k, i] = something(pc.ci_upper, prior_ub[i])
        end
    end

    # Validate that the CM prior support lies within the CM parameter grid, then build
    # the bounds interpolant once; it is reused for every GSA sample point.
    _validatePriorVsGrid(cm_sample, cm_prior)
    get_bounds = _buildBoundsInterpolant(cm_sample, lb_table, ub_table, interp)

    function f(u::AbstractVector)
        # 1. ICDF: unit-cube → natural CM parameter scale
        θ_CM = [quantile(cm_prior.distributions[i], u[i]) for i in eachindex(u)]

        # 2. Interpolate SM parameter CI bounds at this CM parameter point
        lb, ub = get_bounds(θ_CM)

        # 3. LHS sample within the SM parameter CI box — result is [n_sm_params × n_sm_samples].
        # This uses a uniform distribution on [lb, ub] for each SM parameter (product measure).
        # A richer approximation would interpolate the full profile LL curve at each CM point
        # and sample from the resulting weighted distribution (as sampleSMPredictions does for
        # a single cohort). That requires interpolating entire curves across the CM grid rather
        # than just the two CI scalars, and is an open research direction.
        sm_samples = SMoReBase._sampleSMParams(lb, ub, n_sm_samples, rng)

        # 4. Evaluate SM and accumulate outputFn across samples, then average
        out_sum = outputFn(SMoReBase._evaluate(sm, times, sm_samples[:, 1], cond_label))
        for s in 2:n_sm_samples
            out_sum = out_sum .+ outputFn(SMoReBase._evaluate(sm, times, sm_samples[:, s], cond_label))
        end

        return out_sum ./ n_sm_samples
    end

    return f
end
