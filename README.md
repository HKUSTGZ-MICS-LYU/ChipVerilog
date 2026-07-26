# ChipVerilog

ChipVerilogSuite is a Verilog RTL benchmark and workflow repository for RTL generation, functional checking, and equivalence-oriented evaluation. It bundles reference RTL, aligned textual specifications, generated candidate implementations, and Python tools for candidate generation and verification.

## Paper and Artifact

- **Paper:** [ChipVerilog: A Large-Scale OpenCores-Derived Benchmark for
  LLM-Based Verilog RTL Generation](https://arxiv.org/abs/2607.13079)
- **Evaluated artifact:** [Zenodo DOI
  10.5281/zenodo.21583114](https://doi.org/10.5281/zenodo.21583114)


The current tree contains 64 design tasks across 5 families:

| Family | Tasks | Notes |
| --- | ---: | --- |
| `or1200_hp` | 38 | OR1200 CPU-related modules |
| `mips_16` | 11 | 16-bit MIPS stages, memories, and top level |
| `double_fpu` | 9 | Double-precision floating-point blocks |
| `i2c` | 3 | I2C controller modules |
| `verilog_cordic_core` | 3 | CORDIC datapath blocks |

## Repository Layout

| Path | Purpose |
| --- | --- |
| `Src/` | Original source trees, docs, benches, and per-task `description.txt` prompts used for generation |
| `Des/` | Flattened per-module reference directories used by the verification flow |
| `Result/<model>/<module>/` | Generated candidates, one module directory per model |
| `reports/` | Aggregated compile, syntax, and equivalence summaries |
| `logs/` | Suite-level logs |
| `tools/` | Python automation scripts |
| `run_codex_batch_txt.sh` | Shell helper for a separate Codex text-to-Verilog workflow |

Common naming conventions:

- A generated candidate is stored as `Result/<model>/<module>/<module>_tN.v`.
- Per-attempt verification artifacts are stored in `Result/<model>/<module>/<module>_tN/`.
- For `mips_16`, generated result module names use the `mips_` prefix, for example `mips_alu`.

## Typical Workflow

1. Inspect or edit the task prompt under `Src/**/des/**/description.txt`.
2. Generate Verilog candidates into `Result/<model>/`.
3. Run compile/simulation/equivalence checks against `Des/`.
4. Inspect per-attempt logs in `Result/.../<module>_tN/` and aggregated CSV/JSON reports in `reports/`.

## Requirements

The Python tools in `tools/` use only the Python standard library. No `pip install` step is required for them.

Required executables:

- `python3`
- `iverilog`
- `vvp`
- `yosys`

For DeepSeek generation you also need:

- `DEEPSEEK_API_KEY` in the environment, or `OPENAI_API_KEY` as fallback

All three verification executables can be overridden with CLI flags:

```bash
python3 tools/formal_equivalence.py suite \
  --iverilog /path/to/iverilog \
  --vvp /path/to/vvp \
  --yosys /path/to/yosys
```

## Python Tools

### `tools/generate_deepseek_results.py`

This script discovers every `Src/**/des/**/description.txt`, sends the prompt to the DeepSeek chat-completions API, and writes normalized Verilog candidates into `Result/deepseek/`.

```bash
export DEEPSEEK_API_KEY=YOUR_KEY
python3 tools/generate_deepseek_results.py --dry-run --modules cordic mips_alu --samples 2
```

Default outputs:

- Candidate Verilog: `Result/deepseek/<module>/<module>_tN.v`
- Request/response logs: `logs/deepseek/<module>/`


### `tools/formal_equivalence.py`

This script verifies generated candidates against the reference design under `Des/`. It supports three subcommands:

- `verify`: verify one `Result/<model>/<module>/` directory
- `check`: verify one module from an arbitrary candidates root
- `suite`: verify every discovered module under `Result/`

The flow can use compilation, simulation, and Yosys-based equivalence checks depending on the reference module and available testbench assets.

#### `verify`

Use this when you already know the exact candidate directory:

```bash
python3 tools/formal_equivalence.py verify Result/deepseek/cordic
```

Write per-module JSON/CSV reports to a custom directory:

```bash
python3 tools/formal_equivalence.py verify \
  Result/deepseek/mips_alu \
  --report-dir reports/function_result/manual_checks
```

#### `check`

Use this when you want to point at a candidates root and select the module explicitly:

```bash
python3 tools/formal_equivalence.py check \
  --candidates Result/deepseek \
  --module-dir cordic
```

#### `suite`

Run the full verification sweep for one model:

```bash
python3 tools/formal_equivalence.py suite --model deepseek
```

Run across every model directory under `Result/`:

```bash
python3 tools/formal_equivalence.py suite
```

Default outputs:

- Per-module reports: `reports/function_result/formal_equivalence_suite/<model>/<module>.json`
- Per-module CSV: `reports/function_result/formal_equivalence_suite/<model>/<module>.csv`
- Suite summary JSON: `reports/formal_equivalence_suite_summary.json`
- Suite summary CSV: `reports/formal_equivalence_suite_summary.csv`

Per-module reports are written into a per-model subdirectory so that one model's
run never overwrites another model's audit trail. Runs filtered with `--model`
do NOT rewrite the global `reports/compile_suite/` and `reports/syntax_result/`
CSVs (those always describe a full all-model sweep).

### `tools/recompute_corrected_summary.py`

Provides an additional diagnostic view of the earlier aggregate CSV report,
including separate full and bounded equivalence counts. Outputs go to
`reports/corrected/`. Paper-table reproduction uses the candidate-level AE
entry point described below.

## Artifact Evaluation

The current artifact contains 64 tasks and five cached candidate verdicts per
task for each evaluated model. Reproduce the aggregate table with:

```bash
python3 artifact_evaluation/reproduce_metrics.py
```

Run the compact verification workflow with:

```bash
bash artifact_evaluation/smoke_test.sh
```

See `artifact_evaluation/README.md` for expected output and
`artifact_evaluation/METRIC_DEFINITION.md` for the exact metric definition.

## Output Interpretation

- `compile_pass`: the candidate passed the iverilog compile gate (which also
  requires the top module to carry the reference name).
- `simulation_pass`: the candidate passed a **self-checking** testbench. Modules
  whose testbench is print-only (no fail/error/mismatch strings, e.g.
  `mips_16/register_file`, `mips_16/IF_stage`, `mips_16/mips_16_core_top`,
  `or1200/or1200_top`) cannot conclude via simulation; they fall through to the
  formal flow and the sim outcome is recorded in `reason` only.
- `equivalence_pass`: total formal passes, split into
  `equivalence_pass_full` (unbounded combinational SAT proof or temporal
  induction via `equiv_induct`) and `equivalence_pass_bounded`
  (`sat -seq <depth> -set-init-zero`, a bounded check from an all-zero initial
  state — NOT a full proof; depth defaults to 16, see `--depth`).
- `function_pass`: rows with status `pass` from either flow; the main rollup.
- Statuses `equivalence_timeout` and `equivalence_error` mark inconclusive
  formal runs (solver timeout / yosys tooling error). They are deliberately NOT
  counted as `function_fail`: a timeout proves nothing about the candidate.
- `generated_stub_modules` in detail rows lists submodules that were replaced by
  auto-generated stubs; an equivalence pass with stubs only covers the logic
  outside the stubbed cones.

## Notes

- `generate_deepseek_results.py` writes into `Result/deepseek/` by default, but the verifier works for any `Result/<model>/` layout such as `codex`, `claude`, or `deepseek`.
- `formal_equivalence.py verify` expects a directory under `Result/<model>/<module>/` so it can infer the model name automatically.
- The Src leaf `double_fpu/des/verilog/fpu_double` maps to the result/Des name `fpu` (the directory was renamed after the Des/Result trees were built).
- Aggregate artifact-evaluation metrics are computed from the 64-task
  candidate-level verdicts under `Result/`; the earlier CSV summaries under
  `reports/` remain available as audit records.

## License

Our code is released under the repository-level LICENSE. Third-party RTL
components retain their original licenses. See THIRD_PARTY_LICENSES.md for
provenance and licensing details.
