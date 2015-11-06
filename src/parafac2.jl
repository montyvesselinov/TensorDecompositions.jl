immutable PARAFAC2 
    factors::Array{Matrix{Float64}, 1}
    D::Array{Matrix{Float64}, 1}
    A::Matrix{Float64}
    error::Float64

    function PARAFAC2{S<:Matrix}(X::Vector{S},
                                 F::Matrix{Float64},
                                 D::Vector{Matrix{Float64}},
                                 A::Matrix{Float64},
                                 res::Float64)

        factors = map(function (Xi, Di)
            U = svd(A_mul_Bt(F .* Di, Xi * A))
            U[3] * (U[1]'F)
        end, X, D)
        return new(factors, D, A, sqrt(res) / vecnorm(vcat(X...)))
    end

end

function parafac2{S<:Matrix}(X::Vector{S},
                             r::Integer;
                             tol::Float64=1e-5,
                             maxiter::Integer=100,
                             verbose::Bool=true)
    m = length(X)
    n = size(X[1], 2)
    for i in 2:m
        size(X[i], 2) == n || error("All input matrices should have the same number of rows.")
    end

    F = eye(r)
    D = Matrix{Float64}[ones(1, r) for _ in 1:m]
    A = eigs(sum(map(Xi -> Xi'Xi, X)), nev=r)[2]
    G = Matrix{Float64}[eye(r), eye(r), ones(r, r) * m]
    H = Matrix{Float64}[(size(X[i], 1) > size(X[i], 2) ? qr(X[i])[2]: X[i]) for i in 1:m]
    P = Array(Matrix{Float64}, m)

    niters = 0
    converged = false
    resid = vecnorm(vcat(X...))
    while !converged && niters < maxiter
        map!(function (Hi, Di)
            U = svd((F .* Di) * (Hi * A)')
            U[3]*U[1]'
        end, P, H, D)
        T = cat(3, [P[i]'H[i] for i in 1:m]...)

        B = vcat(D...)
        F = _row_unfold(T, 1) * _KhatriRao(B, A) / (G[3] .* G[2])
        At_mul_B!(G[1], F, F)
        A = _row_unfold(T, 2) * _KhatriRao(B, F) / (G[3] .* G[1])
        At_mul_B!(G[2], A, A)
        B = _row_unfold(T, 3) * _KhatriRao(A, F) / (G[2] .* G[1])
        At_mul_B!(G[3], B, B)

        D = Matrix{Float64}[B[i, :] for i in 1:m]

        resid_old = resid
        resid = sum(i -> sumabs2(H[i] - P[i] * A_mul_Bt(F .* D[i], A)), 1:m)
        converged = abs(resid - resid_old) < tol * resid_old

        niters += 1
    end

    verbose && _iter_status(converged, niters, maxiter)
    return PARAFAC2(X, F, D, A, resid)
end
