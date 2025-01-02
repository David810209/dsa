#include<stdio.h>
#include <stdlib.h>
#include <string.h>

void software_convolution(float *img, float *weight, float *out_img, 
                          int in_width, int out_width, int weight_width, 
                          int in_depth, int out_depth) {
    // 初始化輸出圖片為0
    for (int o = 0; o < out_depth; ++o) {
        for (int y = 0; y < out_width; ++y) {
            for (int x = 0; x < out_width; ++x) {
                out_img[o * out_width * out_width + y * out_width + x] = 0.0f;
            }
        }
    }

    // 卷積運算
    for (int o = 0; o < out_depth; ++o) { // 遍歷輸出深度
        for (int i = 0; i < in_depth; ++i) { // 遍歷輸入深度
            for (int y = 0; y < out_width; ++y) { // 遍歷輸出圖像的高度
                for (int x = 0; x < out_width; ++x) { // 遍歷輸出圖像的寬度
                    // 計算對應輸入圖像區域的起始位置
                    for (int ky = 0; ky < weight_width; ++ky) {
                        for (int kx = 0; kx < weight_width; ++kx) {
                            int in_y = y + ky;
                            int in_x = x + kx;

                            // 獲取輸入像素值和權重值
                            float input_val = img[i * in_width * in_width + in_y * in_width + in_x];
                            float weight_val = weight[o * in_depth * weight_width * weight_width + 
                                                     i * weight_width * weight_width + 
                                                     ky * weight_width + kx];

                            // 累加到輸出
                            out_img[o * out_width * out_width + y * out_width + x] += input_val * weight_val;
                        }
                    }
                }
            }
        }
    }
}

void average_pooling(float *input, float *output, int in_width, int in_depth) {
    int out_height = in_width / 2;

    for (int d = 0; d < in_depth; d++) {
        for (int i = 0; i < out_height; i++) {
            for (int j = 0; j < out_height; j++) {
                float sum = 0.0;
                for (int x = 0; x < 2; x++) {
                    for (int y = 0; y < 2; y++) {
                        int in_row = i * 2 + x;
                        int in_col = j * 2 + y;
                        sum += input[d * in_width * in_width + in_row * in_width + in_col];
                    }
                }
                output[d * out_height * out_height + i * out_height + j] = sum / 4;
            }
        }
    }
}

