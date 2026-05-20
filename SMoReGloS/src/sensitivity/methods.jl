"""
    EFAST(; n_samples, num_harmonics=4)

Extended Fourier Amplitude Sensitivity Test (eFAST).

Wraps `GlobalSensitivity.eFAST` and adds `n_samples`, which is a required argument to
`GlobalSensitivity.gsa` for eFAST but is not a field on `GlobalSensitivity.eFAST` itself.

# Keyword Arguments
- `n_samples` — number of frequency-domain samples per parameter (required; no sensible default)
- `num_harmonics` — number of harmonics for frequency analysis (default: 4); matches the
  corresponding field of `GlobalSensitivity.eFAST`
"""
struct EFAST <: GlobalSensitivity.GSAMethod
    n_samples     :: Int
    num_harmonics :: Int
end
EFAST(; n_samples::Int, num_harmonics::Int = 4) = EFAST(n_samples, num_harmonics)
