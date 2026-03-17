// quicksort.c  –  recursive quicksort on a large integer array
//
// The partition function swaps arr[i] and arr[j] via temporary reads and
// writes to the same array pointer.  Each recursive call re-checks the
// same base SSA value, so the redundant-check pass can remove the dominated
// duplicates.

#include <stdio.h>
#include <stdlib.h>

#define N (1 << 20)   // 1 M elements

static int arr[N];

static inline void swap(int *a, int *b) {
    int t = *a;
    *a    = *b;
    *b    = t;
}

static int partition(int *a, int lo, int hi) {
    int pivot = a[hi];
    int i     = lo - 1;
    for (int j = lo; j < hi; j++) {
        if (a[j] <= pivot) {
            i++;
            swap(&a[i], &a[j]);
        }
    }
    swap(&a[i + 1], &a[hi]);
    return i + 1;
}

static void qsort_r_impl(int *a, int lo, int hi) {
    if (lo >= hi) return;

    // Median-of-three pivot selection reduces worst-case depth.
    int mid = lo + (hi - lo) / 2;
    if (a[mid] < a[lo])  swap(&a[lo],  &a[mid]);
    if (a[hi]  < a[lo])  swap(&a[lo],  &a[hi]);
    if (a[mid] < a[hi])  swap(&a[mid], &a[hi]);

    int p = partition(a, lo, hi);
    qsort_r_impl(a, lo,     p - 1);
    qsort_r_impl(a, p + 1,  hi);
}

int main(void) {
    // Initialise with a fixed-seed pseudo-random sequence.
    unsigned state = 42;
    for (int i = 0; i < N; i++) {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        arr[i] = (int)(state & 0x7FFFFFFF);
    }

    qsort_r_impl(arr, 0, N - 1);

    // Verify sorted (optional; comment out for pure timing).
    int ok = 1;
    for (int i = 1; i < N; i++)
        if (arr[i] < arr[i - 1]) { ok = 0; break; }

    printf("sorted=%s  arr[0]=%d  arr[N-1]=%d\n",
           ok ? "yes" : "NO", arr[0], arr[N - 1]);
    return 0;
}
