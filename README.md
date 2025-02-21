# Stock Market Data Processing on FPGA

## **Overview**
This project implements **real-time stock market data processing** using the **DE1-SoC FPGA**. It performs **exponential smoothing** on stock price data and displays the results on a **seven-segment display**. The system leverages **floating-point arithmetic**, memory operations, and a structured **finite state machine (FSM)** to efficiently process financial data.

## **Features**
- **FPGA-based Computation**: Uses the Cyclone V FPGA for high-speed parallel processing.
- **Exponential Smoothing**: Implements IEEE-754 floating-point arithmetic.
- **Memory Handling**: Reads historical stock data from ROM and writes results to RAM.
- **FSM Control**: Ensures structured data flow and operation management.
- **Seven-Segment Display**: Shows computed stock price values in real time.

## **System Architecture**
### **1. Top-Level Entity**
- Controls the overall **data flow and processing**.
- Manages input selection and initiates the **computation process**.
- Displays system states (`WRITE`, `READ`, `SMOOTH`, `COMPLT`) on a **seven-segment display**.

### **2. Floating-Point Computation Module**
- Implements **parallel multiplications** and **serial addition** for fast processing.
- Uses a **Mealy-type FSM** for execution control.
- Computes results following the equation:
  \[ S_T = \alpha X_T + (1 - \alpha) S_{T-1} \]

### **3. Memory Management**
- **ROM**: Stores static historical stock price datasets.
- **RAM**: Stores intermediate and final computed results.
- **Dual-Port Access**: Ensures smooth data flow between storage and computation units.

## **Testbench and FPGA Demonstration**
### **Simulation Results**
- **FSM Validation**: Verified transitions between states via ModelSim.
- **Floating-Point Arithmetic Accuracy**: Confirmed correct results via waveform analysis.
- **Seven-Segment Display Testing**: Checked correct output representation.

### **FPGA Execution**
- **Real-time Data Processing**: Successfully computed and displayed stock price trends.
- **Correct Display Outputs**: FPGA results matched simulation expectations.
- **Stable Performance**: Verified operation at **50 MHz clock frequency**.


