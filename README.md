# FPGA-Based CNN Accelerator for MNIST Digit Recognition

A parameterized RTL implementation of a LeNet-style convolutional neural network for handwritten digit recognition. The design is written in Verilog and organized around processing elements (PEs), a PE array, convolution and pooling control, and a fully connected classification stage.

The project was developed as an RTL-based FPGA accelerator and synthesized targeting the **AMD Xilinx Kria KV260** platform.

> **Repository scope:** This repository contains the Verilog RTL, memory initialization files, and an Icarus Verilog testbench. The uploaded source archive does not include a Vivado project (`.xpr`), board constraints (`.xdc`), or synthesis/implementation reports. Add those artifacts separately if you want the repository to document the complete Vivado flow and measured FPGA resource/timing results.

## 1. Network architecture

The top-level module is `LeNet` (`LeNet.v`). With its default parameters, the network processes a 28 × 28 single-channel input and produces one of ten digit classes (0–9).

| Stage | Configuration | Output dimensions |
|---|---|---:|
| Input | 28 × 28, 1 channel | 28 × 28 × 1 |
| Convolution 1 | 6 filters, each 5 × 5 | 24 × 24 × 6 |
| Pooling 1 | 2 × 2 downsampling | 12 × 12 × 6 |
| Convolution 2 | 12 filters, each 5 × 5 | 8 × 8 × 12 |
| Pooling 2 | 2 × 2 downsampling | 4 × 4 × 12 |
| Fully connected | 192 input features → 10 outputs | 10 scores |
| Classification | Maximum-score selection | Digit 0–9 |

The default weight-memory depth is **3,870 words**:
- Convolution 1: 1 × 5 × 5 × 6 = 150
- Convolution 2: 6 × 5 × 5 × 12 = 1,800
- Fully connected: 12 × 4 × 4 × 10 = 1,920

The RTL uses a 32-bit datapath by default (`M=32`) and exposes a parameter `N` in the multiplication/MAC modules for selecting the product slice. The default is `N=0`. Review the training/export and fixed-point quantization procedure alongside the memory files when reproducing numerical results.

## 2. RTL architecture

The main datapath is built from reusable processing elements:

- **Multiplication.v** — signed multiplication and product-slice selection.
- **MACC.v** — multiply-accumulate unit used by the fully connected layer.
- **PE.v** — processing element that multiplies an input by a weight and accumulates the partial sum while forwarding the input.
- **PE_Array.v** — cascaded row of five processing elements.
- **Conv3D.v** — convolution address/control logic and a six-filter PE matrix (`PE_Matrix6F`).
- **max2.v** and **softmax.v** — despite the `softmax` module name, the implementation compares the ten output scores and asserts the output corresponding to the maximum score; it does not calculate exponential values or normalized probabilities.
- **FC.v** — ten parallel MACC paths for the fully connected layer, followed by maximum-score classification.
- **LeNet.v** — top-level layer sequencing, weight/input memory access, feature-map storage, pooling-result accumulation, and fully connected layer connection.
- **tb_LeNet.v** — simulation testbench with clock/reset generation, waveform dumping, and detected-digit display.

### High-level data flow

```text
28 × 28 input image
        |
        v
Convolution 1 (6 filters, 5 × 5)
        |
        v
2 × 2 pooling
        |
        v
Convolution 2 (12 filters, 5 × 5)
        |
        v
2 × 2 pooling
        |
        v
Fully connected layer (192 → 10)
        |
        v
Maximum-score digit classification
        |
        v
Predicted digit (0–9)
```

## 3. Repository contents

| File | Description |
|---|---|
| `LeNet.v` | Top-level CNN datapath and controller |
| `Conv3D.v` | Convolution controller and six-filter PE matrix |
| `PE.v` | Processing element |
| `PE_Array.v` | Five-PE row/array |
| `Multiplication.v` | Signed multiplier |
| `MACC.v` | Multiply-accumulate unit |
| `FC.v` | Fully connected layer |
| `max2.v` | Signed maximum-of-two comparator |
| `softmax.v` | Ten-class maximum-score selection logic |
| `tb_LeNet.v` | Testbench |
| `W.mem` | Weight initialization data (3,870 words) |
| `I0.mem`–`I9.mem` | Input-image memory files (784 words each); the current top-level initialization selects `I6.mem` |
| `LeNet.vcd` | Previously generated simulation waveform |
| `lenet_tb` | Previously generated Icarus Verilog simulation executable; regenerate it locally rather than relying on this binary |

Memory files are read using `$readmemb`, so run the simulation from the directory containing the `.mem` files.

## 4. Run the RTL simulation

### Requirements

- Icarus Verilog (`iverilog` and `vvp`)
- GTKWave (optional, for waveform inspection)

### Windows PowerShell

Open a terminal in the repository root and run:

```powershell
iverilog -g2012 -o lenet_tb.vvp tb_LeNet.v LeNet.v Conv3D.v PE_Array.v PE.v Multiplication.v FC.v MACC.v softmax.v max2.v
vvp .\lenet_tb.vvp
```

The testbench prints the detected digit when `LeNet_Out` becomes valid and writes a waveform file named `LeNet.vcd`.

To inspect the waveform:

```powershell
gtkwave .\LeNet.vcd
```

### Linux / WSL

```bash
iverilog -g2012 -o lenet_tb.vvp tb_LeNet.v LeNet.v Conv3D.v PE_Array.v PE.v Multiplication.v FC.v MACC.v softmax.v max2.v
vvp ./lenet_tb.vvp
gtkwave LeNet.vcd
```

If the simulation cannot find `W.mem` or `I6.mem`, check that the current working directory is the repository root.

## 5. FPGA synthesis

**Target platform:** AMD Xilinx Kria KV260

The accelerator RTL was synthesized targeting the Kria KV260 platform

## 6. Important implementation notes

- The top-level module initializes weights from `W.mem` and the input image from `I6.mem`.
- Although `I0.mem` through `I9.mem` are included, the current source selects `I6.mem`. To test another image, change the `$readmemb` filename in the initialization block of `LeNet.v`.
- The design uses `$readmemb`; preserve the memory-file format and keep the files in the simulation working directory.
- `softmax.v` implements a maximum-score/argmax decision, not mathematical softmax normalization.
- The supplied testbench runs for a fixed simulation interval. A displayed digit is the classification output produced by the RTL for the selected input and loaded weights.
- The source archive alone does not document how the trained model was converted into `W.mem`, the input preprocessing/quantization procedure, or the expected labels for each `I*.mem` file. Include those details to make the experiment independently reproducible.

## 7. Future improvements

- Add a documented model-training and weight-export pipeline.
- Document input normalization and fixed-point scaling/quantization.
- Add a self-checking testbench with expected labels and accuracy calculation over multiple images.
- Add Vivado constraints and archive synthesis/implementation reports.
- Evaluate pipelining, parallelism, memory organization, and resource/performance trade-offs.
- Compare software inference and FPGA inference using clearly defined latency and throughput measurements.

## 8. Citation

If you use or extend this RTL in your work, please cite or acknowledge this repository:

**CNN Verilog — FPGA-Based CNN Accelerator for MNIST Digit Recognition**  
Repository: https://github.com/leninLD/CNN_verilog

---

*Update this README with the exact Vivado version, device part, timing constraints, and resource-utilization results from your KV260 synthesis before presenting those figures as measured results.*
