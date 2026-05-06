# ChipVerilogSuite

ChipVerilogSuite is a curated collection of chip-related Verilog RTL designs and aligned text metadata for RTL understanding, verification-oriented tasks, and benchmarking. The current release groups several industrial-style IP/design subsets and preserves both the source RTL and per-design descriptive artifacts.

## Overview

This repository currently contains:

- 5 design subsets: `or1200_hp`, `double_fpu`, `i2c`, `mips_16`, and `verilog_cordic_core`
- 64 packaged design entries with `description.txt` metadata under `des/`
- 68 Verilog files packaged under `des/`
- 74 source RTL Verilog files under `rtl/`
- 16 bench/testbench Verilog files plus 10 simulation `.do` scripts
- 9 reference documents, including PDF, DOC, and DOCX files

## Included Subsets

| Subset | Focus | Design Entries |
| --- | --- | ---: |
| `or1200_hp` | Hyper-pipelined OR1200 CPU-related modules | 38 |
| `double_fpu` | Double-precision floating-point units and pipeline variants | 9 |
| `i2c` | I2C controller core modules and supporting RTL | 3 |
| `mips_16` | 16-bit MIPS pipeline stages, memories, and top-level core modules | 11 |
| `verilog_cordic_core` | CORDIC datapath building blocks and top-level core | 3 |

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

## Formal Equivalence Suite

Run the suite command in the foreground:

```bash
python tools/formal_equivalence.py suite \
  --result-root Result \
  --report-dir reports/formal_suite \
  --summary-json reports/formal_suite_summary.json \
  --summary-csv reports/formal_suite_summary.csv
```

Run it in the background with `nohup` and redirect all output to one log file:

```bash
mkdir -p logs/formal
nohup python tools/formal_equivalence.py suite \
  --result-root Result \
  --report-dir reports/formal_suite \
  --summary-json reports/formal_suite_summary.json \
  --summary-csv reports/formal_suite_summary.csv \
  > logs/formal/run_all.log 2>&1 &
```

Note: `>` is a shell redirection operator, not a line continuation marker. Use it only once at the end of the command when redirecting stdout/stderr to a log file.
