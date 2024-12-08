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

4. **Heap Management in TCM**  
   - Stored the **weight arrays** and **previous layer's feature maps** in **TCM (Tightly Coupled Memory)** using a dynamically managed **TCM heap**. Custom **tcm_malloc** and **tcm_free** functions were implemented, alongside linker script modifications to ensure seamless allocation without conflicting with boot code. This optimization effectively reduces cache latency and improves memory access efficiency.

5. **Current Performance**  
   - Execution time reduced: **21502 ms → 3270 ms** (6.58x speedup).  


---

## **Recent Work**  

1. **Convolution Layer Circuit Design**  
   - Further optimized the **conv3d** operation by implementing it directly in hardware to achieve higher computational efficiency.  

---

## **Implementation Details**  

1. **Software**  
   - Modified the CNN C code to offload inner product computations in the convolutional and fully connected layers to the hardware accelerator via MMIO.  
   - Replaced software-based floating-point operations with MMIO-mapped hardware computations to improve performance.  
   - Implemented **tcm_malloc** and **tcm_free** functions for dynamic memory allocation in the TCM heap.  

2. **Hardware**  
   - Implemented the **data_feeder** module in `soc_top.v`, which interacts with the floating-point IP core to manage data transfers for convolutional and fully connected layers.  
   - Designed a **non-blocking architecture** to allow concurrent data processing and computation, minimizing pipeline stalls.  
   - Optimized the **conv3d** operation by designing dedicated hardware to improve computational efficiency.  

3. **Memory Optimization**  
   - Stored weight arrays and previous layer's **feature maps** in **TCM** (Tightly Coupled Memory) to avoid cache latency and ensure deterministic memory access performance.  
   - Created a separate TCM heap region using the following **linker script modifications**:  

---
