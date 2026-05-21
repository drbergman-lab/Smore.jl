using Smore
using Test
import Pkg

@testset "Smore" begin
    @test Smore isa Module
    @test isdefined(Smore, :SmoreBase)
    @test isdefined(Smore, :SmoreFit)
    @test isdefined(Smore, :SmoreGSA)
end

for name in ["SmoreBase", "SmoreFit", "SmoreGSA"]
    Pkg.test(name)
end
