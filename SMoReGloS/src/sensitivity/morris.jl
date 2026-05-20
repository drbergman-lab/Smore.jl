function _runSensitivity(f, n_cm::Int, method::GlobalSensitivity.Morris)
    unit_bounds = [[0.0, 1.0] for _ in 1:n_cm]
    return GlobalSensitivity.gsa(f, method, unit_bounds)
end
