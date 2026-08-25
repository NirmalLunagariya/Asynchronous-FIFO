# Asynchronous FIFO with CDC Synchronization

A SystemVerilog implementation of an **Asynchronous FIFO** for safely transferring data between two independent clock domains.

The design uses **Gray-coded read/write pointers** and **2-flop synchronizers** for clock-domain crossing (CDC). A self-checking testbench verifies normal operation, FULL/EMPTY conditions, and randomized read/write traffic.

## Features

- Independent write and read clocks
- Independent clock domains
- Gray-coded read/write pointers
- 2-flop CDC synchronization
- FULL and EMPTY detection
- Parameterized data width and FIFO depth
- Self-checking SystemVerilog testbench
- Randomized read/write verification
- Reference-queue scoreboard

## Architecture

```text
             WRITE CLOCK DOMAIN
                    |
              Write Pointer
                    |
              Binary → Gray
                    |
                    v
              +-----------+
              | 2-FF CDC  |
              |Synchronizer|
              +-----+-----+
                    |
                    v
              READ CLOCK DOMAIN

       +-------------------------+
       |      FIFO MEMORY        |
       |                         |
       |  Write Address          |
       |        ↓                |
       |  Read Address           |
       +-------------------------+
```

The write pointer is synchronized into the read clock domain, while the read pointer is synchronized into the write clock domain.

## Gray Code

Gray coding is used for CDC because only one bit changes between consecutive pointer values.

```text
Gray = Binary ^ (Binary >> 1)
```

This reduces the risk of inconsistent multi-bit pointer sampling when crossing clock domains.

## CDC Synchronizer

The project uses a standard two-flop synchronizer:

```text
Asynchronous Signal
        |
        v
     +-----+
     | FF1 |
     +--+--+
        |
        v
     +-----+
     | FF2 |
     +--+--+
        |
        v
Synchronized Signal
```

The synchronizer is implemented in `cdc_sync_2ff.sv`.

## FULL and EMPTY Detection

### EMPTY

The FIFO is empty when the next read pointer equals the synchronized write pointer.

```text
empty = (next_read_gray == synchronized_write_gray)
```

### FULL

The FIFO is full when the next Gray-coded write pointer matches the synchronized read pointer with the required wrap-around bits inverted.

This distinguishes a full FIFO from an empty FIFO even when the read and write addresses are identical.

## Project Structure

```text
.
├── async_fifo.sv
├── cdc_sync_2ff.sv
├── tb_async_fifo.sv
└── README.md
```

### `async_fifo.sv`

Main asynchronous FIFO RTL containing:

- FIFO memory
- Read/write pointers
- Binary-to-Gray conversion
- FULL detection
- EMPTY detection
- CDC pointer synchronization

### `cdc_sync_2ff.sv`

Reusable two-flop synchronizer used for transferring pointer information between clock domains.

### `tb_async_fifo.sv`

Self-checking testbench containing:

- Basic FIFO testing
- FULL condition testing
- EMPTY condition testing
- Randomized traffic
- Reference queue scoreboard
- Error detection and reporting

## Default Configuration

| Parameter | Value |
|---|---:|
| Data Width | 32 bits |
| Address Width | 5 bits |
| FIFO Depth | 32 entries |
| Write Clock | 100 MHz |
| Read Clock | ~76.9 MHz |

The FIFO depth is:

```text
DEPTH = 2^ADDR_WIDTH
```

For `ADDR_WIDTH = 5`:

```text
DEPTH = 32
```

## Verification

The testbench verifies:

1. **Basic FIFO operation** — written data is read back in FIFO order.
2. **FULL condition** — verifies that writes are blocked when the FIFO is full.
3. **EMPTY condition** — verifies that reads are blocked when the FIFO is empty.
4. **Randomized traffic** — performs asynchronous read/write operations and compares FIFO output against a reference queue.

The scoreboard checks:

- Data integrity
- FIFO ordering
- Simultaneous read/write operation
- FULL protection
- EMPTY protection
- Number of accepted writes and reads

A simulation passes when no data mismatches are detected and the expected reference data is correctly consumed.

## Simulation

The project can be simulated using a SystemVerilog-compatible simulator such as:

- Xilinx Vivado Simulator
- Questa/ModelSim
- Icarus Verilog
- Verilator

Example using Icarus Verilog:

```bash
iverilog -g2012 -o fifo_sim     async_fifo.sv     cdc_sync_2ff.sv     tb_async_fifo.sv

vvp fifo_sim
```

## Design Flow

```text
Binary Pointer
      |
      v
Gray Conversion
      |
      v
2-FF Synchronization
      |
      v
Destination Clock Domain
      |
      v
FULL / EMPTY Logic
```

This project focuses on RTL design and functional verification of an asynchronous FIFO. For FPGA implementation, the memory can potentially be inferred as dual-port block RAM depending on the target device and synthesis constraints.

## Possible Extensions

- Almost-FULL and Almost-EMPTY flags
- Programmable FIFO thresholds
- SystemVerilog assertions
- Functional coverage
- Formal verification
- Synthesis and timing analysis
- FPGA block RAM implementation
- ASIC SRAM macro integration
- Extended randomized stress testing

## Skills Demonstrated

- SystemVerilog RTL Design
- Asynchronous FIFO Design
- Clock Domain Crossing (CDC)
- Gray Code Pointer Design
- 2-Flip-Flop Synchronization
- FIFO FULL/EMPTY Logic
- Self-Checking Testbenches
- Scoreboard-Based Verification
- Randomized Verification
- Parameterized RTL

## Author

**Nirmal Lunagariya**

Developed as an RTL and verification project to study practical **clock-domain crossing and asynchronous FIFO design**.
