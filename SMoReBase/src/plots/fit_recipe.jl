"""
    SMFitPlot

Plot wrapper for visualizing a surrogate model fit overlaid on CM data.

Construct with `SMFitPlot(sm, data, fit_result)` and pass to `plot()`.

One subplot is produced per output variable. Each subplot overlays the SM fit
line on the CM data scatter ± pointwise σ error bars.

# Plot attributes
- `param_set_index::Int = 1` — which param set to display
- `condition_index::Int = 1` — which condition to display

# Example
```julia
using Plots
plot(SMFitPlot(sm, data, fit_result))
plot(SMFitPlot(sm, data, fit_result); param_set_index=2)
```
"""
struct SMFitPlot{SM<:AbstractSurrogateModel, D<:AbstractCMData, R<:SMFitResult}
    sm     :: SM
    data   :: D
    result :: R
end

# ── SMFitPlot recipe ──────────────────────────────────────────────────────────

@recipe function f(fp::SMFitPlot)
    sm     = fp.sm
    data   = fp.data
    result = fp.result

    ps = pop!(plotattributes, :param_set_index, 1)
    ci = pop!(plotattributes, :condition_index,  1)

    n_v    = n_variables(data)
    times  = data.times
    t_axis = isnothing(times) ? collect(1:size(data.μ, 1)) : times
    x_lbl  = isnothing(times) ? "Index" : "Time"

    layout := (1, n_v)

    cond_label = data.condition_labels[ci]
    p_fitted   = result.parameters[ps, :]
    ŷ          = _evaluate(sm, t_axis, p_fitted, cond_label)  # [n_t × n_v]

    for v in 1:n_v
        @series begin
            subplot    := v
            seriestype := :path
            label      := "SM fit"
            linewidth  := 2
            title      := data.variable_labels[v]
            xlabel     := x_lbl
            ylabel     := "Value"
            t_axis, ŷ[:, v]
        end

        @series begin
            subplot    := v
            seriestype := :scatter
            label      := "CM data"
            yerror     := data.σ[:, v, ci, ps]
            title      := data.variable_labels[v]
            xlabel     := x_lbl
            ylabel     := "Value"
            t_axis, data.μ[:, v, ci, ps]
        end
    end
end

# ── SMFitResult diagnostic recipe ─────────────────────────────────────────────

"""
    plot(result::SMFitResult)

Diagnostic scatter of fitted SM parameter values across all param sets.

One subplot per SM parameter. X-axis: param set index (1…n_param_sets);
Y-axis: fitted parameter value. Points are colored by convergence status:
- Blue (`#0072B2`) — converged
- Orange (`#D55E00`) — not converged

Legend labels are shown in the first subplot only to avoid repetition.

# Example
```julia
using Plots
plot(fit_result)
```
"""
@recipe function f(r::SMFitResult)
    n_ps, n_p   = size(r.parameters)
    param_names = r.prior.names

    layout := (1, n_p)

    idx_conv    = findall(r.converged)
    idx_notconv = findall(.!r.converged)

    for p_idx in 1:n_p
        if !isempty(idx_conv)
            @series begin
                subplot           := p_idx
                seriestype        := :scatter
                title             := param_names[p_idx]
                xlabel            := "Param set"
                ylabel            := "Fitted value"
                label             := p_idx == 1 ? "Converged" : ""
                markercolor       := "#0072B2"
                markerstrokecolor := "#0072B2"
                idx_conv, r.parameters[idx_conv, p_idx]
            end
        end

        if !isempty(idx_notconv)
            @series begin
                subplot           := p_idx
                seriestype        := :scatter
                title             := param_names[p_idx]
                xlabel            := "Param set"
                ylabel            := "Fitted value"
                label             := p_idx == 1 ? "Not converged" : ""
                markercolor       := "#D55E00"
                markerstrokecolor := "#D55E00"
                idx_notconv, r.parameters[idx_notconv, p_idx]
            end
        end
    end
end
