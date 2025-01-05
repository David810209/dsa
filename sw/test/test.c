#include<stdio.h>
#include <stdlib.h>
#include <string.h>

int main()
{
    printf("start testing...\n");
    int in_size = 512;
    int out_size = 10;
    int weight_size = in_size * out_size;
    float *in = (float *)malloc(in_size * sizeof(float));
    float * weight = (float *)malloc(weight_size* sizeof(float));
    srand(1391);
    for(int i = 0; i < in_size; i++)
    {
        in[i] = rand() % 255;
    }
    srand(2697);
    for(int i = 0; i < weight_size; i++)
    {
        weight[i] = rand() % 4 - 1;
    }
    *((int volatile *)0xC4100000) = weight_size;
    for(int i = 0; i < weight_size; i++)
    {
        *((float volatile *)0xC4100004) = weight[i];
    }
     *((int volatile *)0xC4100018) = in_size;
    for(int i = 0; i < in_size; i++)
    {
        *((float volatile *)0xC410001c) = in[i];
    }
    *((int volatile *)0xC4100010) = 1;
    while(*((int volatile *)0xC4100010) == 0);
    int result = *((int volatile *)0xC4100014);
    printf("result = %d\n", result);
    free(in);
    free(weight);
    return 0;
}