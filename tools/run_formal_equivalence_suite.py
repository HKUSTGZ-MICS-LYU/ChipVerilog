#!/usr/bin/env python3
from __future__ import annotations

import argparse
import concurrent.futures
import csv
import json
import shutil
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path


def discover_modules(root: Path) -> list[str]:
    return sorted(path.name for path in root.iterdir() if path.is_dir())


def run_module_check(
    repo_root: Path,
    checker: Path,
    reference_dir: Path,
    result_root: Path,
    module_dir: str,
    report_dir: Path,
    timeout: int,
    depth: int,
) -> tuple[int, Path, str]:
    report_path = report_dir / f"{module_dir}.json"
    csv_path = report_dir / f"{module_dir}.csv"
    cmd = [
        sys.executable,
        str(checker),
        "--reference",
        str(reference_dir / module_dir),
        "--candidates",
        str(result_root),
        "--module-dir",
        module_dir,
        "--timeout",
        str(timeout),
        "--depth",
        str(depth),
        "--report",
        str(report_path),
        "--csv-report",
        str(csv_path),
    ]
    completed = subprocess.run(cmd, cwd=repo_root, text=True, capture_output=True, check=False)
    output = (completed.stdout or "") + (completed.stderr or "")
    cleaned_lines = [
        line for line in output.splitlines() if line.strip() and "setlocale: LC_ALL" not in line
    ]
    return completed.returncode, report_path, "\n".join(cleaned_lines)