int main()
{
    printf("start testing...\n");
    int in_width = 28;
    int in_depth = 1;
    int out_width = 24;
    int out_width_final = 12;
    int out_depth = 3;
    int weight_width = 5;

    int weight_size = weight_width * weight_width * in_depth * out_depth;
    // printf("weight_size: %d\n", weight_size);
    int input_image_size =in_width * in_width * in_depth;
    float  *weight = (float*)malloc(weight_size * sizeof(float));
        float *img = (float*)malloc(input_image_size * sizeof(float));
    // printf("input_image_size: %d\n", input_image_size);
    int out_size = out_width * out_width *out_depth;
    int out_size_final = out_width_final * out_width_final* out_depth;
    srand(1391);
    for(int i = 0;i < weight_size;i++){
        weight[i] =( rand() % 5) - 2;
    }
     srand(2697);
    for(int i = 0;i < input_image_size;i++){
        img[i] =  rand() % 255;
    }

    float *out_img = (float*)malloc(out_size_final * sizeof(float));
    // float *out_img2_conv = (float *)calloc(out_size, sizeof(float)); // 確保初始化
    // float *out_img2 = (float *)calloc(out_size_final, sizeof(float)); // 確保初始化

    // // 呼叫卷積函數和池化
    // software_convolution(img, weight, out_img2_conv, in_width, out_width, weight_width, in_depth, out_depth);

    // // ReLU
    // for (int i = 0; i < out_size; i++) {
    //     out_img2_conv[i] = out_img2_conv[i] > 0 ? out_img2_conv[i] : 0;
    // }

    // printf("software result (3x2 convolution):\n");
    // for (int k = 0; k < out_depth; k++) 
    // {
    //     printf("Depth %d:\n", k);
    //     for (int i = 0; i < out_width; i++) 
    //     {
    //         for (int j = 0; j < out_width; j++) 
    //         {
    //             printf("%f ", out_img2_conv[k * out_width * out_width + i * out_width + j]);
    //         }
    //         printf("\n");
    //     }
    //     printf("\n");
    // }

    // // 呼叫平均池化函數
    // average_pooling(out_img2_conv, out_img2, out_width, out_depth);
    // // 輸出結果
    // printf("software result (3x2 convolution):\n");
    // for (int k = 0; k < out_depth; k++) 
    // {
    //     printf("Depth %d:\n", k);
    //     for (int i = 0; i < out_width_final; i++) 
    //     {
    //         for (int j = 0; j < out_width_final; j++) 
    //         {
    //             printf("%f ", out_img2[k * out_width_final * out_width_final + i * out_width_final + j]);
    //         }
    //         printf("\n");
    //     }
    //     printf("\n");
    // }

    //trigger reset 0
    *((int volatile *)0xC4300028) = out_size;
    //initialize register
    *((int volatile *)0xC4300000) = in_width;
    *((int volatile *)0xC4300004) = out_width;
    *((int volatile *)0xC4300008) = weight_width;
    *((int volatile *)0xC4300010) = in_depth;
    *((int volatile *)0xC4300014) = out_depth;
   
     // load weight into register
    *((int volatile *)0xC4300018) = weight_size;
    for(int i = 0; i < weight_size; i++)
    {
        *((float volatile *)0xC430001c) = weight[i];
    }

     // load image into register
    *((int volatile *)0xC4300020) = input_image_size;
    
    for(int i = 0; i < input_image_size; i++)
    {
        *((float volatile *)0xC4300024) = img[i];
    }
    *((int volatile *)0xC430000c) = 1;
    while(*((int volatile *)0xC4200004) == 0);
    
    for(int i = 0; i < out_size_final; i++)
    {
        out_img[i] = *((float volatile *)0xC4200000);
    }

    printf("hardware result (3x2 convolution):\n");
    //    for (int k = 0; k < out_depth; k++) 
    // {
    //     printf("Depth %d:\n", k);
    //     for (int i = 0; i < out_width_final; i++) 
    //     {
    //         for (int j = 0; j < out_width_final; j++) 
    //         {
    //             printf("%f ", out_img[k * out_width_final * out_width_final + i * out_width_final + j]);
    //         }
    //         printf("\n");
    //     }
    //     printf("\n");
    // }
    free(img);
    free(weight);

    in_width = 12;
    in_depth = 3;
    out_width = 8;
    out_width_final = 4;
    out_depth = 32;
    weight_width = 5;
    weight_size = weight_width * weight_width * in_depth * out_depth;
    // printf("weight_size: %d\n", weight_size);
    input_image_size =in_width * in_width * in_depth;
    // printf("input_image_size: %d\n", input_image_size);
    out_size = out_width * out_width *out_depth;
    out_size_final = out_width_final * out_width_final* out_depth;
    float  *weight2 = (float*)malloc(weight_size * sizeof(float));
      float *out_img2 = (float*)malloc(out_size_final * sizeof(float));
    srand(1391);
    for(int i = 0;i < weight_size;i++){
        weight2[i] =( rand() % 5) - 2;
    }

    // memset(out_img2_conv, 0, out_size * sizeof(float));
    // memset(out_img2, 0, out_size_final * sizeof(float));

    
    // // 呼叫卷積函數和池化
    // software_convolution(img, weight, out_img2_conv, in_width, out_width, weight_width, in_depth, out_depth);

    // // ReLU
    // for (int i = 0; i < out_size; i++) {
    //     out_img2_conv[i] = out_img2_conv[i] > 0 ? out_img2_conv[i] : 0;
    // }

    // printf("software result (3x2 convolution):\n");
    // for (int k = 0; k < out_depth; k++) 
    // {
    //     printf("Depth %d:\n", k);
    //     for (int i = 0; i < out_width; i++) 
    //     {
    //         for (int j = 0; j < out_width; j++) 
    //         {
    //             printf("%f ", out_img2_conv[k * out_width * out_width + i * out_width + j]);
    //         }
    //         printf("\n");
    //     }
    //     printf("\n");
    // }

    // // 呼叫平均池化函數
    // average_pooling(out_img2_conv, out_img2, out_width, out_depth);
    // // 輸出結果
    // printf("software result (3x2 convolution):\n");
    // for (int k = 0; k < out_depth; k++) 
    // {
    //     printf("Depth %d:\n", k);
    //     for (int i = 0; i < out_width_final; i++) 
    //     {
    //         for (int j = 0; j < out_width_final; j++) 
    //         {
    //             printf("%f ", out_img2[k * out_width_final * out_width_final + i * out_width_final + j]);
    //         }
    //         printf("\n");
    //     }
    //     printf("\n");
    // }

    //trigger reset 0
    *((int volatile *)0xC4300028) = out_size;
    //initialize register
    *((int volatile *)0xC4300000) = in_width;
    *((int volatile *)0xC4300004) = out_width;
    *((int volatile *)0xC4300008) = weight_width;
    *((int volatile *)0xC4300010) = in_depth;
    *((int volatile *)0xC4300014) = out_depth;
   
     // load weight into register
    *((int volatile *)0xC4300018) = weight_size;
    for(int i = 0; i < weight_size; i++)
    {
        *((float volatile *)0xC430001c) = weight2[i];
    }

     // load image into register
    *((int volatile *)0xC4300020) = input_image_size;
    
    for(int i = 0; i < input_image_size; i++)
    {
        *((float volatile *)0xC4300024) = out_img[i];
    }
    *((int volatile *)0xC430000c) = 1;
    while(*((int volatile *)0xC4200004) == 0);
    
    for(int i = 0; i < out_size_final; i++)
    {
        out_img2[i] = *((float volatile *)0xC4200000);
    }

    printf("hardware result (3x2 convolution):\n");
    //   for (int k = 0; k < out_depth; k++) 
    // {
    //     printf("Depth %d:\n", k);
    //     for (int i = 0; i < out_width_final; i++) 
    //     {
    //         for (int j = 0; j < out_width_final; j++) 
    //         {
    //             printf("%f ", out_img2[k * out_width_final * out_width_final + i * out_width_final + j]);
    //         }
    //         printf("\n");
    //     }
    //     printf("\n");
    // }

    free(out_img);
    free(out_img2);
    free(weight2);
    return 0;
}