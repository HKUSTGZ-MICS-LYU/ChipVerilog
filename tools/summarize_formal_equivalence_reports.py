#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


ATTEMPT_RE = re.compile(r"_t(?P<attempt>\d+)\.v$")


def parse_attempt(candidate_file: str) -> int | None:
    match = ATTEMPT_RE.search(candidate_file)
    if match is None:
        return None
    return int(match.group("attempt"))


def discover_report_files(report_dir: Path) -> list[Path]:
    return sorted(
        path
        for path in report_dir.glob("*.json")
        if not path.name.endswith("_summary.json")
    )


def build_flat_rows(report_files: list[Path]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for report_file in report_files:
        payload = json.loads(report_file.read_text(encoding="utf-8"))
        module_dir = payload["module_dir"]
        for result in payload["results"]:
            candidate_file = str(result["candidate_file"])
            rows.append(
                {
                    "module_dir": module_dir,
                    "model": result["model"],
                    "attempt": parse_attempt(candidate_file),
                    "candidate_file": candidate_file,
                    "candidate_name": Path(candidate_file).name,
                    "reference_file": result["reference_file"],
                    "reference_top": result["reference_top"],
                    "candidate_top": result["candidate_top"],
                    "reference_precheck": result["reference_precheck"],
                    "candidate_precheck": result["candidate_precheck"],
                    "interface_status": result["interface_status"],
                    "formal_status": result["formal_status"],
                    "proof_type": result["proof_type"],
                    "reason": result["reason"],
                    "counterexample_summary": result.get("counterexample_summary", ""),
                }
            )
    return rows


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "module_dir",
        "model",
        "attempt",
        "candidate_name",
        "candidate_file",
        "reference_file",
        "reference_top",
        "candidate_top",
        "reference_precheck",
        "candidate_precheck",
        "interface_status",
        "formal_status",
        "proof_type",
        "reason",
        "counterexample_summary",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def nested_counts(rows: list[dict[str, object]], first: str, second: str) -> dict[str, dict[str, int]]:
    counts: dict[str, Counter[str]] = defaultdict(Counter)
    for row in rows:
        counts[str(row[first])][str(row[second])] += 1
    return {
        key: dict(sorted(counter.items()))
        for key, counter in sorted(counts.items(), key=lambda item: item[0])
    }


def build_summary(rows: list[dict[str, object]], report_files: list[Path]) -> dict[str, object]:
    overall_formal = Counter(str(row["formal_status"]) for row in rows)
    overall_interface = Counter(str(row["interface_status"]) for row in rows)

    equivalent_rows = [
        {
            "module_dir": row["module_dir"],
            "model": row["model"],
            "attempt": row["attempt"],
            "candidate_name": row["candidate_name"],
        }
        for row in rows
        if row["formal_status"] == "equivalent"
    ]
    skipped_rows = [
        {
            "module_dir": row["module_dir"],
            "model": row["model"],
            "attempt": row["attempt"],
            "candidate_name": row["candidate_name"],
            "reason": row["reason"],
        }
        for row in rows
        if row["formal_status"] == "skip"
    ]
    failing_rows = [
        {
            "module_dir": row["module_dir"],
            "model": row["model"],
            "attempt": row["attempt"],
            "candidate_name": row["candidate_name"],
            "reason": row["reason"],
            "counterexample_summary": row["counterexample_summary"],
        }
        for row in rows
        if row["formal_status"] == "not_equivalent"
    ]
    tool_limited_rows = [
        {
            "module_dir": row["module_dir"],
            "model": row["model"],
            "attempt": row["attempt"],
            "candidate_name": row["candidate_name"],
            "reason": row["reason"],
        }
        for row in rows
        if row["formal_status"] == "tool_limited"
    ]

    return {
        "report_file_count": len(report_files),
        "total_rows": len(rows),
        "overall_formal_counts": dict(sorted(overall_formal.items())),
        "overall_interface_counts": dict(sorted(overall_interface.items())),
        "formal_counts_by_module": nested_counts(rows, "module_dir", "formal_status"),
        "formal_counts_by_model": nested_counts(rows, "model", "formal_status"),
        "formal_counts_by_attempt": nested_counts(rows, "attempt", "formal_status"),
        "equivalent_candidates": equivalent_rows,
        "skipped_candidates": skipped_rows,
        "not_equivalent_candidates": failing_rows,
        "tool_limited_candidates": tool_limited_rows,
    }


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(
        description="Flatten per-module formal equivalence JSON reports into detailed per-candidate reports."
    )
    parser.add_argument(
        "--report-dir",
        type=Path,
        default=repo_root / "reports" / "formal_equivalence_suite",
    )
    parser.add_argument(
        "--detail-csv",
        type=Path,
        default=repo_root / "reports" / "formal_equivalence_suite_detailed.csv",
    )
    parser.add_argument(
        "--summary-json",
        type=Path,
        default=repo_root / "reports" / "formal_equivalence_suite_detailed_summary.json",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report_files = discover_report_files(args.report_dir.resolve())
    if not report_files:
        raise SystemExit(f"No report JSON files found in {args.report_dir}")

    rows = build_flat_rows(report_files)
    rows.sort(
        key=lambda row: (
            str(row["module_dir"]),
            str(row["model"]),
            -1 if row["attempt"] is None else int(row["attempt"]),
        )
    )

    write_csv(args.detail_csv.resolve(), rows)
    summary = build_summary(rows, report_files)
    args.summary_json.resolve().write_text(
        json.dumps(summary, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print(f"Detailed CSV written to {args.detail_csv.resolve()}")
    print(f"Detailed summary written to {args.summary_json.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
