# ── SensitivityResult recipe ──────────────────────────────────────────────────

"""
    plot(result::SensitivityResult)

Grouped bar chart of global sensitivity indices.

X-axis: CM parameter names. One bar series per output variable for first-order
indices (S1). When total-order indices are available (`EFAST`) and `show_ST` is
`true` (default), ST bars are added alongside S1 bars with reduced opacity.

# Plot attributes
- `show_ST::Bool = true` — whether to overlay ST bars when they are available

# Example
```julia
using Plots
plot(sens_result)
plot(sens_result; show_ST=false)   # S1 only
```
"""
@recipe function f(r::SensitivityResult)
    S1 = sensitivity_S1(r)   # [n_outputs × n_cm_params]
    ST = sensitivity_ST(r)   # [n_outputs × n_cm_params] or nothing

    show_ST = pop!(plotattributes, :show_ST, true)

    n_out, n_cm  = size(S1)
    param_names  = r.cm_parameter_names
    output_lbls  = r.output_labels

    seriestype := :bar
    xticks     := (1:n_cm, param_names)
    xlabel     := "CM Parameter"
    ylabel     := "Sensitivity index"
    legend     := :outertopright

    multi_out = n_out > 1

    if !isnothing(ST) && show_ST
        for v in 1:n_out
            s1_lbl = multi_out ? "S1: $(output_lbls[v])" : "S1"
            st_lbl = multi_out ? "ST: $(output_lbls[v])" : "ST"

            @series begin
                label := s1_lbl
                S1[v, :]
            end

            @series begin
                label     := st_lbl
                fillalpha := 0.45
                ST[v, :]
            end
        end
    else
        for v in 1:n_out
            @series begin
                label := multi_out ? output_lbls[v] : "S1"
                S1[v, :]
            end
        end
    end
end
