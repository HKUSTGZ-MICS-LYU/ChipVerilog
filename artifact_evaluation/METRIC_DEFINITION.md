# Metric definition

The reported table is computed over 64 benchmark tasks for each model, with
five cached candidates per task. The metric input is the candidate-level
`result.json` file stored under:

```text
Result/<model>/<task>/<candidate>/result.json
```

For syntax pass@k, a candidate passes when `compile_gate_status` is `pass`.
The compile gate invokes Icarus Verilog and requires successful compilation
and elaboration of the expected top module.

For functional pass@k, a candidate passes only when `status` is `pass`.
Depending on the task, this verdict is produced by a self-checking simulation
or the equivalence flow. Compile failures, functional failures, interface
failures, reference failures, elaboration failures, timeouts, and tool errors
do not count as functional passes.

For a task with `n = 5` candidates and `c` passing candidates, pass@k uses the
standard unbiased estimator:

```text
pass@k = 1 - C(n-c, k) / C(n, k)
```

The final value is the macro-average of the 64 per-task values. Percentages
are rounded to two decimal places using round-half-up. The reproduction script
also verifies that all three models contain the same 64 tasks and attempts
1 through 5 for every task.
