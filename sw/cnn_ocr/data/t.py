import numpy as np

# 從 dat 檔案讀取浮點數
data = np.fromfile("weights.dat", dtype=np.float32)  # 如果是 32 位元浮點數
#
# 印出數值
print(data)
