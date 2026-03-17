// matrix_mult.c  –  O(N³) dense matrix multiplication
//
// Excellent for redundant-check elimination: the inner-loop variable
//   C[i][j] += A[i][k] * B[k][j]
// accesses A[i][k] and B[k][j] whose base pointers are loop-invariant,
// so the same SSA pointer is checked repeatedly across iterations.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define N 400

// Global arrays (static storage avoids stack overflow for large N).
static double A[N][N], B[N][N], C[N][N];

int main(void) {
    // Initialise with deterministic values.
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            A[i][j] = (double)(i + j + 1) / N;
            B[i][j] = (double)(i - j + 1) / N;
        }

    memset(C, 0, sizeof C);

    // ikj loop order (cache-friendly for row-major C arrays).
    for (int i = 0; i < N; i++)
        for (int k = 0; k < N; k++)
            for (int j = 0; j < N; j++)
                C[i][j] += A[i][k] * B[k][j];

    // Print one element to prevent the compiler from treating the whole
    // computation as dead code.
    printf("C[%d][%d] = %.6f\n", N / 2, N / 2, C[N / 2][N / 2]);
    return 0;
}
