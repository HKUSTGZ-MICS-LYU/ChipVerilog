#!/usr/bin/env python3
"""Recompute the paper metrics from the cached candidate verdicts."""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import defaultdict
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import Dict, List, Mapping, Sequence


ROOT = Path(__file__).resolve().parents[1]
MODELS = ("claude", "codex", "deepseek")
DISPLAY_NAMES = {
    "claude": "Claude Opus 4.5",
    "codex": "GPT-5.4",
    "deepseek": "DeepSeek V4 Pro",
}
TOTAL_TASKS = 64
SAMPLES_PER_TASK = 5


def pass_at_k(n: int, c: int, k: int) -> float:
    """Standard unbiased pass@k estimator."""
    if n < k:
        raise ValueError(f"pass@{k} is undefined for n={n}")
    if not 0 <= c <= n:
        raise ValueError(f"invalid pass count c={c} for n={n}")
    if n - c < k:
        return 1.0
    return 1.0 - math.comb(n - c, k) / math.comb(n, k)


def percent(value: float) -> float:
    return float(
        Decimal(str(value * 100)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    )


def group_by_task(
    rows: Sequence[Mapping[str, object]],
) -> Dict[str, List[Mapping[str, object]]]:
    grouped: Dict[str, List[Mapping[str, object]]] = defaultdict(list)
    for row in rows:
        grouped[str(row["module_dir"])].append(row)
    return grouped


def load_candidate_results() -> Dict[str, List[dict]]:
    """Load and validate the 64 tasks x 5 cached verdicts for every model."""
    results: Dict[str, List[dict]] = {}
    task_sets = {}

    for model in MODELS:
        rows = []
        seen = set()
        model_root = ROOT / "Result" / model
        for path in sorted(model_root.glob("*/*/result.json")):
            with path.open(encoding="utf-8") as stream:
                row = json.load(stream)

            if row.get("model") != model:
                raise ValueError(f"model mismatch in {path}: {row.get('model')!r}")
            module = str(row.get("module_dir", ""))
            attempt = str(row.get("attempt", ""))
            key = (module, attempt)
            if not module or key in seen:
                raise ValueError(f"invalid or duplicate candidate key {key!r} in {path}")
            if row.get("compile_gate_status") not in {"pass", "fail"}:
                raise ValueError(f"invalid compile verdict in {path}")
            if not row.get("status"):
                raise ValueError(f"missing functional verdict in {path}")
            seen.add(key)
            rows.append(row)

        grouped = group_by_task(rows)
        if len(grouped) != TOTAL_TASKS:
            raise ValueError(
                f"{model}: expected {TOTAL_TASKS} tasks, found {len(grouped)}"
            )
        expected_attempts = {str(i) for i in range(1, SAMPLES_PER_TASK + 1)}
        for module, task_rows in grouped.items():
            attempts = {str(row["attempt"]) for row in task_rows}
            if len(task_rows) != SAMPLES_PER_TASK or attempts != expected_attempts:
                raise ValueError(
                    f"{model}/{module}: expected attempts 1-{SAMPLES_PER_TASK}, "
                    f"found {sorted(attempts)}"
                )

        results[model] = rows
        task_sets[model] = set(grouped)

    reference_tasks = task_sets[MODELS[0]]
    for model in MODELS[1:]:
        if task_sets[model] != reference_tasks:
            missing = sorted(reference_tasks - task_sets[model])
            extra = sorted(task_sets[model] - reference_tasks)
            raise ValueError(f"{model}: task-set mismatch; missing={missing}, extra={extra}")

    return results


def task_metric(
    rows: Sequence[Mapping[str, object]],
    pass_field: str,
    pass_value: str,
    k: int,
) -> float:
    values = []
    for task_rows in group_by_task(rows).values():
        n = len(task_rows)
        c = sum(row.get(pass_field) == pass_value for row in task_rows)
        values.append(pass_at_k(n, c, k))
    return sum(values) / len(values)


def compute_results() -> Dict[str, Dict[str, float]]:
    candidate_results = load_candidate_results()
    results: Dict[str, Dict[str, float]] = {}
    for model in MODELS:
        rows = candidate_results[model]
        results[model] = {
            "syntax_pass_at_1": percent(
                task_metric(rows, "compile_gate_status", "pass", 1)
            ),
            "syntax_pass_at_5": percent(
                task_metric(rows, "compile_gate_status", "pass", 5)
            ),
            "function_pass_at_1": percent(task_metric(rows, "status", "pass", 1)),
            "function_pass_at_5": percent(task_metric(rows, "status", "pass", 5)),
        }
    return results


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Print JSON output.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    results = compute_results()

    if args.json:
        print(json.dumps(results, indent=2, sort_keys=True))
    else:
        print(f"REPRODUCED RESULTS ({TOTAL_TASKS} tasks x {SAMPLES_PER_TASK} samples/model)")
        print("model,syntax_pass@1,syntax_pass@5,function_pass@1,function_pass@5")
        for model in MODELS:
            row = results[model]
            print(
                f"{DISPLAY_NAMES[model]},{row['syntax_pass_at_1']:.2f},"
                f"{row['syntax_pass_at_5']:.2f},{row['function_pass_at_1']:.2f},"
                f"{row['function_pass_at_5']:.2f}"
            )
    return 0


if __name__ == "__main__":
    sys.exit(main())
