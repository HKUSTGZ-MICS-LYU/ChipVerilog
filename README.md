# ChipVerilogSuite

ChipVerilogSuite is a curated collection of chip-related Verilog RTL designs and aligned text metadata for RTL understanding, verification-oriented tasks, and benchmarking. The current release groups several industrial-style IP/design subsets and preserves both the source RTL and per-design descriptive artifacts.

## Overview

This repository currently contains:

- 4 design subsets: `or1200_hp`, `double_fpu`, `i2c`, and `verilog_cordic_core`
- 54 design entries under `des/`
- 60 RTL Verilog files under `rtl/`
- 55 Verilog files packaged with design-level metadata under `des/`
- 6 bench/testbench Verilog files
- Reference documents including 4 PDF files and 1 DOC file

## Included Subsets

| Subset | Focus | Design Entries |
| --- | --- | ---: |
| `or1200_hp` | Hyper-pipelined OR1200 CPU-related modules | 38 |
| `double_fpu` | Double-precision floating-point units and pipeline variants | 9 |
| `i2c` | I2C controller RTL and related support modules | 5 |
| `verilog_cordic_core` | CORDIC core and testbench pair | 2 |

## Repository Layout

Most subsets follow the same high-level organization:

```text
subset/
├── rtl/       # original or source RTL files
├── des/       # per-design packaged data
├── bench/     # testbenches, when available
└── doc/       # manuals or specification documents, when available
```

The `des/` directory is the main dataset-oriented view. Each design entry typically contains:

- `*.v`: the Verilog module associated with the entry
- `description.txt`: a concise natural-language description
- `detail.txt`: richer implementation details when available
