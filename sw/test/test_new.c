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
        weight[i] = rand() % 4;
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
    *((int volatile *)0xC4200000) = out_size;
    //initialize register
    *((int volatile *)0xC4300000) = in_width;
    *((int volatile *)0xC4300004) = out_width;
    *((int volatile *)0xC4300008) = weight_width;
    *((int volatile *)0xC4300010) = in_depth;
    *((int volatile *)0xC4300014) = out_depth;
    // load image into register
    
    *((int volatile *)0xC4100000) = input_image_size;
    
    for(int i = 0; i < input_image_size; i++)
    {
        *((float volatile *)0xC4100004) = img[i];
    }
    // load weight into register
    
    *((int volatile *)0xC4000000) = weight_size;
    for(int i = 0; i < weight_size; i++)
    {
        *((float volatile *)0xC4000004) = weight[i];
    }
    *((int volatile *)0xC430000c) = 1;

    while(*((int volatile *)0xC430000c) == 0);
    
    for(int i = 0; i < out_size; i++)
    {
        out_img[i] = *((float volatile *)0xC4200004);
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
    free(out_img2);
    /////////////////////////////
     in_width = 12;
     in_depth = 3;
     out_width = 8;
     out_depth = 32;
     weight_width = 5;
     weight_size = weight_width * weight_width * in_depth * out_depth;
     input_image_size =in_width * in_width * in_depth;
   
    srand(6987);
    for(int i = 0;i < weight_size;i++){
        weight[i] = rand() % 3;
    }
     srand(3284);
    for(int i = 0;i < input_image_size;i++){
        img[i] =  rand() % 255;
    }
    out_size = out_width * out_width *out_depth;
    out_img = (float *)malloc(out_size* sizeof(float));
    out_img2 = (float *)malloc(out_size * sizeof(float));
    

    memset(out_img2, 0, out_size * sizeof(float));

    // 調用改進的 software_convolution
    software_convolution(img, weight, out_img2, in_width, out_width, weight_width, in_depth, out_depth);

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

    // free(out_img2);


    //trigger reset 0
    *((int volatile *)0xC4200000) = out_size;
    //initialize register
    *((int volatile *)0xC4300000) = in_width;
    *((int volatile *)0xC4300004) = out_width;
    *((int volatile *)0xC4300008) = weight_width;
    *((int volatile *)0xC4300010) = in_depth;
    *((int volatile *)0xC4300014) = out_depth;
    // load image into register
    
    *((int volatile *)0xC4100000) = input_image_size;
    
    for(int i = 0; i < input_image_size; i++)
    {
        *((float volatile *)0xC4100004) = img[i];
    }
    // load weight into register
    
    *((int volatile *)0xC4000000) = weight_size;
    for(int i = 0; i < weight_size; i++)
    {
        *((float volatile *)0xC4000004) = weight[i];
    }
    *((int volatile *)0xC430000c) = 1;

    while(*((int volatile *)0xC430000c) == 0);
    
    for(int i = 0; i < out_size; i++)
    {
        out_img[i] = *((float volatile *)0xC4200004);
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


    
    

    return 0;
}