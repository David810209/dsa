#include <stdio.h>

int main() {
    // 4x4x3 input data (flattened for simplicity)
    float data[48] = {
        // Channel 0
        1.0, 2.0, 3.0, 4.0,
        5.0, 6.0, 7.0, 8.0,
        9.0, 10.0, 11.0, 12.0,
        13.0, 14.0, 15.0, 16.0,
        // Channel 1
        0.5, 0.75, 1.0, 1.125,
        1.25, 1.375, 1.5, 1.625,
        1.75, 1.875, 2.0, 2.125,
        2.25, 2.375, 2.5, 2.625,
        // Channel 2
        3.0, 4.0, 5.0, 6.0,
        7.0, 8.0, 9.0, 10.0,
        11.0, 12.0, 13.0, 14.0,
        15.0, 16.0, 18.0, 20.0
    };

    int in_width = 4;
    int in_height = 4;
    int channels = 3;
    int pool_size = 2;
    int out_width = in_width / pool_size;
    int out_height = in_height / pool_size;

    // Output data array
    float pooled_data[3][2][2] = {0};

    // Perform average pooling
    for (int c = 0; c < channels; c++) {
        for (int i = 0; i < out_height; i++) {
            for (int j = 0; j < out_width; j++) {
                float sum = 0.0;
                for (int x = 0; x < pool_size; x++) {
                    for (int y = 0; y < pool_size; y++) {
                        int in_row = i * pool_size + x;
                        int in_col = j * pool_size + y;
                        sum += data[c * in_width * in_height + in_row * in_width + in_col];
                    }
                }
                pooled_data[c][i][j] = sum / (pool_size * pool_size);
            }
        }
    }

    // Print the pooled results
    for (int c = 0; c < channels; c++) {
        printf("Channel %d:\n", c);
        for (int i = 0; i < out_height; i++) {
            for (int j = 0; j < out_width; j++) {
                printf("%.6f ", pooled_data[c][i][j]);
            }
            printf("\n");
        }
        printf("\n");
    }

    return 0;
}