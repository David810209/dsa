#include<stdio.h>
#include <stdlib.h>
#include <string.h>

void software_convolution(float *img, float *weight, float *out_img, 
                          int in_width, int out_width, int weight_width, 
                          int in_depth, int out_depth) 
{
    int idx_x, idx_y, i, j, d_in, d_out;

    for (d_out = 0; d_out < out_depth; d_out++) 
    {
        for (idx_y = 0; idx_y < out_width; idx_y++) 
        {
            for (idx_x = 0; idx_x < out_width; idx_x++) 
            {
                float sum = 0.0;
                for (d_in = 0; d_in < in_depth; d_in++) 
                {
                    for (i = 0; i < weight_width; i++) 
                    {
                        for (j = 0; j < weight_width; j++) 
                        {
                            int img_idx = d_in * in_width * in_width + (idx_y + i) * in_width + (idx_x + j);
                            int weight_idx = d_out * in_depth * weight_width * weight_width + 
                                             d_in * weight_width * weight_width + i * weight_width + j;
                            sum += img[img_idx] * weight[weight_idx];
                        }
                    }
                }
                out_img[d_out * out_width * out_width + idx_y * out_width + idx_x] = sum;
            }
        }
    }
}

int main()
{
    float a[20] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 
                   11, 12, 13, 14, 15, 16, 17, 18, 19, 20};
    float b[20] = {3,1,4,1,5,9,2,6,5,3,5,8,9,7,9,3,2,3,8,4};
    float c[20] = {0};
    float d[20] = {0};
    for(int i = 0;i < 20;i++)
    {
        c[i] = a[i] + b[i];
    }
    
    for(int i = 0;i < 20;i++)
    {
        *((float volatile *)0xC4400000) = a[i];
        *((float volatile *)0xC4400004) = b[i];
        d[i] = *((float volatile *)0xC4400008);
        // d[i] = a[i] * b[i];
    }
    for(int i = 0;i < 20;i++)
    {
        if(c[i] != d[i])
        {
            printf("Error at %d\n", i);
            return 0;
        }
    }
    return 0;
}