def write_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "family",
        "module_dir",
        "total_candidates",
        "equivalent",
        "not_equivalent",
        "skip",
        "tool_limited",
        "compatible",
        "incompatible",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(
        description="Run the per-module formal equivalence checker across multiple modules."
    )
    parser.add_argument(
        "--double-root",
        type=Path,
        default=repo_root / "Src" / "double_fpu" / "des" / "verilog",
    )
    parser.add_argument(
        "--or1200-root",
        type=Path,
        default=repo_root / "Src" / "or1200_hp" / "des" / "verilog",
    )
    parser.add_argument(
        "--result-root",
        type=Path,
        default=repo_root / "Result",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=["fpu_add"],
        help="Module directory to skip. Can be used multiple times.",
    )
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--depth", type=int, default=8)
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument(
        "--report-dir",
        type=Path,
        default=repo_root / "reports" / "formal_equivalence_suite",
    )
    parser.add_argument(
        "--summary-json",
        type=Path,
        default=repo_root / "reports" / "formal_equivalence_suite_summary.json",
    )
    parser.add_argument(
        "--summary-csv",
        type=Path,
        default=repo_root / "reports" / "formal_equivalence_suite_summary.csv",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parent.parent
    checker = repo_root / "tools" / "check_formal_equivalence_batch.py"
    detail_summarizer = repo_root / "tools" / "summarize_formal_equivalence_reports.py"
    if not checker.exists():
        print(f"Missing checker script: {checker}", file=sys.stderr)
        return 2
    if not detail_summarizer.exists():
        print(f"Missing detail summarizer script: {detail_summarizer}", file=sys.stderr)
        return 2

    excludes = set(args.exclude)
    double_modules = [name for name in discover_modules(args.double_root) if name not in excludes]
    or1200_modules = [name for name in discover_modules(args.or1200_root) if name not in excludes]

    plan = [("double_fpu", module) for module in double_modules] + [
        ("or1200", module) for module in or1200_modules
    ]

    module_report_dir = args.report_dir.resolve()
    module_report_dir.mkdir(parents=True, exist_ok=True)

    module_summaries: list[dict[str, object]] = []
    flat_rows: list[dict[str, object]] = []
    overall_formal = Counter()
    overall_interface = Counter()
    family_formal: dict[str, Counter[str]] = defaultdict(Counter)
    model_formal: dict[str, Counter[str]] = defaultdict(Counter)

    exit_code = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as executor:
        future_map = {}
        for family, module_dir in plan:
            reference_root = args.double_root if family == "double_fpu" else args.or1200_root
            future = executor.submit(
                run_module_check,
                repo_root=repo_root,
                checker=checker,
                reference_dir=reference_root.resolve(),
                result_root=args.result_root.resolve(),
                module_dir=module_dir,
                report_dir=module_report_dir,
                timeout=args.timeout,
                depth=args.depth,
            )
            future_map[future] = (family, module_dir)

        for future in concurrent.futures.as_completed(future_map):
            family, module_dir = future_map[future]
            rc, report_path, output = future.result()
            if output:
                print(output)
            if rc not in {0, 1}:
                exit_code = rc

            report = json.loads(report_path.read_text(encoding="utf-8"))
            module_summary = {
                "family": family,
                "module_dir": module_dir,
                "reference_file": report["reference_file"],
                "total_candidates": report["total_candidates"],
                "counts": report["counts"],
                "interface_counts": report["interface_counts"],
                "model_counts": report["model_counts"],
                "report_json": str(report_path),
                "report_csv": str(report_path.with_suffix(".csv")),
            }
            module_summaries.append(module_summary)

            row = {
                "family": family,
                "module_dir": module_dir,
                "total_candidates": report["total_candidates"],
                "equivalent": report["counts"].get("equivalent", 0),
                "not_equivalent": report["counts"].get("not_equivalent", 0),
                "skip": report["counts"].get("skip", 0),
                "tool_limited": report["counts"].get("tool_limited", 0),
                "compatible": report["interface_counts"].get("compatible", 0),
                "incompatible": report["interface_counts"].get("incompatible", 0),
            }
            flat_rows.append(row)

            for result in report["results"]:
                overall_formal[result["formal_status"]] += 1
                overall_interface[result["interface_status"]] += 1
                family_formal[family][result["formal_status"]] += 1
                model_formal[result["model"]][result["formal_status"]] += 1

    summary = {
        "double_root": str(args.double_root.resolve()),
        "or1200_root": str(args.or1200_root.resolve()),
        "result_root": str(args.result_root.resolve()),
        "excluded_modules": sorted(excludes),
        "depth": args.depth,
        "timeout": args.timeout,
        "module_count": len(plan),
        "module_summaries": module_summaries,
        "overall_formal_counts": dict(sorted(overall_formal.items())),
        "overall_interface_counts": dict(sorted(overall_interface.items())),
        "formal_counts_by_family": {
            key: dict(sorted(counter.items()))
            for key, counter in sorted(family_formal.items(), key=lambda item: item[0])
        },
        "formal_counts_by_model": {
            key: dict(sorted(counter.items()))
            for key, counter in sorted(model_formal.items(), key=lambda item: item[0])
        },
    }

    write_json(args.summary_json.resolve(), summary)
    write_csv(args.summary_csv.resolve(), flat_rows)
    print(f"Suite summary written to {args.summary_json.resolve()}")
    print(f"Suite CSV written to {args.summary_csv.resolve()}")

    detail_csv = args.summary_csv.resolve().with_name("formal_equivalence_suite_detailed.csv")
    detail_json = args.summary_json.resolve().with_name("formal_equivalence_suite_detailed_summary.json")
    summarize_cmd = [
        sys.executable,
        str(detail_summarizer),
        "--report-dir",
        str(module_report_dir),
        "--detail-csv",
        str(detail_csv),
        "--summary-json",
        str(detail_json),
    ]
    completed = subprocess.run(
        summarize_cmd,
        cwd=repo_root,
        text=True,
        capture_output=True,
        check=False,
    )
    summarize_output = (completed.stdout or "") + (completed.stderr or "")
    cleaned_lines = [
        line for line in summarize_output.splitlines() if line.strip() and "setlocale: LC_ALL" not in line
    ]
    if cleaned_lines:
        print("\n".join(cleaned_lines))
    if completed.returncode != 0 and exit_code in {0, 1}:
        exit_code = completed.returncode

    if exit_code not in {0, 1}:
        return exit_code
    return 0 if overall_formal.get("not_equivalent", 0) == 0 and overall_formal.get("skip", 0) == 0 and overall_formal.get("tool_limited", 0) == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
