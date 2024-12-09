#include<stdio.h>
#include <stdlib.h>
int main()
{
    float a[25] = {1, 2, 3, 4, 5,
                   6, 7, 8, 9, 10,
                   11, 12, 13, 14, 15,
                   16, 17, 18, 19, 20,
                   21, 22, 23, 24, 25};
    *(int volatile *)0xC4000000 = 25;
    for(int i = 0; i < 25; i++){
        *(float volatile *)0xC4100000 = a[i];
    }

    float b[25] = {1, 2, 3, 4, 5,
                   6, 7, 8, 9, 10,
                   11, 12, 13, 14, 15,
                   16, 17, 18, 19, 20,
                   21, 22, 23, 24, 25};
    
    for(int i = 0; i < 25; i++){
        *(float volatile *)0xC4200000 = b[i];
    }

    float test = *(float volatile *)0xC4300000;
    float ans = 0;
    for(int i = 0; i < 25; i++){
        ans += a[i] * b[i];
        a[i]++;
        b[i]+=2;
    }
    printf("Test: %f, Ans: %f\n", test, ans);

    *(int volatile *)0xC4000000 = 25;
    for(int i = 0; i < 25; i++){
        *(float volatile *)0xC4100000 = a[i];
    }

    for(int i = 0; i < 25; i++){
        *(float volatile *)0xC4200000 = b[i];
    }
    test = *(float volatile *)0xC4300000;
    ans = 0;
    for(int i = 0; i < 25; i++){
        ans += a[i] * b[i];
    }
    printf("Test: %f, Ans: %f\n", test, ans);
    return 0;
}