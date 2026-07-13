#!/usr/bin/env python3
"""Recompute corrected cross-model comparison tables from the shipped suite reports.

This does NOT re-run any verification. It reclassifies the rows of
reports/formal_equivalence_suite_detailed.csv to correct known validity issues:

1. Drops the verilog_cordic_core family: its reference designs cannot be
   elaborated by yosys and its testbench does not compile, so no functional
   check ever ran for any model there.
2. Restricts to the 62-task intersection shared by all models (claude/codex
   are missing fpu_addsub_pipeline and fpu_mul_pipeline), so denominators
   are identical.
3. Splits simulation passes into "checked" (self-checking testbench) and
   "unchecked" (print-only testbench: passing only means the candidate
   compiled and ran without crashing). Unchecked passes are excluded from
   the corrected functional score.
4. Splits equivalence passes into full proofs (combinational, unbounded SAT)
   and bounded checks (sat -seq K -set-init-zero), reported separately.
5. Reclassifies yosys timeouts (equivalence_exit_code == 124) from
   "function_fail" to "inconclusive": a solver timeout proves nothing.

Outputs (under reports/corrected/):
  corrected_summary_by_model.csv
  corrected_summary_by_model_family.csv
  corrected_row_classification.csv   (per-row category, for audit)
"""
from __future__ import annotations

import csv
import re
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DETAILED_CSV = REPO_ROOT / "reports" / "formal_equivalence_suite_detailed.csv"
OUT_DIR = REPO_ROOT / "reports" / "corrected"

# Reports were generated on the HPC host; remap paths so tb sources can be read locally.
PATH_PREFIX_RE = re.compile(r"^.*?/ChipVerilogSuite/")

EXCLUDED_FAMILIES = {"verilog_cordic_core"}
# Modules present only in Result/deepseek; excluded so all models share one task set.
NON_INTERSECTION_MODULES = {"fpu_addsub_pipeline", "fpu_mul_pipeline"}

STRING_LITERAL_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')
SELF_CHECK_TOKEN_RE = re.compile(r"fail|error|mismatch|wrong|incorrect", re.IGNORECASE)
# "... 0 errors" style success messages must not count as failure evidence,
# but a tb that *reports* an error count is self-checking either way.


def localize(path_text: str) -> Path | None:
    if not path_text:
        return None
    localized = PATH_PREFIX_RE.sub(str(REPO_ROOT) + "/", path_text)
    path = Path(localized)
    return path if path.exists() else None


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text = re.sub(r"//.*", "", text)
    return text


def tb_is_self_checking(tb_path: Path) -> bool:
    """A tb counts as self-checking iff some display/format string mentions
    fail/error/mismatch-style outcomes, i.e. it can express a verdict."""
    text = strip_comments(tb_path.read_text(errors="ignore"))
    for literal in STRING_LITERAL_RE.findall(text):
        if SELF_CHECK_TOKEN_RE.search(literal):
            return True
    return False


def classify_row(row: dict[str, str], tb_checking: dict[str, bool]) -> str:
    status = row["status"]
    flow = row["flow"]
    if status == "compile_fail":
        return "compile_fail"
    if flow == "simulation_tb":
        if status == "pass":
            checked = tb_checking.get(row["tb_file"], False)
            return "sim_pass_checked" if checked else "sim_pass_unchecked"
        return f"sim_{status}"
    if flow == "equivalence":
        if status == "pass":
            return "equiv_pass_full" if row["proof_type"] == "strict_comb" else "equiv_pass_bounded"
        if status == "function_fail" and row.get("equivalence_exit_code") == "124":
            return "equiv_inconclusive_timeout"
        return f"equiv_{status}"
    return f"{flow}_{status}"


