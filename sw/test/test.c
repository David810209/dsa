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


int main()
{
    int in_width = 28;
    int in_depth = 1;
    int out_width = 24;
    int out_depth = 3;
    int weight_width = 5;
    float weight[2400] ;
        float img[2048]; 
    int weight_size = weight_width * weight_width * in_depth * out_depth;
    int input_image_size =in_width * in_width * in_depth;
    srand(1391);
    for(int i = 0;i < weight_size;i++){
        weight[i] =( rand() % 5) - 2;
    }
     srand(2697);
    for(int i = 0;i < input_image_size;i++){
        img[i] =  rand() % 255;
    }
    int out_size = out_width * out_width *out_depth;
    float * out_img = (float *)malloc(out_size* sizeof(float));
    float *  out_img2 = (float *)malloc(out_size * sizeof(float));
    

    memset(out_img2, 0, out_size * sizeof(float));

    // 調用改進的 software_convolution
    software_convolution(img, weight, out_img2, in_width, out_width, weight_width, in_depth, out_depth);
    for(int i = 0;i < out_size;i++){
        out_img2[i] = out_img2[i] > 0 ? out_img2[i] : 0;
    }
    // 輸出結果
    printf("software result (3x2 convolution):\n");
    for (int k = 0; k < out_depth; k++) 
    {
        printf("Depth %d:\n", k);
        for (int i = 0; i < out_width; i++) 
        {
            for (int j = 0; j < out_width; j++) 
            {
                printf("%f ", out_img2[k * out_width * out_width + i * out_width + j]);
            }
            printf("\n");
        }
        printf("\n");
    }

    //trigger reset 0
    *((int volatile *)0xC4300028) = out_size;
    //initialize register
    *((int volatile *)0xC4300000) = in_width;
    *((int volatile *)0xC4300004) = out_width;
    *((int volatile *)0xC4300008) = weight_width;
    *((int volatile *)0xC4300010) = in_depth;
    *((int volatile *)0xC4300014) = out_depth;
    // load image into register
    
    *((int volatile *)0xC4300020) = input_image_size;
    
    for(int i = 0; i < input_image_size; i++)
    {
        *((float volatile *)0xC4300024) = img[i];
    }
    // load weight into register
    
    *((int volatile *)0xC4300018) = weight_size;
    for(int i = 0; i < weight_size; i++)
    {
        *((float volatile *)0xC430001c) = weight[i];
    }
    *((int volatile *)0xC430000c) = 1;

    while(*((int volatile *)0xC430000c) == 0);
    
    for(int i = 0; i < out_size; i++)
    {
        out_img[i] = *((float volatile *)0xC430002c);
    }

    printf("hardware result\n");
    for(int k = 0;k < out_depth;k++){
        printf("Depth %d:\n", k);
        for(int i = 0;i < out_width;i++)
        {
            for(int j = 0;j < out_width;j++)
            {
                printf("%f ", out_img[i*out_width+j + k * out_width * out_width]);
                if(out_img[i*out_width+j + k * out_width * out_width] != out_img2[k * out_width * out_width + i * out_width + j]){
                    printf("Error at %d %d %d\n", i, j, k);
                    return 0;
                }
            }
            printf("\n");
        }
        printf("\n");
    }
    
    free(out_img);
    // free(out_img2);
   
    return 0;
}