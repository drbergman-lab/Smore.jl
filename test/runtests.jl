using SMoReVerse
using Test

# Run each sub-package's own test suite in a subprocess so it resolves against
# its own Project.toml rather than the meta-package environment.
const ROOT = dirname(dirname(@__FILE__))

const SUBPKGS = [
    ("SMoReBase", joinpath(ROOT, "SMoReBase")),
    ("SMoReParS",  joinpath(ROOT, "SMoReParS")),
    ("SMoReGloS",  joinpath(ROOT, "SMoReGloS")),
]

@testset "SMoReVerse" begin
    for (name, path) in SUBPKGS
        @testset "$name" begin
            cmd = `$(Base.julia_exename()) --project=$path -e "using Pkg; Pkg.test()"`
            @test success(pipeline(cmd; stdout=stdout, stderr=stderr))
        end
    end
end
