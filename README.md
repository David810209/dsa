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
   - Integrated a floating-point IP core in **Vivado**, utilizing a non-blocking approach to accelerate inner product calculations and reduce bottlenecks.  

3. **CNN Optimization**  
   - **Convolutional Layer Optimization**: Improved the speed of inner product calculations in the `convolutional_layer.h` file, specifically for the **conv3d** function.  
   - **Fully Connected Layer Optimization**: Enhanced the efficiency of inner product computations in the **fully_connected_layer**.  
   - **TCM Optimization**: Stored weight arrays in **TCM (Tightly Coupled Memory)** to mitigate cache latency and improve memory access efficiency.  

4. **Current Performance**  
   - Execution time reduced: **21289 ms → 3582 ms** (5.94x speedup).  

---

## **Recent Work**  

1. **Memory Optimization**  
   - Store the previous layer's **feature maps** in **TCM** to further reduce cache latency.  

2. **Convolution Layer Circuit Design**  
   - Further optimize the **conv3d** operation by implementing it directly in hardware to achieve higher computational efficiency.  

3. **Scaling to Complex Models**  
   - Explore deeper and more complex CNN models, and optimize the accelerator design to support larger-scale convolutional operations.  

---

## **Implementation Details**  

1. **Software**  
   - Modified the CNN C code to offload inner product computations in the convolutional and fully connected layers to the hardware accelerator via MMIO.  
   - Replaced software-based floating-point operations with MMIO-mapped hardware computations to improve performance.  

2. **Hardware**  
   - Implemented the **data_feeder** module in `soc_top.v`, which interacts with the floating-point IP core to manage data transfers for convolutional and fully connected layers.  
   - Designed a **non-blocking architecture** to allow concurrent data processing and computation, minimizing pipeline stalls.  

3. **Memory Optimization**  
   - Stored weight arrays in **TCM** (Tightly Coupled Memory) to avoid cache latency and ensure deterministic memory access performance.  
---
