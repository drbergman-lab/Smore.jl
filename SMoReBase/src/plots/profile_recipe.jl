# ── ProfileLikelihoodResult recipe ────────────────────────────────────────────

"""
    plot(result::ProfileLikelihoodResult)

Profile likelihood curves for all SM parameters.

Produces one subplot per profiled parameter by delegating to the `ProfileCurve`
recipe. Each panel shows the profile log-likelihood, the Wilks CI threshold
(dashed), the MLE (solid vertical line), and the CI bounds (dotted vertical
lines, omitted when `nothing`).

# Example
```julia
using Plots
plot(uq_result)
```
"""
@recipe function f(r::ProfileLikelihoodResult)
    n_p = length(r.profiles)
    layout := (1, n_p)

    for (i, pc) in enumerate(r.profiles)
        @series begin
            subplot := i
            pc
        end
    end
end

# ── ProfileCurve recipe ────────────────────────────────────────────────────────

"""
    plot(curve::ProfileCurve)

Single profile likelihood panel for one SM parameter.

Shows the profile log-likelihood curve, a dashed horizontal line at the Wilks
CI threshold, a solid vertical line at the MLE, and dotted vertical lines at the
CI bounds (omitted if `ci_lower` or `ci_upper` is `nothing`).

# Example
```julia
using Plots
plot(uq_result.profiles[1])
```
"""
@recipe function f(pc::ProfileCurve)
    mle_idx = argmax(pc.log_likelihoods)
    mle_val = pc.profile_values[mle_idx]

    title  := pc.parameter_name
    xlabel := pc.parameter_name
    ylabel := "Log-likelihood"

    # Profile LL curve
    @series begin
        seriestype := :path
        linewidth  := 2
        label      := "Profile LL"
        pc.profile_values, pc.log_likelihoods
    end

    # CI threshold — dashed horizontal line
    @series begin
        seriestype := :hline
        linestyle  := :dash
        linecolor  := :gray
        linewidth  := 1.5
        label      := "CI threshold"
        [pc.threshold]
    end

    # MLE — solid vertical line
    @series begin
        seriestype := :vline
        linestyle  := :solid
        linecolor  := :black
        linewidth  := 1.5
        label      := "MLE"
        [mle_val]
    end

    # CI lower bound — dotted vertical line (labeled "95% CI" or similar)
    if !isnothing(pc.ci_lower)
        @series begin
            seriestype := :vline
            linestyle  := :dot
            linecolor  := :red
            linewidth  := 1.5
            label      := "CI"
            [pc.ci_lower]
        end
    end

    # CI upper bound — same style, no duplicate legend label
    if !isnothing(pc.ci_upper)
        @series begin
            seriestype := :vline
            linestyle  := :dot
            linecolor  := :red
            linewidth  := 1.5
            label      := ""
            [pc.ci_upper]
        end
    end
end
