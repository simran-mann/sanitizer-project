// binary_search.c  –  many binary searches on a sorted array
//
// Each search iterates  mid = arr[lo + (hi-lo)/2]  — always the same base
// SSA pointer.  The redundant-check pass will keep one dominating check per
// call frame and remove all dominated repeats within the search loop.

#include <stdio.h>
#include <stdlib.h>

#define ARR_SIZE 100000
#define QUERIES  2000000

static int arr[ARR_SIZE];

static int bsearch_impl(const int *a, int n, int target) {
    int lo = 0, hi = n - 1;
    while (lo <= hi) {
        int mid = lo + (hi - lo) / 2;
        if      (a[mid] == target) return mid;
        else if (a[mid] <  target) lo = mid + 1;
        else                       hi = mid - 1;
    }
    return -1;
}

int main(void) {
    // Build sorted array of multiples of 3.
    for (int i = 0; i < ARR_SIZE; i++)
        arr[i] = i * 3;

    long long found = 0;
    for (int q = 0; q < QUERIES; q++) {
        // Cycle through targets; some will be present, some absent.
        int target = (q * 7919) % (ARR_SIZE * 3 + 1);
        if (bsearch_impl(arr, ARR_SIZE, target) >= 0)
            found++;
    }

    printf("queries=%d  found=%lld  (~%.1f%%)\n",
           QUERIES, found, 100.0 * (double)found / QUERIES);
    return 0;
}
