"""
    AbstractSurrogateModel

Abstract base type for surrogate models.
"""
abstract type AbstractSurrogateModel end

"""
    ODESurrogateModel(; ode_fn, y0, solver, kwargs...)

Surrogate model backed by an ODE system (SciML convention).

Calling `_evaluate` on this type requires `using OrdinaryDiffEq` to activate
the package extension `SMoReBaseOrdinaryDiffEqExt`.

# Fields
- `ode_fn` — in-place ODE RHS: `f!(du, u, p, t)`
- `y0` — initial conditions (`Vector{Float64}`)
- `solver` — ODE algorithm (e.g., `Tsit5()`)
- `output_variables` — indices of state variables that correspond to observables (`nothing` → all)
- `pre_processor` — `Union{Nothing,Function}` applied to `(t, p, condition)` before solving
- `post_processor` — `Union{Nothing,Function}` applied to the prediction matrix after solving
- `custom_solve_fn` — if supplied, replaces the default ODE solve step entirely
- `custom_error_fn` — if supplied, replaces the default loss computation
- `abstol`, `reltol` — ODE solver tolerances

# Example
```julia
using OrdinaryDiffEq
sm = ODESurrogateModel(
    ode_fn = (du, u, p, t) -> (du[1] = p[1] * u[1] * (1 - u[1] / p[2])),
    y0     = [0.01],
    solver = Tsit5(),
)
```
"""
struct ODESurrogateModel{F,Pre,Post,Solve,Err} <: AbstractSurrogateModel
    ode_fn::F
    y0::Vector{Float64}
    solver::Any
    output_variables::Union{Nothing,Vector{Int}}
    pre_processor::Pre
    post_processor::Post
    custom_solve_fn::Solve
    custom_error_fn::Err
    abstol::Float64
    reltol::Float64
end

function ODESurrogateModel(;
    ode_fn,
    y0,
    solver,
    output_variables = nothing,
    pre_processor    = nothing,
    post_processor   = nothing,
    custom_solve_fn  = nothing,
    custom_error_fn  = nothing,
    abstol::Float64  = 1e-6,
    reltol::Float64  = 1e-3,
)
    return ODESurrogateModel(
        ode_fn, y0, solver,
        output_variables,
        pre_processor, post_processor,
        custom_solve_fn, custom_error_fn,
        abstol, reltol,
    )
end

"""
    AnalyticalSurrogateModel(; fn, kwargs...)

Surrogate model defined by a closed-form analytical function.

`fn` signature: `(t::Vector, p::Vector, condition::String) -> Matrix{Float64}`
where rows are time points and columns are output variables.

# Fields
- `fn` — analytical solution function
- `pre_processor` — `Union{Nothing,Function}` applied to `(t, p, condition)` before evaluation
- `post_processor` — `Union{Nothing,Function}` applied to the prediction matrix after evaluation
- `custom_error_fn` — if supplied, replaces the default loss computation

# Example
```julia
sm = AnalyticalSurrogateModel(
    fn = (t, p, c) -> reshape(p[2] ./ (1 .+ (p[2]/0.01 - 1) .* exp.(-p[1] .* t)), :, 1),
)
```
"""
struct AnalyticalSurrogateModel{F,Pre,Post,Err} <: AbstractSurrogateModel
    fn::F
    pre_processor::Pre
    post_processor::Post
    custom_error_fn::Err
end

function AnalyticalSurrogateModel(;
    fn,
    pre_processor   = nothing,
    post_processor  = nothing,
    custom_error_fn = nothing,
)
    return AnalyticalSurrogateModel(fn, pre_processor, post_processor, custom_error_fn)
end

# ── internal evaluation helpers ───────────────────────────────────────────────

# pre_processor signature: (p, condition) -> (p_new, condition_new)
# Common uses: log-space → linear parameter transform, condition-dependent parameter adjustments.
function _applyPreprocessor(sm, p, condition)
    isnothing(sm.pre_processor) && return (p, condition)
    return sm.pre_processor(p, condition)
end

function _applyPostprocessor(sm, result)
    isnothing(sm.post_processor) && return result
    return sm.post_processor(result)
end

"""
    _evaluate(sm, t, p, condition) -> Matrix{Float64}

Internal evaluation entry point. Returns a `[n_times × n_outputs]` matrix of SM predictions.

For `AnalyticalSurrogateModel`: calls `sm.fn(t, p, condition)`.
For `ODESurrogateModel`: requires the `OrdinaryDiffEq` extension to be loaded.
"""
function _evaluate(sm::AnalyticalSurrogateModel, t, p, condition)
    p_eff, c_eff = _applyPreprocessor(sm, p, condition)
    result = sm.fn(t, p_eff, c_eff)
    return _applyPostprocessor(sm, result)
end

# Generic fallback: catches any AbstractSurrogateModel subtype that has no _evaluate method.
# The ODE extension overrides this for ODESurrogateModel specifically.
function _evaluate(sm::AbstractSurrogateModel, args...)
    msg = "No `_evaluate` method defined for $(typeof(sm))."
    if sm isa ODESurrogateModel
        msg *= " Load OrdinaryDiffEq first (`using OrdinaryDiffEq`) to activate the ODE extension."
    end
    error(msg)
end
