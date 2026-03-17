// knapsack.c  –  0/1 knapsack solved with bottom-up DP
//
// The DP table  dp[i][w]  is accessed row by row.  Within each row the
// inner loop reads dp[i-1][w] and dp[i-1][w-weight[i]], both via the
// same dp base pointer.  The redundant-check pass can eliminate the
// dominated duplicate check on dp within each iteration.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define N_ITEMS  600
#define CAPACITY 3000

static int weight[N_ITEMS];
static int value[N_ITEMS];

// Allocate dp on the heap to avoid a large stack frame.
static int dp[N_ITEMS + 1][CAPACITY + 1];

int main(void) {
    // Deterministic pseudo-random initialisation.
    unsigned state = 0xDEADBEEFu;
    for (int i = 0; i < N_ITEMS; i++) {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        weight[i] = (int)((state & 0x3F) + 1);  // 1..64
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        value[i]  = (int)((state & 0x7F) + 1);  // 1..128
    }

    memset(dp, 0, sizeof dp);

    for (int i = 1; i <= N_ITEMS; i++) {
        int wi = weight[i - 1];
        int vi = value[i - 1];
        for (int w = 0; w <= CAPACITY; w++) {
            dp[i][w] = dp[i - 1][w];            // don't take item i
            if (wi <= w) {
                int take = dp[i - 1][w - wi] + vi;
                if (take > dp[i][w])
                    dp[i][w] = take;             // take item i
            }
        }
    }

    printf("Max value (N=%d, cap=%d): %d\n",
           N_ITEMS, CAPACITY, dp[N_ITEMS][CAPACITY]);
    return 0;
}
