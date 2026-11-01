# Julia Differential Equation & Matrix Operations Fixture
using LinearAlgebra

function solve_system(A::Matrix{Float64}, b::Vector{Float64})::Vector{Float64}
    # Direct LU factorization solve
    x = A \ b
    residual = norm(A * x - b)
    @info "System solved" residual=residual
    return x
end

macro measure_time(ex)
    quote
        local t0 = time_ns()
        local val = $(esc(ex))
        println("Elapsed: ", (time_ns() - t0) / 1e6, " ms")
        val
    end
end
