# Artifact access

- Paper: *ChipVerilog: A Large-Scale OpenCores-Derived Benchmark for
  LLM-Based Verilog RTL Generation*
- Zenodo snapshot: <https://doi.org/10.5281/zenodo.21583114>
- Live repository: <https://github.com/HKUSTGZ-MICS-LYU/ChipVerilog>

The artifact is public and needs no account, password, API key, commercial
license, PDK, or GPU. Reviewers evaluate the cached candidates; hosted-model
regeneration is not required.

From the extracted repository root, run:

```bash
bash artifact_evaluation/smoke_test.sh
python3 artifact_evaluation/reproduce_metrics.py
```

Tool versions and the exact functional-pass definition are in
`artifact_evaluation/environment.yml` and
`artifact_evaluation/METRIC_DEFINITION.md`.
