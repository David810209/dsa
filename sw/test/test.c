#include<stdio.h>
#include <stdlib.h>
#include <string.h>


void software_convolution(float *img, float *weight, float *out_img, 
                          int in_width, int out_width, int weight_width) 
{
    int const1 = in_width - weight_width; // 用於跳過邊界
    int idx_x, idx_y, i, j;

    for (idx_y = 0; idx_y < out_width; idx_y++) 
    {
        for (idx_x = 0; idx_x < out_width; idx_x++) 
        {
            float sum = 0.0;
            for (i = 0; i < weight_width; i++) 
            {
                for (j = 0; j < weight_width; j++) 
                {
                    int img_idx = (idx_y + i) * in_width + (idx_x + j);
                    int weight_idx = i * weight_width + j;
                    sum += img[img_idx] * weight[weight_idx];
                }
            }
            out_img[idx_y * out_width + idx_x] += sum;
        }
    }
}



int main()
{
    float weight[25] = {1, 2, 3, 4, 5,
                   1, 2, 3, 4, 5,
                  1, 2, 3, 4, 5,
                   1, 2, 3, 4, 5,
                   1, 2, 3, 4, 5};
    float img[64] = {
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8
    };
    int in_width = 8;
    int out_width = 4;
    int weight_width = 5;
    float *out_img = (float *)malloc(out_width * out_width * sizeof(float));
    float *out_img2 = (float *)malloc(out_width * out_width * sizeof(float));
    *((int volatile *)0xC4200000) = out_width * out_width;
    *((int volatile *)0xC4300000) = in_width;
    *((int volatile *)0xC4300004) = out_width;
    *((int volatile *)0xC4300008) = weight_width;
    int const1 = in_width - weight_width;
    int const2 = in_width - out_width;
    *((int volatile *)0xC4100000) = 1;
    int input_image_size = in_width * in_width;
    for(int i = 0; i < input_image_size; i++)
    {
        *((float volatile *)0xC4100004) = img[i];
    }
    *((int volatile *)0xC4000000) = 1;
    for(int i = 0; i < 25; i++)
    {
        *((float volatile *)0xC4000004) = weight[i];
    }
    *((int volatile *)0xC430000c) = 1;

    while(*((int volatile *)0xC430000c) == 0);
    
    for(int i = 0; i < out_width * out_width; i++)
    {
        out_img[i] = *((float volatile *)0xC4200004);
    }
    ///////////////////////////////////////////////////////////////////////////////////////////////
    *((int volatile *)0xC4100000) = 1;
    for(int i = 0; i < input_image_size; i++)
    {
        *((float volatile *)0xC4100004) = img[i];
    }
    *((int volatile *)0xC4000000) = 1;
    for(int i = 0; i < 25; i++)
    {
        *((float volatile *)0xC4000004) = weight[i];
    }
    *((int volatile *)0xC430000c) = 1;

    while(*((int volatile *)0xC430000c) == 0);
    
    for(int i = 0; i < out_width * out_width; i++)
    {
        out_img[i] = *((float volatile *)0xC4200004);
    }

    printf("hardware result2\n");
    for(int i = 0;i < out_width;i++)
    {
        for(int j = 0;j < out_width;j++)
        {
            printf("%f ", out_img[i*out_width+j]);
        }
        printf("\n");
    }

    memset(out_img2, 0, out_width * out_width * sizeof(float));
    software_convolution(img, weight, out_img2, in_width, out_width, weight_width);
    software_convolution(img, weight, out_img2, in_width, out_width, weight_width);
   printf("software result2\n");
    for(int i = 0;i < out_width;i++)
    {
        for(int j = 0;j < out_width;j++)
        {
            printf("%f ", out_img2[i*out_width+j]);
        }
        printf("\n");
    }
    return 0;
}