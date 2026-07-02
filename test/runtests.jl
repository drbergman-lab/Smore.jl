using Smore
using Test

@testset "Smore" begin
    @test Smore isa Module
    @test isdefined(Smore, :SmoreBase)
    @test isdefined(Smore, :SmoreFit)
    @test isdefined(Smore, :SmoreGSA)
end
