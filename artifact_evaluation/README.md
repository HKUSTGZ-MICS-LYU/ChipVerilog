# Artifact evaluation

This directory contains the entry points for reproducing the aggregate metrics
and running a compact verification check. The cached artifact is self-contained;
model API access is not required.

## Environment

Create the Conda environment from the repository root:

```bash
conda env create -f artifact_evaluation/environment.yml
conda activate chipverilog-ae
```

The metric-only command requires Python 3.9 or newer. The smoke test also uses
Icarus Verilog 12.0 (`iverilog` and `vvp`). Yosys 0.62 is required for a full
suite rerun.

## Reproduce the aggregate table

```bash
python3 artifact_evaluation/reproduce_metrics.py
```

Expected output:

```text
REPRODUCED RESULTS (64 tasks x 5 samples/model)
model,syntax_pass@1,syntax_pass@5,function_pass@1,function_pass@5
Claude Opus 4.5,78.75,96.88,17.50,35.94
GPT-5.4,83.13,93.75,23.13,37.50
DeepSeek V4 Pro,45.94,78.13,13.44,23.44
```

The precise pass criteria, estimator, aggregation, and rounding rule are in
[`METRIC_DEFINITION.md`](METRIC_DEFINITION.md).

## Run the smoke test

```bash
bash artifact_evaluation/smoke_test.sh
```

The smoke test checks the 64-task metric inputs, reruns the five-candidate
`mips_data_mem` reviewer subset, validates the two FPU references, and reruns
the cached FPU pipeline candidates for Claude Opus 4.5 and GPT-5.4. Temporary
outputs are created under `/tmp` and removed automatically.

## Full verification

To rerun all cached candidates with Icarus Verilog and Yosys:

```bash
python3 tools/formal_equivalence.py suite --depth 8 --timeout 120
```

The aggregate metric command reads the candidate-level verdicts under
`Result/`. The CSV files under `reports/` are retained as detailed audit
records and are not required by the aggregate reproduction command.
