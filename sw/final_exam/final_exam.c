#include "io_uart.h"

#define A ((unsigned int volatile *) 0xC2000000)
#define B ((unsigned int volatile *) 0xC200000C)
#define dot_prod ((unsigned int volatile *) 0xC2000018)

int a_vec[3] = {17, -23,  3};
int b_vec[3] = { 9,  25, 26};

int main(void)
{
    int answer;

    answer = a_vec[0]*b_vec[0] + a_vec[1]*b_vec[1] + a_vec[2]*b_vec[2];

    printf("The correct answer is: %d\n", answer);
    exit(0);
}

