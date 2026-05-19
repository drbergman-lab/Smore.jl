module SMoReBaseOrdinaryDiffEqExt

using SMoReBase
using OrdinaryDiffEq

# Override the stub that errors without the extension loaded.
function SMoReBase._evaluate(sm::SMoReBase.ODESurrogateModel, t, p, condition)
    y0 = sm.y0

    if sm.custom_solve_fn !== nothing
        result = sm.custom_solve_fn(sm, t, p, condition, y0)
        return SMoReBase._applyPostprocessor(sm, result)
    end

    tspan = (Float64(t[1]), Float64(t[end]))
    prob  = ODEProblem(sm.ode_fn, y0, tspan, p)
    sol   = solve(prob, sm.solver;
                  abstol  = sm.abstol,
                  reltol  = sm.reltol,
                  saveat  = t)

    # Build [n_times × n_outputs] matrix
    state_mat = reduce(hcat, sol.u)'  # [n_times × n_states]

    result = if sm.output_variables !== nothing
        state_mat[:, sm.output_variables]
    else
        state_mat
    end

    return SMoReBase._applyPostprocessor(sm, result)
end

end # module
