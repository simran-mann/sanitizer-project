// convolution.c  –  2-D image convolution with a 5×5 kernel
//
// The innermost double loop accesses  image[i+ki-HALF][j+kj-HALF]  and
// kernel[ki][kj].  For a fixed (i, j), the base SSA pointers for `image`
// and `kernel` are the same on every (ki, kj) iteration, so the
// redundant-check pass can remove the dominated duplicates.

#include <stdio.h>
#include <string.h>
#include <math.h>

#define IMG_H     512
#define IMG_W     512
#define KERN_SIZE 5
#define HALF      (KERN_SIZE / 2)

static float image[IMG_H][IMG_W];
static float kernel[KERN_SIZE][KERN_SIZE];
static float output[IMG_H][IMG_W];

int main(void) {
    // ── Initialise image with a simple gradient ───────────────────────────────
    for (int i = 0; i < IMG_H; i++)
        for (int j = 0; j < IMG_W; j++)
            image[i][j] = (float)(i * IMG_W + j) / (float)(IMG_H * IMG_W);

    // ── Build a normalised Gaussian-like kernel ───────────────────────────────
    float ksum = 0.0f;
    for (int ki = 0; ki < KERN_SIZE; ki++)
        for (int kj = 0; kj < KERN_SIZE; kj++) {
            int di = ki - HALF, dj = kj - HALF;
            kernel[ki][kj] = 1.0f / (1.0f + (float)(di * di + dj * dj));
            ksum += kernel[ki][kj];
        }
    for (int ki = 0; ki < KERN_SIZE; ki++)
        for (int kj = 0; kj < KERN_SIZE; kj++)
            kernel[ki][kj] /= ksum;

    memset(output, 0, sizeof output);

    // ── 2-D convolution (valid region only) ──────────────────────────────────
    for (int i = HALF; i < IMG_H - HALF; i++)
        for (int j = HALF; j < IMG_W - HALF; j++)
            for (int ki = 0; ki < KERN_SIZE; ki++)
                for (int kj = 0; kj < KERN_SIZE; kj++)
                    output[i][j] +=
                        image[i + ki - HALF][j + kj - HALF] * kernel[ki][kj];

    printf("output[%d][%d] = %.6f\n",
           IMG_H / 2, IMG_W / 2, output[IMG_H / 2][IMG_W / 2]);
    return 0;
}
