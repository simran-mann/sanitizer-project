// array_sum.c  –  multiple sequential passes over a large integer array
//
// Each pass performs  sum += arr[i],  producing a fresh load each iteration.
// With multiple named passes accessing the same base pointer 'arr', the
// redundant-check pass can eliminate all but the first dominating check
// per SSA base value.

#include <stdio.h>
#include <stdlib.h>

#define N      (1 << 22)   // ~4 M elements  (~16 MB)
#define PASSES 8

static int arr[N];

int main(void) {
    // Initialise array.
    for (int i = 0; i < N; i++)
        arr[i] = (i * 2654435761u) & 0xFFFF;  // pseudo-random 16-bit values

    long long sum = 0;

    // PASSES sequential sweeps — lots of repeated base-pointer accesses.
    for (int p = 0; p < PASSES; p++)
        for (int i = 0; i < N; i++)
            sum += arr[i];

    // Prefix-sum pass (read-modify-write pattern).
    for (int i = 1; i < N; i++)
        arr[i] += arr[i - 1];

    // Dot-product with itself.
    long long dot = 0;
    for (int i = 0; i < N; i++)
        dot += (long long)arr[i] * arr[i];

    printf("sum=%lld  dot=%lld  arr[N-1]=%d\n", sum, dot, arr[N - 1]);
    return 0;
}
