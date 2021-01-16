using PokerHands
using Test

@testset "PokerHands.jl" begin
    @test chances("AhAs") > chances("KcKd")
end

