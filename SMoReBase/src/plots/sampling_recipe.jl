# ── SampledPredictions recipe ─────────────────────────────────────────────────

"""
    plot(sp::SampledPredictions)

Prediction uncertainty bands from SM parameter sampling.

One subplot per output variable. Each subplot shows a quantile ribbon spanning
the `band_quantile` central fraction of samples (default: 0.9 → 5th–95th
percentile), with the median trajectory plotted on top.

`sp.times` must be non-`nothing`; `sampleSMPredictions` populates this field
automatically.

# Plot attributes
- `band_quantile::Float64 = 0.9` — ribbon width as a central probability mass
  (e.g., 0.8 → 10th–90th percentile, 0.95 → 2.5th–97.5th percentile)

# Example
```julia
using Plots
samples = sampleSMPredictions(sm, uq_result; nSamples=200)
plot(samples)
plot(samples; band_quantile=0.8)
```
"""
@recipe function f(sp::SampledPredictions)
    isnothing(sp.times) && error(
        "SampledPredictions has no stored times; cannot plot without a time axis. " *
        "Ensure `sampleSMPredictions` was called with a `ProfileLikelihoodResult` that has `times` set."
    )

    bq   = pop!(plotattributes, :band_quantile, 0.9)
    α_lo = (1 - bq) / 2
    α_hi = 1 - α_lo

    times            = sp.times
    n_t, n_out, n_s  = size(sp.predictions)

    layout := (1, n_out)

    for v in 1:n_out
        preds_v = sp.predictions[:, v, :]   # [n_t × n_s]

        lo  = [quantile(view(preds_v, ti, :), α_lo) for ti in 1:n_t]
        hi  = [quantile(view(preds_v, ti, :), α_hi) for ti in 1:n_t]
        med = [median(view(preds_v, ti, :))          for ti in 1:n_t]

        band_pct = Int(round(bq * 100))

        @series begin
            subplot    := v
            seriestype := :path
            ribbon     := (med .- lo, hi .- med)
            fillalpha  := 0.3
            linewidth  := 2
            label      := "$(band_pct)% band"
            xlabel     := "Time"
            ylabel     := "Value"
            times, med
        end
    end
end
