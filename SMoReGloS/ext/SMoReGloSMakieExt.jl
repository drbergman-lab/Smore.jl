module SMoReGloSMakieExt

using SMoReGloS
using SMoReBase
using Makie

# ── SensitivityResult ─────────────────────────────────────────────────────────

"""
    Makie.plot(r::SensitivityResult; show_ST=true) -> Figure

Grouped bar chart of global sensitivity indices.

X-axis: CM parameter names. One bar group per CM parameter, with S1 (first-order)
bars for each output variable. When total-order indices are available (EFAST) and
`show_ST=true`, ST bars are interleaved alongside S1 bars at reduced opacity.

For each output `v`, S1 occupies dodge group `2v-1` and ST occupies dodge group
`2v`. With ST disabled or absent, output `v` occupies dodge group `v`.

# Keywords
- `show_ST::Bool = true` — whether to overlay ST bars when available

# Example
```julia
using CairoMakie, SMoReGloS
fig = Makie.plot(sens_result)
fig = Makie.plot(sens_result; show_ST=false)
```
"""
function Makie.plot(r::SensitivityResult; show_ST = true, kwargs...)
    S1 = sensitivity_S1(r)
    ST = sensitivity_ST(r)

    n_out, n_cm = size(S1)
    param_names = r.cm_parameter_names
    output_lbls = r.output_labels
    multi_out   = n_out > 1

    include_ST = show_ST && !isnothing(ST)
    n_groups   = include_ST ? 2 * n_out : n_out

    fig = Figure()
    ax  = Axis(fig[1, 1];
        xlabel = "CM Parameter",
        ylabel = "Sensitivity index",
        xticks = (1:n_cm, param_names),
    )

    for v in 1:n_out
        s1_dodge = include_ST ? 2v - 1 : v
        s1_lbl   = multi_out ? "S1: $(output_lbls[v])" : "S1"
        barplot!(ax, 1:n_cm, S1[v, :];
            dodge   = fill(s1_dodge, n_cm),
            n_dodge = n_groups,
            label   = s1_lbl)

        if include_ST
            st_lbl = multi_out ? "ST: $(output_lbls[v])" : "ST"
            barplot!(ax, 1:n_cm, ST[v, :];
                dodge   = fill(2v, n_cm),
                n_dodge = n_groups,
                alpha   = 0.45,
                label   = st_lbl)
        end
    end

    Legend(fig[1, 2], ax)
    return fig
end

end # module
