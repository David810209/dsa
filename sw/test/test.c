#include<stdio.h>
#include <stdlib.h>
int main()
{
    float a[10] ={1,2,3,4,5,6,7,8,9,10};
    float b[10] = {1,2,3,4,5,6,7,8,9,10};
    float test;
    printf("start calculate\n");
    for(int j = 0;j < 1;j++){
        for(int i = 0;i < 10;i++){
            *((float volatile *)0xC4100000) = a[i];
            *((float volatile *)0xC4200000) = b[i];
        }
        test = *((float volatile *)0xC4300000);
        printf("test%d = %f\n",j, test);
    }
    
    float ans = 0;
    for(int i = 0;i < 10;i++){
        ans += a[i]*b[i];
    }
    printf("ans = %f\n",ans);

    return 0;
}