def main() -> int:
    with DETAILED_CSV.open() as handle:
        rows = list(csv.DictReader(handle))

    tb_checking: dict[str, bool] = {}
    for row in rows:
        tb_file = row["tb_file"]
        if tb_file and tb_file not in tb_checking:
            local = localize(tb_file)
            tb_checking[tb_file] = tb_is_self_checking(local) if local else False

    kept: list[dict[str, str]] = []
    for row in rows:
        row["category"] = classify_row(row, tb_checking)
        row["excluded"] = ""
        if row["family"] in EXCLUDED_FAMILIES:
            row["excluded"] = "family_unmeasurable"
        elif row["module_dir"] in NON_INTERSECTION_MODULES:
            row["excluded"] = "not_in_intersection"
        else:
            kept.append(row)

    def summarize(bucket_rows: list[dict[str, str]]) -> dict[str, object]:
        total = len(bucket_rows)
        counts: dict[str, int] = defaultdict(int)
        for row in bucket_rows:
            counts[row["category"]] += 1
        compile_pass = sum(1 for row in bucket_rows if row["status"] != "compile_fail")
        sim_checked = counts["sim_pass_checked"]
        sim_unchecked = counts["sim_pass_unchecked"]
        eq_full = counts["equiv_pass_full"]
        eq_bounded = counts["equiv_pass_bounded"]
        timeouts = counts["equiv_inconclusive_timeout"]
        strict = sim_checked + eq_full
        corrected = strict + eq_bounded
        original = sim_checked + sim_unchecked + eq_full + eq_bounded
        return {
            "candidates": total,
            "compile_pass": compile_pass,
            "compile_rate": f"{compile_pass / total:.1%}" if total else "",
            "sim_pass_checked": sim_checked,
            "sim_pass_unchecked_excluded": sim_unchecked,
            "equiv_pass_full": eq_full,
            "equiv_pass_bounded_k8": eq_bounded,
            "equiv_inconclusive_timeout": timeouts,
            "function_pass_original": original,
            "function_pass_corrected": corrected,
            "corrected_rate": f"{corrected / total:.1%}" if total else "",
            "function_pass_strict": strict,
            "strict_rate": f"{strict / total:.1%}" if total else "",
        }

    by_model: dict[str, list[dict[str, str]]] = defaultdict(list)
    by_model_family: dict[tuple[str, str], list[dict[str, str]]] = defaultdict(list)
    for row in kept:
        by_model[row["model"]].append(row)
        by_model_family[(row["model"], row["family"])].append(row)

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    model_rows = []
    for model in sorted(by_model):
        model_rows.append({"model": model, **summarize(by_model[model])})
    model_fields = list(model_rows[0].keys())
    with (OUT_DIR / "corrected_summary_by_model.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=model_fields)
        writer.writeheader()
        writer.writerows(model_rows)

    family_rows = []
    for (model, family) in sorted(by_model_family):
        family_rows.append({"model": model, "family": family, **summarize(by_model_family[(model, family)])})
    family_fields = list(family_rows[0].keys())
    with (OUT_DIR / "corrected_summary_by_model_family.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=family_fields)
        writer.writeheader()
        writer.writerows(family_rows)

    audit_fields = ["model", "family", "module_dir", "attempt", "flow", "status", "proof_type", "equivalence_exit_code", "category", "excluded"]
    with (OUT_DIR / "corrected_row_classification.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=audit_fields)
        writer.writeheader()
        for row in rows:
            writer.writerow({name: row.get(name, "") for name in audit_fields})

    tb_note = {tb: checked for tb, checked in sorted(tb_checking.items())}
    print("testbench self-checking classification:")
    for tb, checked in tb_note.items():
        print(f"  {'SELF-CHECKING' if checked else 'PRINT-ONLY   '} {PATH_PREFIX_RE.sub('', tb)}")
    print()
    header = f"{'model':10s} {'N':>4s} {'compile':>8s} {'simchk':>6s} {'simUNC':>6s} {'eqFULL':>6s} {'eqK8':>5s} {'tmo':>4s} {'orig':>5s} {'corr':>5s} {'strict':>6s}"
    print(header)
    for row in model_rows:
        print(
            f"{row['model']:10s} {row['candidates']:>4d} {row['compile_pass']:>4d}/{row['compile_rate']:<4s}"
            f" {row['sim_pass_checked']:>5d} {row['sim_pass_unchecked_excluded']:>6d} {row['equiv_pass_full']:>6d}"
            f" {row['equiv_pass_bounded_k8']:>5d} {row['equiv_inconclusive_timeout']:>4d}"
            f" {row['function_pass_original']:>5d} {row['function_pass_corrected']:>5d} {row['function_pass_strict']:>6d}"
        )
    print(f"\nwrote {OUT_DIR}/corrected_summary_by_model.csv, corrected_summary_by_model_family.csv, corrected_row_classification.csv")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
