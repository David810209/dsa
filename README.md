# **Handwriting Recognition using CNN (Domain-Specific Accelerator)**  

## **Project Overview**  
This project focuses on implementing a **Domain-Specific Accelerator (DSA)** to accelerate the inner product operations in a **Convolutional Neural Network (CNN)** for handwriting recognition. The design is based on **`aquila`** — a RISC-V 5-stage pipelined core developed by the **Embedded Intelligence System Lab (EISL)**. The primary focus is on optimizing the **convolutional layer**, **Average Pooling Layer**, and **fully connected layer** Floating Point  computations (mainly focus on convolution) to improve CNN performance.  

## **Current Performance**  
   - Execution time reduced: **21502 ms → 298 ms** (72.15x speedup).
---

## **System Architecture**  
![block diagram](diagram.png)  
![workflow](workflow.png)  
---

## **Current Progress**

1. **Current Performance**  
   - Execution time reduced: **21502 ms → 298 ms** (72.15x speedup).

2. **CNN Optimization**  
   - **Convolutional Layer +Average Pooling Layer  Optimization**: Transfer the whole process into hardware in the `convolutional_layer.h`, `average_pooling.h` file, including the convolutional operation, ReLU activation, and pooling operation.
   - **Fully Connected Layer Optimization**: Enhanced the efficiency of inner product computations in the **fully_connected_layer**.  

3. **MMIO-based Communication**  
   - Uses **Memory-Mapped I/O (MMIO)** for communication between the CPU and the accelerator, enabling efficient hardware-software co-design.  

4. **Floating-Point IP Acceleration**  
   - Integrated three floating-point IP core in **Vivado**, utilizing a non-blocking approach to accelerate inner product calculations, floating point multiplication, addition and reduce bottlenecks.  

4. **Heap Management in TCM**  
   - Stored the **weight arrays** and **previous layer's feature maps** in **TCM (Tightly Coupled Memory)** using a dynamically managed **TCM heap**. Custom **tcm_malloc** and **tcm_free** functions were implemented, alongside linker script modifications to ensure seamless allocation without conflicting with boot code. This optimization effectively reduces cache latency and improves memory access efficiency.  

---