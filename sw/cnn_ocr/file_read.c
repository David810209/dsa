// =============================================================================
//  Program : file_read.c
//  Author  : Chun-Jen Tsai
//  Date    : Dec/06/2023
// -----------------------------------------------------------------------------
//  Description:
//      This is a library of file reading functions for MNIST test
//  images & labels. It also contains a function for reading the model
//  weights file of a neural network.
//
//  This program is designed as one of the homework projects for the course:
//  Microprocessor Systems: Principles and Implementation
//  Dept. of CS, NYCU (aka NCTU), Hsinchu, Taiwan.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  None.
// =============================================================================

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

#include "fat32.h"
#include "file_read.h"
#include "config.h"

// Our FAT32 file I/O routine need a large buffer area to read in
// the entire file before processing. the Arty board has 256MB DRAM.
uint8_t *fbuf  = (uint8_t *) 0x81000000L;

float_t **read_images(char *filename, int *n_images, int *n_rows, int *n_cols, int padding)
{
    uint8_t *iptr;
    float_t **images;
    int idx, jdx, size, row, col;

    read_file(filename, fbuf);
    iptr = fbuf;
    iptr += sizeof(int); // skip the ID of the file.

    *n_images = big2little32(iptr);
    iptr += sizeof(int);
    // printf("#images = %d\n", *n_images);

    *n_rows = big2little32(iptr) + padding*2;
    iptr += sizeof(int);
    // printf("#rows = %d\n", *n_rows);

    *n_cols = big2little32(iptr) + padding*2;
    iptr += sizeof(int);
    // printf("#cols = %d\n", *n_cols);
    size = (*n_rows) * (*n_cols);

    images = (float_t **) malloc(sizeof(float_t *) * *n_images);
    for (idx = 0; idx < *n_images; idx++)
    {
        images[idx] = (float_t *) calloc(size, sizeof(float_t));

        /* Convert the image pixels to PyTorch's input tensor format */
        for (row = padding; row < *n_rows-padding; row++)
        {
		    for (col = padding; col < *n_cols-padding; col++)
		    {
	            images[idx][row * (*n_cols) + col] = (float_t) *(iptr++)/255.0;
	        }
        }

        /* Normalize the pixels by PyTorch's transforms.Normalize(mean, std) rule */
        for (jdx = 0; jdx < size; jdx++)
        {
            images[idx][jdx] = (images[idx][jdx] - 0.1307) / 0.3081;
        }
    }

    return images;
}

uint8_t *read_labels(char *filename)
{
    uint8_t *labels;
    int n_labels;

    n_labels = read_file(filename, fbuf) - 8;
    if ((labels = (uint8_t *) malloc(n_labels)) == NULL)
    {
        printf("read_labels: out of memory.\n");
        exit (-1);        
    }
    memcpy((void *) labels, (void *) (fbuf+8), n_labels);
    
    return labels;
}

// void quantize_weights(float *weights, int8_t *q_weights, int num_weights, float scale)
// {
//     for (int i = 0; i < num_weights; i++)
//     {
//         q_weights[i] = (int8_t)roundf(weights[i] / scale);
//         if (q_weights[i] > 127) q_weights[i] = 127;       // 上限截斷
//         if (q_weights[i] < -128) q_weights[i] = -128;     // 下限截斷
//     }
// }

// // 計算 L2 範數誤差和 MSE
// void compute_quantization_error(float *weights, int8_t *q_weights, int num_weights, float scale)
// {
//     float l2_error = 0.0f, mse = 0.0f;
//     float mae = 0.0f;
//     for (int i = 0; i < num_weights; i++)
//     {
//         float restored = q_weights[i] * scale; // 還原到浮點數
//         float diff = weights[i] - restored;    // 計算誤差
//         l2_error += diff * diff;
//         mae += fabsf(diff);
//         mse += diff * diff;
//     }
//     l2_error = sqrtf(l2_error);
//     mse /= num_weights;
//     mae /= num_weights;

//     printf("L2 Error: %f\n", l2_error);
//     printf("MSE: %f\n", mse);
//     printf("MAE: %f\n", mae);
// }

float_t *read_weights(char *filename)
{
    int size;
    float_t *weights;

    // 讀取檔案並取得總 byte 數
    size = read_file(filename, fbuf);
    // int num_weights = size / sizeof(float_t); // 計算浮點數的個數

    if ((weights = (float_t *)tcm_malloc(size)) == NULL)
    {
        printf("read_weights(): Out of memory.\n");
        exit(1);
    }
    // printf("read_weights(): size = %d bytes, num_weights = %d\n", size, num_weights);
    memcpy((void *)weights, (void *)fbuf, size);

    // 計算量化比例 (scale)
    // float max_val = 0.0f;
    // for (int i = 0; i < num_weights; i++)
    // {
    //     if (fabsf(weights[i]) > max_val)
    //         max_val = fabsf(weights[i]);
    // }
    // float scale = max_val / 127.0f;

    // // 分配記憶體並量化權重
    // int8_t *q_weights = (int8_t *)malloc(num_weights * sizeof(int8_t));
    // if (!q_weights)
    // {
    //     printf("Failed to allocate memory for quantized weights.\n");
    //     free(weights);
    //     exit(1);
    // }

    // quantize_weights(weights, q_weights, num_weights, scale);

    // // 計算量化誤差
    // compute_quantization_error(weights, q_weights, num_weights, scale);
    // printf("Quantization Scale: %f\n", scale);

    // // 清理記憶體
    // free(q_weights);
    return weights;
}

/*
read_weights(): size = 30560 bytes, num_weights = 7640
L2 Error: 8.580088
MSE: 0.009636
MAE: 0.052817
Quantization Scale: 0.006118
*/