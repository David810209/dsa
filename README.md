# **Handwriting Recognition using CNN (Domain-Specific Accelerator)**  

## **Project Overview**  
This project focuses on implementing a **Domain-Specific Accelerator (DSA)** to accelerate the inner product operations in a **Convolutional Neural Network (CNN)** for handwriting recognition. The design is based on **`aquila`** — a RISC-V 5-stage pipelined core developed by the **Embedded Intelligence System Lab (EISL)**. The primary focus is on optimizing the **convolutional layer** and **fully connected layer** inner product computations to improve CNN performance.  

---

## **System Architecture**  
![block diagram](diagram.png)  

---

## **Current Progress**  

1. **MMIO-based Communication**  
   - Uses **Memory-Mapped I/O (MMIO)** for communication between the CPU and the accelerator, enabling efficient hardware-software co-design.  

2. **Floating-Point IP Acceleration**  
   - Integrated three floating-point IP core in **Vivado**, utilizing a non-blocking approach to accelerate inner product calculations, floating point multiplication, addition and reduce bottlenecks.  

3. **CNN Optimization**  
   - **Convolutional Layer Optimization**: Improved the speed of inner product calculations and addition in the `convolutional_layer.h` file, specifically for the **conv3d** function.  
   - **Fully Connected Layer Optimization**: Enhanced the efficiency of inner product computations in the **fully_connected_layer**.  
    - **Average pooling Layer Optimization**: Improved the speed of inner product calculations and addition.  

4. **Heap Management in TCM**  
   - Stored the **weight arrays** and **previous layer's feature maps** in **TCM (Tightly Coupled Memory)** using a dynamically managed **TCM heap**. Custom **tcm_malloc** and **tcm_free** functions were implemented, alongside linker script modifications to ensure seamless allocation without conflicting with boot code. This optimization effectively reduces cache latency and improves memory access efficiency.
5. **Weight Preload Optimization in conv3d**
   - To reduce memory access latency, 25 weights (5x5 kernel) are preloaded into hardware registers. During image traversal, only image data is sent to the hardware, where it is combined with the preloaded weights and passed to the Floating-Point IP core for fused multiply-add (FMA) operations. The results are then stored in the output buffer. This design eliminates redundant weight loading and ensures efficient weight reuse across the sliding window, improving computational efficiency.

6. **Current Performance**  
   - Execution time reduced: **21502 ms → 2363 ms** (9.1x speedup).  


---

## **Recent Work**  

1. **Convolution Layer Circuit Design**  
   - Further optimized the **conv3d** operation by implementing it directly in hardware to achieve higher computational efficiency.  

2. **CPooling Layer Circuit Design**  
   - Pooling layer is also the bottlenect (21%)
---
