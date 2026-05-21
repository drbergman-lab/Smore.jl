using SMoReGloS
using SMoReBase
using Distributions
using RecipesBase
using Test
using Random

# ── helpers ────────────────────────────────────────────────────────────────────

# Two-parameter analytical SM: output = [a * exp(-b * t)]
_sm_fn(t, p, _cond) = reshape(p[1] .* exp.(-p[2] .* t), :, 1)
const _sm = AnalyticalSurrogateModel(fn = _sm_fn)

# Build a minimal ProfileLikelihoodResult for a given cohort.
function _make_uq(a_true, b_true; ci_frac=0.2, lb=[0.0, 0.0], ub=[5.0, 5.0])
    prior  = ParameterPrior(lb, ub; names=["a", "b"])
    params = [a_true b_true]
    fit    = SMFitResult(params, [0.0], params, prior, BitVector([true]), Any[nothing])
    pc_a   = ProfileCurve(1, "a", collect(range(lb[1], ub[1], 20)), zeros(20), zeros(20, 2),
                          a_true * (1 - ci_frac), a_true * (1 + ci_frac), -1.92, 0.0)
    pc_b   = ProfileCurve(2, "b", collect(range(lb[2], ub[2], 20)), zeros(20), zeros(20, 2),
                          b_true * (1 - ci_frac), b_true * (1 + ci_frac), -1.92, 0.0)
    return ProfileLikelihoodResult([pc_a, pc_b], fit, collect(range(0.0, 5.0, 10)))
end

const _t        = collect(range(0.0, 5.0, 10))
const _cm_vals  = [1.0; 2.0; 3.0; 4.0; 5.0;;]   # [5 × 1]
const _cm_sample = GridCMSample(_cm_vals)
const _uq_list  = [_make_uq(Float64(k), 0.5) for k in 1:5]
const _cm_prior = ParameterPrior([1.0], [5.0]; names=["cm_param_1"])

# ── EFAST ──────────────────────────────────────────────────────────────────────

@testset "EFAST" begin
    rng    = Random.MersenneTwister(42)
    result = runSensitivity(
        _sm, _uq_list, _cm_sample, _cm_prior, EFAST(n_samples=500);
        times = _t,
        rng   = rng,
    )

    @test result isa SensitivityResult
    @test result.method isa EFAST
    @test result.cm_parameter_names == ["cm_param_1"]
    @test result.output_labels == ["output_1"]

    S1 = sensitivity_S1(result)
    ST = sensitivity_ST(result)

    # Native layout: [n_outputs × n_cm_params] = [1 × 1]
    @test size(S1) == (1, 1)
    @test size(ST) == (1, 1)
    @test S1[1, 1] >= 0
    @test ST[1, 1] >= 0
end

# ── Morris ─────────────────────────────────────────────────────────────────────

@testset "Morris" begin
    rng    = Random.MersenneTwister(7)
    result = runSensitivity(
        _sm, _uq_list, _cm_sample, _cm_prior, Morris(num_trajectory=5);
        times = _t,
        rng   = rng,
    )

    @test result isa SensitivityResult
    @test result.method isa Morris
    @test sensitivity_ST(result) === nothing

    S1 = sensitivity_S1(result)
    @test size(S1) == (1, 1)
    @test S1[1, 1] >= 0
end

# ── multi-output outputFn ──────────────────────────────────────────────────────

@testset "custom outputFn" begin
    two_out_fn = pred -> [pred[1, 1], pred[end, 1]]

    rng    = Random.MersenneTwister(99)
    result = runSensitivity(
        _sm, _uq_list, _cm_sample, _cm_prior, EFAST(n_samples=500);
        times    = _t,
        outputFn = two_out_fn,
        rng      = rng,
    )

    S1 = sensitivity_S1(result)
    ST = sensitivity_ST(result)
    @test size(S1) == (2, 1)
    @test size(ST) == (2, 1)
    @test result.output_labels == ["output_1", "output_2"]
end

# ── CI fallback when bounds are nothing ────────────────────────────────────────

@testset "nothing CI fallback" begin
    function _make_uq_partial_ci(a_true, b_true)
        prior  = ParameterPrior([0.0, 0.0], [5.0, 5.0]; names=["a", "b"])
        params = [a_true b_true]
        fit    = SMFitResult(params, [0.0], params, prior, BitVector([true]), Any[nothing])
        pc_a   = ProfileCurve(1, "a", collect(range(0.0, 5.0, 20)), zeros(20), zeros(20, 2),
                              a_true * 0.8, a_true * 1.2, -1.92, 0.0)
        pc_b   = ProfileCurve(2, "b", collect(range(0.0, 5.0, 20)), zeros(20), zeros(20, 2),
                              nothing, nothing, -1.92, 0.0)
        return ProfileLikelihoodResult([pc_a, pc_b], fit, _t)
    end

    uq_partial = [_make_uq_partial_ci(Float64(k), 0.5) for k in 1:5]

    rng    = Random.MersenneTwister(11)
    result = runSensitivity(
        _sm, uq_partial, _cm_sample, _cm_prior, Morris(num_trajectory=5);
        times = _t,
        rng   = rng,
    )

    @test result isa SensitivityResult
    @test size(sensitivity_S1(result)) == (1, 1)
end

# ── nearest-neighbor exact match ───────────────────────────────────────────────

@testset "nearest-neighbor exact match" begin
    rng    = Random.MersenneTwister(0)
    result = runSensitivity(
        _sm, _uq_list, _cm_sample, _cm_prior, Morris(num_trajectory=3);
        times        = _t,
        n_sm_samples = 4,
        rng          = rng,
    )
    @test result isa SensitivityResult
    @test all(isfinite, sensitivity_S1(result))
end

# ── Plotting recipes ───────────────────────────────────────────────────────────

@testset "Plots — SensitivityResult (EFAST)" begin
    rng    = Random.MersenneTwister(42)
    result = runSensitivity(
        _sm, _uq_list, _cm_sample, _cm_prior, EFAST(n_samples=500);
        times = _t,
        rng   = rng,
    )

    # EFAST has ST: default show_ST=true → 2 series (S1 + ST) for 1 output
    rds = RecipesBase.apply_recipe(Dict{Symbol,Any}(), result)
    @test length(rds) == 2

    # show_ST=false → 1 series (S1 only)
    rds2 = RecipesBase.apply_recipe(Dict{Symbol,Any}(:show_ST => false), result)
    @test length(rds2) == 1
end

@testset "Plots — SensitivityResult (Morris)" begin
    rng    = Random.MersenneTwister(7)
    result = runSensitivity(
        _sm, _uq_list, _cm_sample, _cm_prior, Morris(num_trajectory=5);
        times = _t,
        rng   = rng,
    )

    # Morris has no ST → show_ST is irrelevant; always 1 series (S1)
    rds = RecipesBase.apply_recipe(Dict{Symbol,Any}(), result)
    @test length(rds) == 1
end

@testset "Plots — SensitivityResult (multi-output)" begin
    two_out_fn = pred -> [pred[1, 1], pred[end, 1]]
    rng        = Random.MersenneTwister(99)
    result = runSensitivity(
        _sm, _uq_list, _cm_sample, _cm_prior, EFAST(n_samples=500);
        times    = _t,
        outputFn = two_out_fn,
        rng      = rng,
    )

    # 2 outputs × (S1 + ST) = 4 series
    rds = RecipesBase.apply_recipe(Dict{Symbol,Any}(), result)
    @test length(rds) == 4
end
