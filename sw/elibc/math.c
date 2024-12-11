#include "math.h"

// 絕對值
float fabsf(float x) {
    return (x < 0) ? -x : x;
}

// 四捨五入
float roundf(float x) {
    return (x >= 0) ? (int)(x + 0.5f) : (int)(x - 0.5f);
}

// 平方根 (牛頓迭代法實現)
float sqrtf(float x) {
    if (x < 0) return -1; // 處理無效輸入
    float guess = x / 2.0f;
    float epsilon = 0.00001f;
    while (fabsf(guess * guess - x) > epsilon) {
        guess = (guess + x / guess) / 2.0f;
    }
    return guess;
}
