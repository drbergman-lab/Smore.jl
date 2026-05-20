module SMoReGloS

using Distributions
using GlobalSensitivity
using Interpolations
using Random
using SMoReBase

include("sensitivity/methods.jl")
include("sensitivity/results.jl")
include("sensitivity/cm_sample.jl")
include("sensitivity/interp.jl")
include("sensitivity/sampling.jl")
include("sensitivity/efast.jl")
include("sensitivity/morris.jl")
include("sensitivity/sensitivity.jl")

export runSensitivity
export EFAST
export SensitivityResult, sensitivity_S1, sensitivity_ST
export GridCMSample, ScatteredCMSample
export LinearCIInterp, RBFCIInterp

# Re-export Morris so users don't need `using GlobalSensitivity` just to name a method.
using GlobalSensitivity: Morris
export Morris

end
