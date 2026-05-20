function _runSensitivity(f, n_cm::Int, method::EFAST)
    unit_bounds = [[0.0, 1.0] for _ in 1:n_cm]
    gs_method   = GlobalSensitivity.eFAST(num_harmonics = method.num_harmonics)
    return GlobalSensitivity.gsa(f, gs_method, unit_bounds; samples = method.n_samples)
end
