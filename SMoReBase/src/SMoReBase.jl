module SMoReBase

using Distributions
using LinearAlgebra
using Optimization
using OptimizationOptimJL
using QuasiMonteCarlo
using Random
using Statistics

# Types
include("types/cm_data.jl")
include("types/surrogate_model.jl")
include("types/conditions.jl")
include("types/loss.jl")
include("types/results.jl")

# Fitting
include("fitting/objective.jl")
include("fitting/parallel.jl")
include("fitting/fitting.jl")

# Uncertainty quantification
include("profile/ci.jl")
include("profile/profile.jl")

# Exports — types
export AbstractCMData, CMData
export AbstractSurrogateModel, ODESurrogateModel, AnalyticalSurrogateModel
export ConditionSpec, ParameterBounds
export AbstractLoss, GaussianNLL, CustomLoss
export AbstractUQMethod, ProfileLikelihood
export SMFitResult, SMUQResult, ProfileLikelihoodResult, ProfileCurve

# Exports — public API
export fitSurrogate

end
