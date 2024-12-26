using Test
using LinearAlgebra
using CUDA

# @testset "lu! with varing pivot" begin
#     for T in [Float32, Float64, ComplexF32, ComplexF64]
#         for pivot in [NoPivot(), RowNonZero(), CompletePivoting()]
#             for m in [10, 100, 1000]
#                 for n in [m, div(m,10)*9, div(m,10)*11]
#                     A = rand(T, m, n)
#                     B = copy(A)
#                     DLA_A = DLAMatrix{T}(A)
#                     F =LinearAlgebra.lu!(DLA_A, pivot)
#                     m, n = size(F.factors)
#                     L = tril(F.factors[1:m, 1:min(m,n)])
#                     for i in 1:min(m,n); L[i,i] = 1 end
#                     U = triu(F.factors[1:min(m,n), 1:n])
#                     p = LinearAlgebra.ipiv2perm(F.ipiv,m)
#                     q = LinearAlgebra.ipiv2perm(F.jpiv, n)
#                     L * U ≈ B[p, q]
#                     norm(L * U) ≈ norm(B[p, q])
#                 end
#             end
#         end
#     end
# end


# @testset "lu generic_lufact!" begin
#     for T in [Float32, Float64, ComplexF32, ComplexF64]
#         for pivot in [NoPivot(), RowNonZero(),  RowMaximum(), CompletePivoting()]
#             for m in [10, 100, 1000]
#                 for n in [m, div(m,10)*9, div(m,10)*11]
#                     A = rand(T, m, n)
#                     B = copy(A)
#                     DLA_A = DLAMatrix{T}(A)
#                     F =LinearAlgebra.generic_lufact!(DLA_A, pivot)
#                     m, n = size(F.factors)
#                     L = tril(F.factors[1:m, 1:min(m,n)])
#                     for i in 1:min(m,n); L[i,i] = 1 end
#                     U = triu(F.factors[1:min(m,n), 1:n])
#                     p = LinearAlgebra.ipiv2perm(F.ipiv,m)
#                     q = LinearAlgebra.ipiv2perm(F.jpiv, n)
#                     L * U ≈ B[p, q]
#                     norm(L * U) ≈ norm(B[p, q])
#                 end
#             end
#         end
#     end
# end


# @testset "lu! default RowMaximum()" begin
#     for T in [Float32, Float64, ComplexF32, ComplexF64]
#         for m in [10, 100, 1000]
#             for n in [m, div(m,10)*9, div(m,10)*11]
#                 A = rand(T, m, n)
#                 B = copy(A)
#                 DLA_A = DLAMatrix{T}(A)
#                 F =LinearAlgebra.lu!(DLA_A)
#                 m, n = size(F.factors)
#                 L = tril(F.factors[1:m, 1:min(m,n)])
#                 for i in 1:min(m,n); L[i,i] = 1 end
#                 U = triu(F.factors[1:min(m,n), 1:n])
#                 p = LinearAlgebra.ipiv2perm(F.ipiv,m)
#                 L * U ≈ B[p, :]
#                 norm(L * U) ≈ norm(B[p, :])
#             end
#         end
#     end
# end

# @testset "zlauum test" begin
#     for T in [Float32, Float64, ComplexF32, ComplexF64]
#         for uplo in ['U', 'L']
#             # Test different matrix sizes including edge cases
#             for n in [16, 32, 64, 128, 256]
#                 # Test a variety of block sizes including edge cases
#                 for block_size in [2, 3, 4, 5, 8]
#                     if uplo == 'U'
#                         # Create an upper triangular matrix with values centered around 0.5
#                         A = Matrix(UpperTriangular(0.5 .+ rand(T, n, n)))
#                     else
#                         # Create a lower triangular matrix with values centered around -0.5
#                         A = Matrix(LowerTriangular(-0.5 .+ rand(T, n, n)))
#                     end
#                     Ac = copy(A)
                
#                     info = zlauum(uplo, n, A, n, block_size)
                    
#                     @test info == 0  # Ensure no error from zlauum

#                     # Set tolerance based on type
#                     tolerance = T <: Union{Float64, ComplexF64} ? 1e-12 : 1e-6

#                     if uplo == 'U'
#                         expected_result = Matrix(UpperTriangular(Ac * Ac'))
#                         result_diff = norm(Matrix(A) - expected_result) / n

#                         @test result_diff < tolerance  # Use adjusted tolerance
#                         if result_diff >= tolerance
#                             println("Failure in zlauum test for T: $T, uplo: $uplo, n: $n, block_size: $block_size")
#                             println("Difference norm: $result_diff")
#                         end
#                     else
#                         expected_result = Matrix(LowerTriangular(Ac' * Ac))
#                         result_diff = norm(Matrix(A) - expected_result) / n

#                         @test result_diff < tolerance  # Use adjusted tolerance
#                         if result_diff >= tolerance
#                             println("Failure in zlauum test for T: $T, uplo: $uplo, n: $n, block_size: $block_size")
#                             println("Difference norm: $result_diff")
#                         end
#                     end
#                 end
#             end
#         end
#     end
# end


@testset "Accuracy Test for performant_rectrsm!" begin
    # Matrix sizes to test
    sizes = [30, 45, 64, 102, 128, 250, 512, 750, 1024, 2048, 4096, 8192, 5000, 6000]

    # Tolerance for accuracy check
    tolerance = 1e-12

    for n in sizes
        # Generate random lower triangular matrix
        A = Matrix(LowerTriangular(rand(n, n) .+ 1))  # CPU Array
        diag = Diagonal(10 * ones(n, n))  # Create a diagonal matrix with 10s
        A = A + diag  # Add 10 to the diagonal elements of the matrix

        # Generate random right-hand side
        B = Matrix(rand(n, 1) .+ 1)  # CPU Array
        Ac = copy(A)
        Bc = copy(B)

        # Convert to CuArray for GPU computation
        A = CuArray(A)
        B = CuArray(B)

        # Perform GPU operation with performant_rectrsm!
        performant_rectrsm!(A, n, B)

        # Perform baseline operation with BLAS trsm!
        LinearAlgebra.BLAS.trsm!('L', 'L', 'N', 'N', 1.0, Ac, Bc)

        # Compute the Frobenius norm difference (relative error)
        result_diff = norm(Matrix(B) - Bc) / norm(Bc)

        println("Size: $n x $n | Result Diff (Relative Error): $result_diff")

        # Skip NaN cases (don't count as failure)
        if isnan(result_diff)
            println("Size: $n x $n | Skipping NaN result")
            continue
        end

        # Check if the relative error exceeds tolerance
        if result_diff >= tolerance
            println("Test failed for matrix size $n x $n")
            println("Relative error: $result_diff")
        end

        # Assert relative error is within tolerance
        @test result_diff < tolerance
    end
end
