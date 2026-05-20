"""
    AbstractCMSample

Abstract type representing a set of CM parameter points at which SM UQ results are known.

Concrete subtypes encode the spatial structure of the points (regular grid, scattered, etc.)
and drive dispatch in `_buildBoundsInterpolant`.
"""
abstract type AbstractCMSample end

"""
    GridCMSample(params)

CM parameter points on a regular grid (rows = Cartesian product of per-dimension values).

# Arguments
- `params` — `[n_cohorts × n_cm_params]` matrix; rows must form the Cartesian product of
  unique sorted values in each column

# Fields
- `params` — raw matrix `[n_cohorts × n_cm_params]`
- `axes`   — `axes[d]` holds the sorted unique values along CM dimension `d`

Throws `ArgumentError` if the rows are not consistent with a Cartesian product structure.

# Example
```julia
# 1-D grid over a single CM parameter
cm_sample = GridCMSample([1.0; 2.0; 3.0; 4.0; 5.0;;])

# 2-D grid over two CM parameters (4 cohorts)
cm_sample = GridCMSample([1.0 0.1; 1.0 0.2; 2.0 0.1; 2.0 0.2])
```
"""
struct GridCMSample <: AbstractCMSample
    params :: Matrix{Float64}
    axes   :: Vector{Vector{Float64}}
end

function GridCMSample(params::AbstractMatrix)
    mat  = Matrix{Float64}(params)
    axes = [sort(unique(c)) for c in eachcol(mat)]
    n_rows = size(mat, 1)
    n_rows == prod(length.(axes)) || throw(ArgumentError(
        "GridCMSample: expected $(prod(length.(axes))) rows (Cartesian product of " *
        "per-dimension unique values) but got $n_rows"
    ))
    length(Set(Tuple(r) for r in eachrow(mat))) == n_rows || throw(ArgumentError(
        "GridCMSample: rows are not unique — not a valid Cartesian product grid"
    ))
    return GridCMSample(mat, axes)
end

"""
    ScatteredCMSample(params)

CM parameter points at arbitrary (non-grid) locations.

# Arguments
- `params` — `[n_cohorts × n_cm_params]` matrix

# Note
Interpolation support for scattered layouts is not yet implemented. When implementing,
consider adding a `kdtree::KDTree` field (from `NearestNeighbors.jl`) built in the
constructor to avoid rebuilding per call for local methods (IDW, local RBF with k-nearest).
"""
struct ScatteredCMSample <: AbstractCMSample
    params :: Matrix{Float64}
end

ScatteredCMSample(params::AbstractMatrix) = ScatteredCMSample(Matrix{Float64}(params))
