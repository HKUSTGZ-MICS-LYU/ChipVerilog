# ChipVerilog

ChipVerilog is a benchmark for Verilog generation with language models.
It contains 64 tasks from five design families.

[Paper](https://arxiv.org/abs/2607.13079)

## Files

| Path | Contents |
| --- | --- |
| `Src/` | Original designs and task descriptions |
| `Des/` | Reference RTL |
| `Result/` | Generated candidates and verification results |
| `tools/` | Generation and verification scripts |
| `run_codex_batch_txt.sh` | GPT generation script |

## Requirements

For verification, install Python 3, Icarus Verilog, and Yosys.

For GPT generation, install Bash, curl, and jq.

## Check the Results

Check one task:

```bash
python3 tools/formal_equivalence.py verify Result/codex/cordic
```

Check all tasks for one model:

```bash
python3 tools/formal_equivalence.py suite --model codex
```

The tools save reports in `reports/`.

## Generate Candidates

Set the model API key.
See the configuration examples in the script.

The default model is `gpt-5.4`.
The script makes five separate API requests for each task.
It does not use verification feedback or iterative refinement.

Preview the tasks:

```bash
bash run_codex_batch_txt.sh --dry-run
```

Generate candidates for one task:

```bash
bash run_codex_batch_txt.sh --modules cordic --samples 5
```

The script saves candidates in `Result/codex/`.
It saves logs in `.codex_batch_logs/`.
It skips existing nonempty files.

Use `--help` to see more options.

## License

See [LICENSE](LICENSE) and
[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
