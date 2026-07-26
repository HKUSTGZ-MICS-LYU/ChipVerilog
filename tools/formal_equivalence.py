#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import re
import shutil
import subprocess
import sys
import time
from collections import Counter, defaultdict
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Iterable, Sequence

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_RESULT_ROOT = REPO_ROOT / "Result"
DEFAULT_REPORT_DIR = REPO_ROOT / "reports" / "function_result" / "formal_equivalence_suite"
DEFAULT_SUMMARY_JSON = REPO_ROOT / "reports" / "formal_equivalence_suite_summary.json"
DEFAULT_SUMMARY_CSV = REPO_ROOT / "reports" / "formal_equivalence_suite_summary.csv"
DEFAULT_DETAILED_CSV = REPO_ROOT / "reports" / "formal_equivalence_suite_detailed.csv"
DEFAULT_DETAILED_SUMMARY_JSON = REPO_ROOT / "reports" / "formal_equivalence_suite_detailed_summary.json"
DEFAULT_COMPILE_CSV = REPO_ROOT / "reports" / "compile_suite" / "compile_results.csv"
DEFAULT_SYNTAX_DETAIL_CSV = REPO_ROOT / "reports" / "syntax_result" / "result_detail.csv"
DEFAULT_SYNTAX_MODEL_CSV = REPO_ROOT / "reports" / "syntax_result" / "result_summary_by_model.csv"
DEFAULT_SYNTAX_MODEL_MODULE_CSV = REPO_ROOT / "reports" / "syntax_result" / "result_summary_by_model_module.csv"
DEFAULT_SUITE_LOG = REPO_ROOT / "logs" / "formal" / "suite.log"
DEFAULT_IVERILOG = shutil.which("iverilog") or "iverilog"
DEFAULT_VVP = shutil.which("vvp") or "vvp"
DEFAULT_YOSYS = shutil.which("yosys") or "yosys"
STATUS_VALUES = [
    "pass",
    "compile_fail",
    "simulation_runtime_fail",
    "function_fail",
    "reference_fail",
    "elaboration_fail",
    "interface_fail",
    "equivalence_timeout",
    "equivalence_error",
]
DETAIL_FIELDS = [
    "model",
    "family",
    "module_dir",
    "attempt",
    "candidate_name",
    "candidate_file",
    "reference_file",
    "reference_top",
    "candidate_top",
    "flow",
    "status",
    "proof_type",
    "tb_file",
    "tb_top",
    "tb_self_checking",
    "artifact_dir",
    "reason",
    "reference_precheck",
    "candidate_precheck",
    "interface_status",
    "formal_status",
    "reason_bucket",
    "interface_reason_kind",
    "interface_reason",
    "interface_aliases_applied",
    "counterexample_summary",
    "generated_stub_modules",
    "compile_gate_status",
    "compile_gate_exit_code",
    "compile_gate_warning_count",
    "compile_gate_warning_excerpt",
    "compile_gate_error_excerpt",
    "simulation_exit_code",
    "equivalence_exit_code",
]
COMPILE_FIELDS = [
    "model",
    "family",
    "module_dir",
    "attempt",
    "candidate_file",
    "reference_file",
    "expected_top",
    "status",
    "exit_code",
    "warning_count",
    "warning_excerpt",
    "error_excerpt",
]
SUMMARY_FIELDS = [
    "model",
    "module_dir",
    "compile_pass",
    "function_pass",
    "simulation_pass",
    "equivalence_pass",
    "equivalence_pass_full",
    "equivalence_pass_bounded",
]
REPORT_FAMILY_NAMES = {"cordic_core": "verilog_cordic_core"}
PREFIX_PRIORITY = {"timescale.v": 0}
VERILOG_SUFFIXES = {".v", ".sv", ".vh", ".inc"}
ASSET_EXCLUDE_SUFFIXES = {".v", ".sv", ".vh", ".inc", ".log", ".out", ".bak"}
KEYWORD_MODULE_NAMES = {
    "module",
    "if",
    "else",
    "for",
    "while",
    "case",
    "casex",
    "casez",
    "endcase",
    "assign",
    "always",
    "always_comb",
    "always_ff",
    "always_latch",
    "initial",
    "begin",
    "end",
    "fork",
    "join",
    "join_any",
    "join_none",
    "input",
    "output",
    "inout",
    "wire",
    "reg",
    "logic",
    "parameter",
    "localparam",
    "generate",
    "endgenerate",
    "genvar",
    "function",
    "endfunction",
    "task",
    "endtask",
    "default",
    "forever",
    "repeat",
    "wait",
}
PRIMITIVE_MODULE_NAMES = {
    "and",
    "nand",
    "nor",
    "not",
    "or",
    "xor",
    "xnor",
    "buf",
    "bufif0",
    "bufif1",
    "notif0",
    "notif1",
    "nmos",
    "pmos",
    "rnmos",
    "rpmos",
    "tran",
    "rtran",
    "tranif0",
    "tranif1",
    "rtranif0",
    "rtranif1",
    "pullup",
    "pulldown",
    "cmos",
    "rcmos",
}
MODULE_RE = re.compile(r"(?m)^\s*module\s+([A-Za-z_][A-Za-z0-9_$]*)\b")
INCLUDE_RE = re.compile(r'(?m)^\s*`include\s+"([^"]+)"')
INSTANCE_RE = re.compile(
    r"(?m)^\s*([A-Za-z_][A-Za-z0-9_$]*)\s*(?:#\s*\([^;]*?\))?\s+([A-Za-z_][A-Za-z0-9_$]*)\s*\(",
    re.MULTILINE,
)
INSTANCE_BODY_RE = re.compile(
    r"(?ms)([A-Za-z_][A-Za-z0-9_$]*)\s*(?:#\s*\([^;]*?\))?\s+([A-Za-z_][A-Za-z0-9_$]*)\s*\((.*?)\)\s*;"
)
SIM_FAIL_RE = re.compile(r"(FAIL|ERROR|MISMATCH)", re.IGNORECASE)
NEGATED_FAIL_RE = re.compile(
    r"\b(?:no|0|zero)\s+(?:errors?|failures?|mismatch(?:es)?)\b"
    r"|\b(?:errors?|failures?|mismatch(?:es)?)\s*[:=]\s*0\b",
    re.IGNORECASE,
)
STRING_LITERAL_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')
SELF_CHECK_TOKEN_RE = re.compile(r"fail|error|mismatch|wrong|incorrect", re.IGNORECASE)
EVENT_RE = re.compile(r"\b(?:posedge|negedge)\b")
DECL_BLOCK_RE = re.compile(r"(?m)^\s*(input|output|inout|wire|reg|logic)\b(.*?);", re.DOTALL)
NUMBER_RE = re.compile(r"^\d+$")


@dataclass
class CommandResult:
    command: list[str]
    exit_code: int
    stdout: str
    stderr: str
    timed_out: bool = False

    @property
    def combined_output(self) -> str:
        if self.stdout and self.stderr:
            return f"{self.stdout.rstrip()}\n{self.stderr.rstrip()}\n"
        return self.stdout or self.stderr or ""


@dataclass
class PortInfo:
    name: str
    direction: str
    width: int


@dataclass
class TestbenchInfo:
    path: Path
    top: str
    includes_reference: bool
    self_checking: bool = False


@dataclass
class CompileGateResult:
    passed: bool
    exit_code: int
    warning_count: int
    warning_excerpt: str
    error_excerpt: str
    log_text: str


@dataclass
class SimulationFlowResult:
    final_result: CandidateResult | None
    tb_compile_failed: bool = False
    tb_compile_reason: str = ""


@dataclass
class CandidateResult:
    model: str
    family: str
    module_dir: str
    attempt: str
    candidate_name: str
    candidate_file: str
    reference_file: str
    reference_top: str
    candidate_top: str
    flow: str
    status: str
    proof_type: str
    tb_file: str
    tb_top: str
    artifact_dir: str
    reason: str
    reference_precheck: str = "skip"
    candidate_precheck: str = "skip"
    interface_status: str = "skip"
    formal_status: str = "skip"
    reason_bucket: str = ""
    interface_reason_kind: str = ""
    interface_reason: str = ""
    interface_aliases_applied: list[str] = field(default_factory=list)
    counterexample_summary: str = ""
    generated_stub_modules: list[str] = field(default_factory=list)
    tb_self_checking: bool = False
    compile_gate_status: str = "fail"
    compile_gate_exit_code: int = 1
    compile_gate_warning_count: int = 0
    compile_gate_warning_excerpt: str = ""
    compile_gate_error_excerpt: str = ""
    simulation_exit_code: int | None = None
    equivalence_exit_code: int | None = None

    def to_row(self) -> dict[str, object]:
        row = asdict(self)
        row["reason_bucket"] = self.reason_bucket or self.status
        row["interface_aliases_applied"] = json.dumps(self.interface_aliases_applied)
        row["generated_stub_modules"] = json.dumps(self.generated_stub_modules)
        return row

    def syntax_row(self) -> dict[str, object]:
        return {
            "model": self.model,
            "family": self.family,
            "module_dir": self.module_dir,
            "attempt": self.attempt,
            "candidate_file": self.candidate_file,
            "reference_file": self.reference_file,
            "expected_top": self.reference_top,
            "status": self.compile_gate_status,
            "exit_code": self.compile_gate_exit_code,
            "warning_count": self.compile_gate_warning_count,
            "warning_excerpt": self.compile_gate_warning_excerpt,
            "error_excerpt": self.compile_gate_error_excerpt,
        }


@dataclass
class ModuleContext:
    result_root: Path
    model: str
    candidate_module_dir: Path
    module_dir_name: str
    des_module_dir: Path
    family_root: Path
    family_name: str
    report_family_name: str
    reference_file: Path
    reference_top: str
    tb_info: TestbenchInfo | None
    prefix_files: list[Path]
    same_dir_support: list[Path]
    base_include_dirs: list[Path]
    iverilog: str
    vvp: str
    yosys: str
    depth: int
    timeout: int
    artifacts_root: Path


@dataclass
class ModuleFileInfo:
    path: Path
    declared_modules: list[str]


@dataclass
class FamilyCache:
    family_root: Path
    files: list[ModuleFileInfo]
    module_to_files: dict[str, list[ModuleFileInfo]]


@dataclass
class StubPortSpec:
    direction: str
    width: int


@dataclass
class StubModuleSpec:
    name: str
    ports: dict[str, StubPortSpec]


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text = re.sub(r"//.*", "", text)
    return text


def read_text(path: Path) -> str:
    return path.read_text(errors="ignore")


def normalize_output_text(text: str | bytes | None) -> str:
    if text is None:
        return ""
    if isinstance(text, bytes):
        return text.decode(errors="ignore")
    return text


def run_command(command: Sequence[str], cwd: Path | None = None, timeout: int | None = None) -> CommandResult:
    try:
        completed = subprocess.run(
            list(command),
            cwd=str(cwd) if cwd else None,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
        return CommandResult(
            list(command),
            completed.returncode,
            normalize_output_text(completed.stdout),
            normalize_output_text(completed.stderr),
            False,
        )
    except subprocess.TimeoutExpired as exc:
        stdout = normalize_output_text(exc.stdout)
        stderr = normalize_output_text(exc.stderr)
        return CommandResult(list(command), 124, stdout, stderr, True)


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, text: str) -> None:
    ensure_parent(path)
    path.write_text(text)


def write_json(path: Path, data: object) -> None:
    ensure_parent(path)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def write_csv(path: Path, rows: Iterable[dict[str, object]], fieldnames: Sequence[str]) -> None:
    ensure_parent(path)
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({name: row.get(name, "") for name in fieldnames})


def now_string() -> str:
    return dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def emit_progress(message: str, log_file: Path | None = None, stream: object = sys.stdout) -> None:
    line = f"[{now_string()}] {message}"
    print(line, file=stream, flush=True)
    if log_file is not None:
        ensure_parent(log_file)
        with log_file.open("a") as handle:
            handle.write(line + "\n")


def format_status_counts(counts: Counter[str]) -> str:
    parts = [f"{status}={counts.get(status, 0)}" for status in STATUS_VALUES if counts.get(status, 0)]
    return ", ".join(parts) if parts else "no_results"


def pass_metrics(rows: Sequence[CandidateResult]) -> dict[str, int]:
    compile_pass = sum(1 for row in rows if row.status != "compile_fail")
    function_pass = sum(1 for row in rows if row.status == "pass")
    simulation_pass = sum(1 for row in rows if row.flow == "simulation_tb" and row.status == "pass")
    equivalence_pass_rows = [row for row in rows if row.flow == "equivalence" and row.status == "pass"]
    equivalence_pass_bounded = sum(1 for row in equivalence_pass_rows if row.proof_type == "bounded_seq")
    return {
        "compile_pass": compile_pass,
        "function_pass": function_pass,
        "simulation_pass": simulation_pass,
        "equivalence_pass": len(equivalence_pass_rows),
        "equivalence_pass_full": len(equivalence_pass_rows) - equivalence_pass_bounded,
        "equivalence_pass_bounded": equivalence_pass_bounded,
    }


def stable_path_list(paths: Iterable[Path]) -> list[Path]:
    seen: set[Path] = set()
    ordered: list[Path] = []
    for path in paths:
        resolved = path.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        ordered.append(path)
    return ordered


def module_names_in_file(path: Path) -> list[str]:
    text = strip_comments(read_text(path))
    return MODULE_RE.findall(text)


def include_targets(path: Path) -> list[str]:
    return INCLUDE_RE.findall(strip_comments(read_text(path)))


def instance_module_names(path: Path) -> list[str]:
    text = strip_comments(read_text(path))
    names: list[str] = []
    for module_name, _instance_name in INSTANCE_RE.findall(text):
        if module_name in KEYWORD_MODULE_NAMES or module_name in PRIMITIVE_MODULE_NAMES:
            continue
        names.append(module_name)
    return names


def instance_records(path: Path) -> list[tuple[str, str, list[tuple[str, str]]]]:
    text = strip_comments(read_text(path))
    records: list[tuple[str, str, list[tuple[str, str]]]] = []
    for module_name, instance_name, body in INSTANCE_BODY_RE.findall(text):
        if module_name in KEYWORD_MODULE_NAMES or module_name in PRIMITIVE_MODULE_NAMES:
            continue
        ports = re.findall(r"\.([A-Za-z_][A-Za-z0-9_$]*)\s*\((.*?)\)", body, flags=re.DOTALL)
        records.append((module_name, instance_name, [(name, expr.strip()) for name, expr in ports]))
    return records


def parse_numeric_width(range_text: str | None) -> int | None:
    if not range_text:
        return 1
    match = re.match(r"\[\s*(\d+)\s*:\s*(\d+)\s*\]", range_text)
    if not match:
        return None
    msb = int(match.group(1))
    lsb = int(match.group(2))
    return abs(msb - lsb) + 1


def parse_width_map(path: Path) -> dict[str, int]:
    text = strip_comments(read_text(path))
    widths: dict[str, int] = {}
    for _kind, body in DECL_BLOCK_RE.findall(text):
        body = re.sub(r"\b(?:signed|reg|wire|logic)\b", " ", body)
        width_match = re.search(r"(\[[^\]]+\])", body)
        width = parse_numeric_width(width_match.group(1) if width_match else None)
        cleaned = re.sub(r"\[[^\]]+\]", " ", body)
        for raw_name in cleaned.split(","):
            name = raw_name.strip()
            if not name:
                continue
            name = name.split("=")[0].strip()
            name = name.split()[-1]
            if re.match(r"^[A-Za-z_][A-Za-z0-9_$]*$", name):
                widths[name] = width or 1
    return widths


def constant_width(expr: str) -> int | None:
    match = re.match(r"\s*(\d+)'[bdhoBDHO][0-9a-fA-F_xXzZ]+\s*$", expr)
    if match:
        return int(match.group(1))
    if NUMBER_RE.match(expr.strip()):
        return max(1, int(expr.strip()).bit_length())
    return None


def infer_expr_width(expr: str, width_map: dict[str, int]) -> int | None:
    expr = expr.strip()
    if not expr:
        return None
    if expr.startswith("{") and expr.endswith("}"):
        inner = expr[1:-1].strip()
        if not inner:
            return None
        parts = [part.strip() for part in inner.split(",")]
        widths = [infer_expr_width(part, width_map) for part in parts]
        if any(width is None for width in widths):
            return None
        return sum(widths)  # type: ignore[arg-type]
    match = re.match(r"([A-Za-z_][A-Za-z0-9_$]*)\[(\d+):(\d+)\]$", expr)
    if match:
        msb = int(match.group(2))
        lsb = int(match.group(3))
        return abs(msb - lsb) + 1
    match = re.match(r"([A-Za-z_][A-Za-z0-9_$]*)\[(.+)\]$", expr)
    if match:
        return 1
    if expr in width_map:
        return width_map[expr]
    return constant_width(expr)


def attempt_from_name(filename: str) -> str:
    match = re.search(r"_t(\d+)\.v$", filename)
    if match:
        return match.group(1)
    return Path(filename).stem


def warning_count(text: str) -> int:
    return len(re.findall(r"warning:", text, flags=re.IGNORECASE))


def sim_failure_lines(text: str) -> list[str]:
    """Output lines that indicate functional failure, ignoring negated forms like '0 errors'."""
    lines = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line and SIM_FAIL_RE.search(line) and not NEGATED_FAIL_RE.search(line):
            lines.append(line)
    return lines


def tb_is_self_checking(tb_file: Path) -> bool:
    """A testbench counts as self-checking iff some display/format string can express
    a fail verdict; a print-only bench cannot produce a trustworthy pass."""
    text = strip_comments(read_text(tb_file))
    return any(SELF_CHECK_TOKEN_RE.search(literal) for literal in STRING_LITERAL_RE.findall(text))


def summarize_lines(text: str, patterns: Sequence[str], limit: int = 8) -> str:
    if not text:
        return ""
    lines = []
    regexes = [re.compile(pattern, re.IGNORECASE) for pattern in patterns]
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if any(regex.search(line) for regex in regexes):
            lines.append(line)
    if not lines:
        lines = [line.strip() for line in text.splitlines() if line.strip()][:limit]
    return " | ".join(lines[:limit])


def format_command(result: CommandResult) -> str:
    quoted = " ".join(shlex_quote(part) for part in result.command)
    return f"$ {quoted}\n"


def shlex_quote(text: str) -> str:
    return subprocess.list2cmdline([text]) if sys.platform == "win32" else __import__("shlex").quote(text)


def command_log(result: CommandResult, heading: str) -> str:
    stdout_text = normalize_output_text(result.stdout)
    stderr_text = normalize_output_text(result.stderr)
    chunks = [f"=== {heading} ===\n", format_command(result)]
    if stdout_text:
        chunks.append("--- stdout ---\n")
        chunks.append(stdout_text)
        if not stdout_text.endswith("\n"):
            chunks.append("\n")
    if stderr_text:
        chunks.append("--- stderr ---\n")
        chunks.append(stderr_text)
        if not stderr_text.endswith("\n"):
            chunks.append("\n")
    chunks.append(f"exit_code={result.exit_code}\n")
    if result.timed_out:
        chunks.append("timed_out=true\n")
    return "".join(chunks)


def derive_detailed_csv_path(summary_csv: Path) -> Path:
    if summary_csv.name.endswith("_summary.csv"):
        return summary_csv.with_name(summary_csv.name.replace("_summary.csv", "_detailed.csv"))
    return summary_csv.with_name(summary_csv.stem + "_detailed.csv")


def derive_detailed_summary_json_path(summary_json: Path) -> Path:
    if summary_json.name.endswith("_summary.json"):
        return summary_json.with_name(summary_json.name.replace("_summary.json", "_detailed_summary.json"))
    return summary_json.with_name(summary_json.stem + "_detailed_summary.json")


def family_cache_for(family_root: Path, caches: dict[Path, FamilyCache]) -> FamilyCache:
    family_root = family_root.resolve()
    cached = caches.get(family_root)
    if cached is not None:
        return cached
    file_infos: list[ModuleFileInfo] = []
    module_to_files: dict[str, list[ModuleFileInfo]] = defaultdict(list)
    for path in sorted(family_root.rglob("*.v")):
        info = ModuleFileInfo(path=path, declared_modules=module_names_in_file(path))
        file_infos.append(info)
        for name in info.declared_modules:
            module_to_files[name].append(info)
    cached = FamilyCache(family_root=family_root, files=file_infos, module_to_files=module_to_files)
    caches[family_root] = cached
    return cached


def all_des_module_dirs() -> list[Path]:
    return sorted(path for path in (REPO_ROOT / "Des").glob("*/*") if path.is_dir())


def resolve_des_module_dir(module_dir_name: str) -> Path | None:
    candidates = {path.name: path for path in all_des_module_dirs()}
    direct = candidates.get(module_dir_name)
    if direct is not None:
        return direct
    if module_dir_name.startswith("mips_"):
        mapped = candidates.get(module_dir_name[len("mips_") :])
        if mapped is not None and mapped.parent.name == "mips_16":
            return mapped
    return None


def discover_reference_file(des_module_dir: Path) -> Path:
    same_name = des_module_dir / f"{des_module_dir.name}.v"
    if same_name.exists():
        return same_name
    verilog_files = sorted(des_module_dir.glob("*.v"))
    if len(verilog_files) == 1:
        return verilog_files[0]
    raise ValueError(f"cannot resolve reference file for {des_module_dir}")


def prefix_files_for_family(family_root: Path) -> list[Path]:
    files = []
    for path in sorted(
        (p for p in family_root.iterdir() if p.is_file() and p.suffix.lower() in VERILOG_SUFFIXES),
        key=lambda p: (PREFIX_PRIORITY.get(p.name, 1), p.name),
    ):
        lowered = path.name.lower()
        if path.name == "timescale.v" or "defines" in lowered or "defs" in lowered:
            files.append(path)
    return files


def tb_score(name: str) -> int:
    lowered = name.lower()
    if lowered == "tb_top":
        return 100
    if lowered == "tb":
        return 90
    if "testbench" in lowered:
        return 80
    if lowered.startswith("tb") or "_tb" in lowered or lowered.endswith("tb"):
        return 70
    return 0


def classify_module_dir(des_module_dir: Path, reference_file: Path) -> tuple[TestbenchInfo | None, list[Path]]:
    verilog_files = sorted(des_module_dir.glob("*.v"))
    extras = [path for path in verilog_files if path != reference_file]
    if not extras:
        return None, []
    tb_candidates: list[tuple[int, Path, str]] = []
    same_dir_support: list[Path] = []
    reference_basename = reference_file.name
    for path in extras:
        modules = module_names_in_file(path)
        best = 0
        best_name = ""
        for module_name in modules:
            score = tb_score(module_name)
            if score > best:
                best = score
                best_name = module_name
        file_score = tb_score(path.stem)
        if file_score > best:
            best = file_score
            best_name = path.stem
        if best > 0:
            tb_candidates.append((best, path, best_name))
        else:
            same_dir_support.append(path)
    if not tb_candidates:
        return None, same_dir_support
    tb_candidates.sort(key=lambda item: (-item[0], item[1].name))
    tb_path = tb_candidates[0][1]
    tb_top = select_tb_top(tb_path)
    includes_reference = reference_basename in include_targets(tb_path)
    same_dir_support = [path for path in extras if path != tb_path]
    tb_info = TestbenchInfo(
        path=tb_path,
        top=tb_top,
        includes_reference=includes_reference,
        self_checking=tb_is_self_checking(tb_path),
    )
    return tb_info, same_dir_support


def select_tb_top(tb_file: Path) -> str:
    modules = module_names_in_file(tb_file)
    if not modules:
        raise ValueError(f"no module declarations found in testbench {tb_file}")
    ranked = sorted(modules, key=lambda name: (-tb_score(name), name))
    return ranked[0]


def resolve_reference_top(reference_file: Path, module_dir_name: str, tb_info: TestbenchInfo | None) -> str:
    reference_modules = module_names_in_file(reference_file)
    if not reference_modules:
        raise ValueError(f"no module declarations found in {reference_file}")
    if tb_info is not None:
        tb_instances = instance_module_names(tb_info.path)
        intersection = [name for name in tb_instances if name in reference_modules]
        if len(dict.fromkeys(intersection)) == 1:
            return intersection[0]
        if module_dir_name in intersection:
            return module_dir_name
    if module_dir_name in reference_modules:
        return module_dir_name
    if len(reference_modules) == 1:
        return reference_modules[0]
    raise ValueError(f"cannot resolve reference top for {reference_file}")


def reference_modules_defined(reference_file: Path) -> set[str]:
    return set(module_names_in_file(reference_file))


def select_support_file(
    missing_name: str,
    candidates: list[ModuleFileInfo],
    defined_modules: set[str],
    missing_modules: set[str],
) -> ModuleFileInfo | None:
    ranked: list[tuple[int, int, int, str, ModuleFileInfo]] = []
    for info in candidates:
        declared = set(info.declared_modules)
        if declared & defined_modules:
            continue
        basename_match = 0 if info.path.stem == missing_name else 1
        coverage = -len(declared & missing_modules)
        size = len(declared)
        ranked.append((basename_match, coverage, size, str(info.path), info))
    if not ranked:
        return None
    ranked.sort()
    return ranked[0][4]


def resolve_support_files_for(family_cache: FamilyCache, primary_files: Sequence[Path]) -> list[Path]:
    """Resolve Des support files for ONE design (gold or gate) independently, so a
    candidate's internal module names can never poison the reference build."""
    defined_modules: set[str] = set()
    for path in primary_files:
        defined_modules.update(module_names_in_file(path))
    selected: list[Path] = []
    pending_modules: set[str] = set()
    for path in primary_files:
        for name in instance_module_names(path):
            if name in defined_modules or name in PRIMITIVE_MODULE_NAMES:
                continue
            pending_modules.add(name)
    while pending_modules:
        missing_name = sorted(pending_modules)[0]
        pending_modules.remove(missing_name)
        if missing_name in defined_modules or missing_name in PRIMITIVE_MODULE_NAMES:
            continue
        info = select_support_file(
            missing_name,
            family_cache.module_to_files.get(missing_name, []),
            defined_modules,
            pending_modules | {missing_name},
        )
        if info is None:
            continue
        selected.append(info.path)
        defined_modules.update(info.declared_modules)
        for nested_name in instance_module_names(info.path):
            if nested_name in defined_modules or nested_name in PRIMITIVE_MODULE_NAMES:
                continue
            pending_modules.add(nested_name)
    primary_resolved = {path.resolve() for path in primary_files}
    return [path for path in stable_path_list(selected) if path.resolve() not in primary_resolved]


def unresolved_instance_modules(source_files: Sequence[Path]) -> list[str]:
    defined = set()
    for path in source_files:
        defined.update(module_names_in_file(path))
    missing = set()
    for path in source_files:
        for name in instance_module_names(path):
            if name in defined or name in PRIMITIVE_MODULE_NAMES:
                continue
            missing.add(name)
    return sorted(missing)


def infer_stub_direction(port_name: str) -> str:
    lowered = port_name.lower()
    if lowered in {"p", "doq", "doutb", "do_a", "do_b", "dpo", "spo", "dat_o", "full_o", "empty_o"}:
        return "output"
    if lowered.endswith("_o") or lowered.startswith("do") or lowered.startswith("dout") or lowered.startswith("q"):
        return "output"
    return "input"


def build_stub_specs(unresolved_modules: Sequence[str], source_files: Sequence[Path]) -> dict[str, StubModuleSpec]:
    specs: dict[str, StubModuleSpec] = {}
    missing_set = set(unresolved_modules)
    width_maps = {path: parse_width_map(path) for path in source_files}
    for path in source_files:
        for module_name, _instance_name, ports in instance_records(path):
            if module_name not in missing_set:
                continue
            spec = specs.setdefault(module_name, StubModuleSpec(module_name, {}))
            for port_name, expr in ports:
                direction = infer_stub_direction(port_name)
                width = infer_expr_width(expr, width_maps[path]) or 1
                current = spec.ports.get(port_name)
                if current is None:
                    spec.ports[port_name] = StubPortSpec(direction=direction, width=width)
                    continue
                if current.direction != "output" and direction == "output":
                    current.direction = direction
                current.width = max(current.width, width)
    return specs


def port_decl(name: str, direction: str, width: int, as_reg: bool = False) -> str:
    reg_text = " reg" if as_reg and direction == "output" else ""
    if width <= 1:
        return f"{direction}{reg_text} {name};"
    return f"{direction}{reg_text} [{width - 1}:0] {name};"


def render_zero_stub(spec: StubModuleSpec) -> str:
    ports = sorted(spec.ports)
    lines = [f"module {spec.name}({', '.join(ports)});"]
    output_ports = []
    for name in ports:
        port = spec.ports[name]
        lines.append(port_decl(name, port.direction, port.width, as_reg=False))
        if port.direction == "output":
            output_ports.append((name, port.width))
    for name, width in output_ports:
        zero = "1'b0" if width <= 1 else f"{width}'b0"
        lines.append(f"assign {name} = {zero};")
    lines.append("endmodule")
    return "\n".join(lines)


def render_rf_sub_stub(spec: StubModuleSpec) -> str:
    width_d = spec.ports.get("d", StubPortSpec("input", 32)).width
    width_a = spec.ports.get("a", StubPortSpec("input", 5)).width
    depth = max(2, 1 << min(width_a, 8))
    lines = [f"module {spec.name}(a, d, dpra, clk, we, spo, dpo);"]
    lines.append(port_decl("a", "input", width_a))
    lines.append(port_decl("d", "input", width_d))
    lines.append(port_decl("dpra", "input", spec.ports.get("dpra", StubPortSpec("input", width_a)).width))
    lines.append(port_decl("clk", "input", 1))
    lines.append(port_decl("we", "input", 1))
    lines.append(port_decl("spo", "output", spec.ports.get("spo", StubPortSpec("output", width_d)).width))
    lines.append(port_decl("dpo", "output", spec.ports.get("dpo", StubPortSpec("output", width_d)).width))
    lines.append(f"reg [{width_d - 1}:0] mem [0:{depth - 1}];")
    lines.append("always @(posedge clk) if (we) mem[a] <= d;")
    lines.append("assign spo = mem[a];")
    lines.append("assign dpo = mem[dpra];")
    lines.append("endmodule")
    return "\n".join(lines)


def render_single_ram_stub(spec: StubModuleSpec) -> str:
    width_addr = spec.ports.get("addr", StubPortSpec("input", 8)).width
    width_data = spec.ports.get("di", StubPortSpec("input", 32)).width
    width_out = spec.ports.get("doq", StubPortSpec("output", width_data)).width
    depth = max(2, 1 << min(width_addr, 10))
    ports = sorted(spec.ports)
    lines = [f"module {spec.name}({', '.join(ports)});"]
    for name in ports:
        port = spec.ports[name]
        lines.append(port_decl(name, port.direction, port.width, as_reg=(name == "doq")))
    lines.append(f"reg [{max(width_data, width_out) - 1}:0] mem [0:{depth - 1}];")
    lines.append("always @(posedge clk) begin")
    lines.append("  if (ce && we) mem[addr] <= di;")
    lines.append("  if (ce) doq <= mem[addr];")
    lines.append("end")
    lines.append("endmodule")
    return "\n".join(lines)


def render_dual_ram_stub(spec: StubModuleSpec) -> str:
    width_addra = spec.ports.get("addra", StubPortSpec("input", 8)).width
    width_dina = spec.ports.get("dina", StubPortSpec("input", 32)).width
    width_doutb = spec.ports.get("doutb", StubPortSpec("output", width_dina)).width
    depth = max(2, 1 << min(width_addra, 10))
    ports = sorted(spec.ports)
    lines = [f"module {spec.name}({', '.join(ports)});"]
    for name in ports:
        port = spec.ports[name]
        lines.append(port_decl(name, port.direction, port.width, as_reg=(name == "doutb")))
    lines.append(f"reg [{max(width_dina, width_doutb) - 1}:0] mem [0:{depth - 1}];")
    lines.append("always @(posedge clka) if (ena && wea) mem[addra] <= dina;")
    lines.append("always @(posedge clkb) doutb <= mem[addrb];")
    lines.append("endmodule")
    return "\n".join(lines)


def render_port_ab_ram_stub(spec: StubModuleSpec) -> str:
    width_a = spec.ports.get("addr_a", StubPortSpec("input", 8)).width
    width_di = spec.ports.get("di_b", StubPortSpec("input", 32)).width
    width_do = spec.ports.get("do_a", StubPortSpec("output", width_di)).width
    depth = max(2, 1 << min(width_a, 10))
    ports = sorted(spec.ports)
    lines = [f"module {spec.name}({', '.join(ports)});"]
    for name in ports:
        port = spec.ports[name]
        lines.append(port_decl(name, port.direction, port.width, as_reg=(name in {"do_a", "do_b"})))
    lines.append(f"reg [{max(width_di, width_do) - 1}:0] mem [0:{depth - 1}];")
    lines.append("always @(posedge clk_b) if (ce_b && we_b) mem[addr_b] <= di_b;")
    lines.append("always @(posedge clk_a) if (ce_a) do_a <= mem[addr_a];")
    if "do_b" in spec.ports:
        lines.append("always @(posedge clk_b) if (ce_b && !we_b) do_b <= mem[addr_b];")
    lines.append("endmodule")
    return "\n".join(lines)


def render_fifo_stub(spec: StubModuleSpec) -> str:
    width_data = spec.ports.get("dat_i", StubPortSpec("input", 32)).width
    ports = sorted(spec.ports)
    lines = [f"module {spec.name}({', '.join(ports)});"]
    for name in ports:
        port = spec.ports[name]
        as_reg = name in {"dat_o", "full_o", "empty_o"}
        lines.append(port_decl(name, port.direction, port.width, as_reg=as_reg))
    lines.append(f"reg [{width_data - 1}:0] data_reg;")
    lines.append("reg valid_reg;")
    lines.append("always @(posedge clk_i or posedge rst_i) begin")
    lines.append("  if (rst_i) begin")
    lines.append(f"    data_reg <= {width_data}'b0;")
    lines.append("    valid_reg <= 1'b0;")
    lines.append("  end else begin")
    lines.append("    if (wr_i) begin data_reg <= dat_i; valid_reg <= 1'b1; end")
    lines.append("    if (rd_i) valid_reg <= 1'b0;")
    lines.append("  end")
    lines.append("end")
    lines.append("always @* begin")
    lines.append("  dat_o = data_reg;")
    lines.append("  full_o = valid_reg;")
    lines.append("  empty_o = !valid_reg;")
    lines.append("end")
    lines.append("endmodule")
    return "\n".join(lines)


def render_mult_stub(spec: StubModuleSpec) -> str:
    width_x = spec.ports.get("X", StubPortSpec("input", 32)).width
    width_y = spec.ports.get("Y", StubPortSpec("input", 32)).width
    width_p = spec.ports.get("P", StubPortSpec("output", width_x + width_y)).width
    lines = [f"module {spec.name}(X, Y, RST, CLK, P);"]
    lines.append(port_decl("X", "input", width_x))
    lines.append(port_decl("Y", "input", width_y))
    lines.append(port_decl("RST", "input", 1))
    lines.append(port_decl("CLK", "input", 1))
    lines.append(port_decl("P", "output", width_p))
    lines.append("assign P = X * Y;")
    lines.append("endmodule")
    return "\n".join(lines)


def render_stub_module(spec: StubModuleSpec) -> str:
    ports = set(spec.ports)
    if spec.name == "rf_sub":
        return render_rf_sub_stub(spec)
    if spec.name == "or1200_sb_fifo":
        return render_fifo_stub(spec)
    if spec.name == "or1200_amultp2_32x32":
        return render_mult_stub(spec)
    if {"clka", "ena", "wea", "addra", "dina", "clkb", "addrb", "doutb"}.issubset(ports):
        return render_dual_ram_stub(spec)
    if {"clk", "ce", "we", "addr", "di", "doq"}.issubset(ports):
        return render_single_ram_stub(spec)
    if {"clk_a", "addr_a", "ce_a", "do_a", "clk_b", "addr_b", "ce_b", "we_b", "di_b"}.issubset(ports):
        return render_port_ab_ram_stub(spec)
    if {"clk_a", "addr_a", "ce_a", "we_a", "di_a", "do_a", "clk_b", "addr_b", "ce_b", "we_b", "di_b", "do_b"}.issubset(ports):
        return render_port_ab_ram_stub(spec)
    return render_zero_stub(spec)


def generate_missing_support_file(
    unresolved_modules: Sequence[str],
    source_files: Sequence[Path],
    artifact_dir: Path,
    filename: str = "_generated_support.v",
) -> tuple[Path | None, list[str]]:
    if not unresolved_modules:
        return None, []
    specs = build_stub_specs(unresolved_modules, source_files)
    if not specs:
        return None, []
    stub_path = artifact_dir / filename
    modules = [render_stub_module(specs[name]) for name in sorted(specs)]
    write_text(stub_path, "\n\n".join(modules) + "\n")
    return stub_path, sorted(specs)


def include_dirs_for(candidate_file: Path, ctx: ModuleContext, workdir: Path | None = None) -> list[Path]:
    # workdir must come FIRST: staged candidate copies have to shadow the reference
    # source for testbenches that `include the DUT file, independent of the tool's
    # cwd-based include search order.
    dirs = ([workdir] if workdir is not None else []) + [ctx.family_root, ctx.des_module_dir]
    return stable_path_list(dirs)


def stage_assets(des_module_dir: Path, workdir: Path) -> None:
    for path in des_module_dir.iterdir():
        if not path.is_file():
            continue
        if path.suffix.lower() in ASSET_EXCLUDE_SUFFIXES:
            continue
        shutil.copy2(path, workdir / path.name)


def clear_artifact_dir(artifact_dir: Path) -> None:
    ensure_dir(artifact_dir)
    for name in [
        "compile.log",
        "sim.log",
        "equivalence.log",
        "result.json",
        "_generated_support.v",
        "_generated_support_gold.v",
        "_generated_support_gate.v",
        "candidate_check.out",
    ]:
        path = artifact_dir / name
        if path.exists():
            path.unlink()
    work_dir = artifact_dir / "work"
    if work_dir.exists():
        shutil.rmtree(work_dir)


def cleanup_transient_artifacts(artifact_dir: Path) -> None:
    for name in ["_generated_support.v", "_generated_support_gold.v", "_generated_support_gate.v", "candidate_check.out"]:
        path = artifact_dir / name
        if path.exists():
            path.unlink()
    work_dir = artifact_dir / "work"
    if work_dir.exists():
        shutil.rmtree(work_dir)


def build_iverilog_command(
    iverilog: str,
    top: str,
    output_path: Path,
    include_dirs: Sequence[Path],
    files: Sequence[Path],
    language_flag: str | None = "-g2012",
) -> list[str]:
    command = [iverilog]
    if language_flag:
        command.append(language_flag)
    for include_dir in include_dirs:
        command.extend(["-I", str(include_dir)])
    command.extend(["-s", top, "-o", str(output_path)])
    command.extend(str(path) for path in files)
    return command


def compile_gate_log_text(result: CommandResult) -> str:
    return command_log(result, "candidate_compile_gate")


def run_candidate_compile_gate(candidate_file: Path, ctx: ModuleContext, support_files: Sequence[Path], artifact_dir: Path) -> CompileGateResult:
    output_path = artifact_dir / "candidate_check.out"
    include_dirs = include_dirs_for(candidate_file, ctx)
    files = [*ctx.prefix_files, candidate_file, *support_files]
    command = build_iverilog_command(ctx.iverilog, ctx.reference_top, output_path, include_dirs, files)
    result = run_command(command, timeout=ctx.timeout)
    log_text = compile_gate_log_text(result)
    write_text(artifact_dir / "compile.log", log_text)
    combined = result.combined_output
    return CompileGateResult(
        passed=result.exit_code == 0,
        exit_code=result.exit_code,
        warning_count=warning_count(combined),
        warning_excerpt=summarize_lines(combined, [r"warning:"], limit=8),
        error_excerpt=summarize_lines(combined, [r"error", r"syntax error", r"unexpected"], limit=8),
        log_text=log_text,
    )


def detect_candidate_top(candidate_file: Path, reference_top: str) -> str:
    modules = module_names_in_file(candidate_file)
    if reference_top in modules:
        return reference_top
    return modules[0] if modules else ""


def precheck_script(read_files: Sequence[Path], include_dirs: Sequence[Path], top: str, json_path: Path) -> str:
    command = ["read_verilog", "-sv"]
    for include_dir in include_dirs:
        command.append(f"-I{include_dir}")
    command.extend(str(path) for path in read_files)
    lines = ["# auto-generated", " ".join(shlex_quote(part) for part in command)]
    lines.append(f"hierarchy -check -top {shlex_quote(top)}")
    lines.append("proc")
    lines.append(f"write_json {shlex_quote(str(json_path))}")
    return "\n".join(lines) + "\n"


def run_yosys_script(yosys: str, script_text: str, workdir: Path, timeout: int) -> CommandResult:
    script_path = workdir / "script.ys"
    script_path.write_text(script_text)
    command = [yosys, "-s", str(script_path)]
    return run_command(command, cwd=workdir, timeout=timeout)


def ports_from_yosys_json(json_path: Path, top: str) -> list[PortInfo]:
    data = json.loads(json_path.read_text())
    modules = data.get("modules", {})
    if top not in modules:
        raise ValueError(f"top {top} not found in {json_path}")
    ports = modules[top].get("ports", {})
    result = []
    for name, info in ports.items():
        bits = info.get("bits", [])
        direction = info.get("direction", "")
        result.append(PortInfo(name=name, direction=direction, width=len(bits)))
    return result


def compare_ports(reference_ports: Sequence[PortInfo], candidate_ports: Sequence[PortInfo]) -> tuple[bool, str]:
    ref_map = {port.name: port for port in reference_ports}
    cand_map = {port.name: port for port in candidate_ports}
    if set(ref_map) != set(cand_map):
        missing = sorted(set(ref_map) - set(cand_map))
        extra = sorted(set(cand_map) - set(ref_map))
        parts = []
        if missing:
            parts.append("missing: " + ", ".join(missing))
        if extra:
            parts.append("extra: " + ", ".join(extra))
        return False, "; ".join(parts)
    mismatches = []
    for name in sorted(ref_map):
        ref_port = ref_map[name]
        cand_port = cand_map[name]
        if ref_port.direction != cand_port.direction or ref_port.width != cand_port.width:
            mismatches.append(
                f"{name}: ref={ref_port.direction}[{ref_port.width}] cand={cand_port.direction}[{cand_port.width}]"
            )
    if mismatches:
        return False, "; ".join(mismatches[:8])
    return True, "ports matched"


def detect_proof_type(paths: Sequence[Path]) -> str:
    for path in paths:
        if EVENT_RE.search(strip_comments(read_text(path))):
            return "bounded_seq"
    return "strict_comb"


def read_verilog_command(files: Sequence[Path], include_dirs: Sequence[Path]) -> str:
    parts = ["read_verilog", "-sv"]
    for include_dir in include_dirs:
        parts.append(f"-I{include_dir}")
    parts.extend(str(path) for path in files)
    return " ".join(shlex_quote(part) for part in parts)


def staged_design_lines(
    files: Sequence[Path],
    include_dirs: Sequence[Path],
    top: str,
    stash_name: str,
    extra_prep: Sequence[str] = (),
) -> list[str]:
    lines = [
        "design -reset",
        "design -reset-vlog",
        read_verilog_command(files, include_dirs),
        f"prep -top {shlex_quote(top)} -flatten",
    ]
    lines.extend(extra_prep)
    lines.append(f"design -stash {shlex_quote(stash_name)}")
    return lines


def equivalence_script(
    reference_files: Sequence[Path],
    candidate_files: Sequence[Path],
    include_dirs: Sequence[Path],
    top: str,
    proof_type: str,
    depth: int,
) -> str:
    lines = ["# auto-generated"]
    lines.extend(staged_design_lines(reference_files, include_dirs, top, "gold"))
    lines.extend(staged_design_lines(candidate_files, include_dirs, top, "gate"))
    lines.append("design -reset")
    lines.append(f"design -copy-from gold -as {shlex_quote('gold_' + top)} {shlex_quote(top)}")
    lines.append(f"design -copy-from gate -as {shlex_quote('gate_' + top)} {shlex_quote(top)}")
    lines.append(f"miter -equiv -flatten -make_assert {shlex_quote('gold_' + top)} {shlex_quote('gate_' + top)} miter")
    lines.append("prep -top miter")
    lines.append("delete t:$print")
    if proof_type == "bounded_seq":
        lines.append("async2sync")
        lines.append("dffunmap")
        lines.append(f"sat -verify -prove-asserts -seq {depth} -set-init-zero")
    else:
        lines.append("sat -verify -prove-asserts")
    return "\n".join(lines) + "\n"


def equivalence_induction_script(
    reference_files: Sequence[Path],
    candidate_files: Sequence[Path],
    include_dirs: Sequence[Path],
    top: str,
    depth: int,
) -> str:
    extra_prep = ["memory_map", "async2sync"]
    lines = ["# auto-generated (temporal induction attempt)"]
    lines.extend(staged_design_lines(reference_files, include_dirs, top, "gold", extra_prep))
    lines.extend(staged_design_lines(candidate_files, include_dirs, top, "gate", extra_prep))
    lines.append("design -reset")
    lines.append(f"design -copy-from gold -as {shlex_quote('gold_' + top)} {shlex_quote(top)}")
    lines.append(f"design -copy-from gate -as {shlex_quote('gate_' + top)} {shlex_quote(top)}")
    lines.append(f"equiv_make {shlex_quote('gold_' + top)} {shlex_quote('gate_' + top)} equiv")
    lines.append("hierarchy -top equiv")
    lines.append("clean")
    lines.append(f"equiv_simple -seq {depth}")
    lines.append(f"equiv_induct -seq {depth}")
    lines.append("equiv_status -assert")
    return "\n".join(lines) + "\n"


def extract_counterexample(output: str, limit: int = 12) -> str:
    lines = output.splitlines()
    for index, line in enumerate(lines):
        if re.search(r"model found|proof did fail", line, re.IGNORECASE):
            excerpt = [entry.strip() for entry in lines[index : index + limit] if entry.strip()]
            return " | ".join(excerpt)
    return ""


def build_module_context(
    candidate_module_dir: Path,
    result_root: Path,
    model: str,
    iverilog: str,
    vvp: str,
    yosys: str,
    depth: int,
    timeout: int,
) -> ModuleContext:
    des_module_dir = resolve_des_module_dir(candidate_module_dir.name)
    if des_module_dir is None:
        raise ValueError(f"cannot map Result module {candidate_module_dir.name} into Des")
    reference_file = discover_reference_file(des_module_dir)
    tb_info, same_dir_support = classify_module_dir(des_module_dir, reference_file)
    reference_top = resolve_reference_top(reference_file, des_module_dir.name, tb_info)
    family_root = des_module_dir.parent
    family_name = family_root.name
    report_family_name = REPORT_FAMILY_NAMES.get(family_name, family_name)
    prefix_files = prefix_files_for_family(family_root)
    base_include_dirs = stable_path_list([family_root, des_module_dir])
    return ModuleContext(
        result_root=result_root,
        model=model,
        candidate_module_dir=candidate_module_dir,
        module_dir_name=candidate_module_dir.name,
        des_module_dir=des_module_dir,
        family_root=family_root,
        family_name=family_name,
        report_family_name=report_family_name,
        reference_file=reference_file,
        reference_top=reference_top,
        tb_info=tb_info,
        prefix_files=prefix_files,
        same_dir_support=same_dir_support,
        base_include_dirs=base_include_dirs,
        iverilog=iverilog,
        vvp=vvp,
        yosys=yosys,
        depth=depth,
        timeout=timeout,
        artifacts_root=candidate_module_dir,
    )


def build_result(
    ctx: ModuleContext,
    candidate_file: Path,
    artifact_dir: Path,
    status: str,
    flow: str,
    proof_type: str,
    reason: str,
    candidate_top: str,
    compile_gate: CompileGateResult,
) -> CandidateResult:
    candidate_name = candidate_file.name
    return CandidateResult(
        model=ctx.model,
        family=ctx.report_family_name,
        module_dir=ctx.module_dir_name,
        attempt=attempt_from_name(candidate_name),
        candidate_name=candidate_name,
        candidate_file=str(candidate_file),
        reference_file=str(ctx.reference_file),
        reference_top=ctx.reference_top,
        candidate_top=candidate_top,
        flow=flow,
        status=status,
        proof_type=proof_type,
        tb_file=str(ctx.tb_info.path) if ctx.tb_info else "",
        tb_top=ctx.tb_info.top if ctx.tb_info else "",
        tb_self_checking=ctx.tb_info.self_checking if ctx.tb_info else False,
        artifact_dir=str(artifact_dir),
        reason=reason,
        compile_gate_status="pass" if compile_gate.passed else "fail",
        compile_gate_exit_code=compile_gate.exit_code,
        compile_gate_warning_count=compile_gate.warning_count,
        compile_gate_warning_excerpt=compile_gate.warning_excerpt,
        compile_gate_error_excerpt=compile_gate.error_excerpt,
    )


def compile_fail_result(
    ctx: ModuleContext,
    candidate_file: Path,
    artifact_dir: Path,
    compile_gate: CompileGateResult,
    reason: str | None = None,
) -> CandidateResult:
    final_reason = reason or compile_gate.error_excerpt or "candidate compile gate failed"
    result = build_result(
        ctx,
        candidate_file,
        artifact_dir,
        status="compile_fail",
        flow="compile_gate",
        proof_type="compile_gate",
        reason=final_reason,
        candidate_top=detect_candidate_top(candidate_file, ctx.reference_top),
        compile_gate=compile_gate,
    )
    result.reason_bucket = "compile_fail"
    return result


def run_simulation_flow(
    ctx: ModuleContext,
    candidate_file: Path,
    artifact_dir: Path,
    compile_gate: CompileGateResult,
    support_files: Sequence[Path],
) -> SimulationFlowResult:
    assert ctx.tb_info is not None
    tb_info = ctx.tb_info
    workdir = artifact_dir / "work"
    ensure_dir(workdir)
    stage_assets(ctx.des_module_dir, workdir)
    include_dirs = include_dirs_for(candidate_file, ctx, workdir)
    simulation_files: list[Path] = [*ctx.prefix_files]
    if tb_info.includes_reference:
        staged_candidate = workdir / ctx.reference_file.name
        shutil.copy2(candidate_file, staged_candidate)
        simulation_files.extend(stable_path_list([*support_files, *ctx.same_dir_support]))
        simulation_files.append(tb_info.path)
    else:
        simulation_files.append(candidate_file)
        simulation_files.extend(stable_path_list([*support_files, *ctx.same_dir_support]))
        simulation_files.append(tb_info.path)
    simv_path = workdir / "simv"
    compile_logs: list[str] = []
    plain_verilog_fallback_used = False
    compile_cmd = build_iverilog_command(
        ctx.iverilog,
        tb_info.top,
        simv_path,
        include_dirs,
        simulation_files,
        language_flag="-g2012",
    )
    compile_result = run_command(compile_cmd, cwd=workdir, timeout=ctx.timeout)
    compile_logs.append(command_log(compile_result, "tb_compile_sv2012"))
    sim_log_path = artifact_dir / "sim.log"
    if compile_result.exit_code != 0:
        plain_compile_cmd = build_iverilog_command(
            ctx.iverilog,
            tb_info.top,
            simv_path,
            include_dirs,
            simulation_files,
            language_flag=None,
        )
        plain_compile_result = run_command(plain_compile_cmd, cwd=workdir, timeout=ctx.timeout)
        compile_logs.append(command_log(plain_compile_result, "tb_compile_plain_verilog"))
        if plain_compile_result.exit_code != 0:
            write_text(sim_log_path, "\n".join(compile_logs))
            reason = (
                summarize_lines(
                    plain_compile_result.combined_output or compile_result.combined_output,
                    [r"error", r"syntax error", r"unexpected"],
                    limit=8,
                )
                or "testbench compile failed"
            )
            return SimulationFlowResult(final_result=None, tb_compile_failed=True, tb_compile_reason=reason)
        compile_result = plain_compile_result
        plain_verilog_fallback_used = True
    run_result = run_command([ctx.vvp, "-n", str(simv_path)], cwd=workdir, timeout=ctx.timeout)
    sim_log_text = "\n".join(compile_logs) + "\n" + command_log(run_result, "simulation_run")
    write_text(sim_log_path, sim_log_text)
    combined = run_result.combined_output
    if run_result.exit_code != 0:
        reason = summarize_lines(combined, [r"fail", r"error", r"mismatch", r"stop called", r"timed_out"], limit=8) or "simulation runtime failed"
        if plain_verilog_fallback_used:
            reason = f"plain Verilog tb compile fallback used; {reason}"
        result = build_result(
            ctx,
            candidate_file,
            artifact_dir,
            status="simulation_runtime_fail",
            flow="simulation_tb",
            proof_type="simulation_tb",
            reason=reason,
            candidate_top=detect_candidate_top(candidate_file, ctx.reference_top),
            compile_gate=compile_gate,
        )
        result.reason_bucket = "simulation_runtime_fail"
        result.simulation_exit_code = run_result.exit_code
        return SimulationFlowResult(final_result=result)
    failure_lines = sim_failure_lines(combined)
    if failure_lines:
        reason = " | ".join(failure_lines[:8])
        if plain_verilog_fallback_used:
            reason = f"plain Verilog tb compile fallback used; {reason}"
        result = build_result(
            ctx,
            candidate_file,
            artifact_dir,
            status="function_fail",
            flow="simulation_tb",
            proof_type="simulation_tb",
            reason=reason,
            candidate_top=detect_candidate_top(candidate_file, ctx.reference_top),
            compile_gate=compile_gate,
        )
        result.reason_bucket = "function_fail"
        result.simulation_exit_code = run_result.exit_code
        return SimulationFlowResult(final_result=result)
    pass_reason = "simulation passed"
    if plain_verilog_fallback_used:
        pass_reason = "simulation passed after plain Verilog tb compile fallback"
    result = build_result(
        ctx,
        candidate_file,
        artifact_dir,
        status="pass",
        flow="simulation_tb",
        proof_type="simulation_tb",
        reason=pass_reason,
        candidate_top=detect_candidate_top(candidate_file, ctx.reference_top),
        compile_gate=compile_gate,
    )
    result.reason_bucket = "pass"
    result.simulation_exit_code = run_result.exit_code
    return SimulationFlowResult(final_result=result)


def run_equivalence_flow(
    ctx: ModuleContext,
    candidate_file: Path,
    artifact_dir: Path,
    compile_gate: CompileGateResult,
    ref_support: Sequence[Path],
    cand_support: Sequence[Path],
) -> CandidateResult:
    workdir = artifact_dir / "work"
    ensure_dir(workdir)
    include_dirs = include_dirs_for(candidate_file, ctx, workdir)
    reference_files = [*ctx.prefix_files, ctx.reference_file, *ref_support]
    candidate_files = [*ctx.prefix_files, candidate_file, *cand_support]
    reference_json = workdir / "reference.json"
    candidate_json = workdir / "candidate.json"
    log_chunks: list[str] = []

    reference_precheck = run_yosys_script(
        ctx.yosys,
        precheck_script(reference_files, include_dirs, ctx.reference_top, reference_json),
        workdir,
        ctx.timeout,
    )
    log_chunks.append(command_log(reference_precheck, "reference_precheck"))
    if reference_precheck.exit_code != 0:
        write_text(artifact_dir / "equivalence.log", "\n".join(log_chunks))
        result = build_result(
            ctx,
            candidate_file,
            artifact_dir,
            status="reference_fail",
            flow="equivalence",
            proof_type="unknown",
            reason=summarize_lines(reference_precheck.combined_output, [r"error", r"syntax error", r"unexpected"], limit=8)
            or "reference precheck failed",
            candidate_top=detect_candidate_top(candidate_file, ctx.reference_top),
            compile_gate=compile_gate,
        )
        result.reference_precheck = "fail"
        result.reason_bucket = "reference_fail"
        return result

    candidate_precheck = run_yosys_script(
        ctx.yosys,
        precheck_script(candidate_files, include_dirs, ctx.reference_top, candidate_json),
        workdir,
        ctx.timeout,
    )
    log_chunks.append(command_log(candidate_precheck, "candidate_precheck"))
    if candidate_precheck.exit_code != 0:
        write_text(artifact_dir / "equivalence.log", "\n".join(log_chunks))
        result = build_result(
            ctx,
            candidate_file,
            artifact_dir,
            status="elaboration_fail",
            flow="equivalence",
            proof_type="unknown",
            reason=summarize_lines(candidate_precheck.combined_output, [r"error", r"syntax error", r"unexpected"], limit=8)
            or "candidate precheck failed",
            candidate_top=detect_candidate_top(candidate_file, ctx.reference_top),
            compile_gate=compile_gate,
        )
        result.reference_precheck = "pass"
        result.candidate_precheck = "fail"
        result.reason_bucket = "elaboration_fail"
        return result

    reference_ports = ports_from_yosys_json(reference_json, ctx.reference_top)
    candidate_ports = ports_from_yosys_json(candidate_json, ctx.reference_top)
    ports_ok, port_reason = compare_ports(reference_ports, candidate_ports)
    if not ports_ok:
        write_text(artifact_dir / "equivalence.log", "\n".join(log_chunks))
        result = build_result(
            ctx,
            candidate_file,
            artifact_dir,
            status="interface_fail",
            flow="equivalence",
            proof_type="unknown",
            reason=port_reason,
            candidate_top=detect_candidate_top(candidate_file, ctx.reference_top),
            compile_gate=compile_gate,
        )
        result.reference_precheck = "pass"
        result.candidate_precheck = "pass"
        result.interface_status = "incompatible"
        result.formal_status = "skip"
        result.interface_reason = port_reason
        result.interface_reason_kind = "strict_port_mismatch"
        result.reason_bucket = "interface_fail"
        return result

    proof_type = detect_proof_type([ctx.reference_file, candidate_file, *ref_support, *cand_support])
    induction_used = False
    eq_result: CommandResult | None = None
    if proof_type == "bounded_seq":
        induction_script = equivalence_induction_script(
            reference_files, candidate_files, include_dirs, ctx.reference_top, ctx.depth
        )
        log_chunks.append(f"=== induction script ===\n{induction_script}")
        induction_result = run_yosys_script(ctx.yosys, induction_script, workdir, ctx.timeout)
        log_chunks.append(command_log(induction_result, "equivalence_induction"))
        if induction_result.exit_code == 0 and not induction_result.timed_out:
            induction_used = True
            eq_result = induction_result
    if eq_result is None:
        proof_script = equivalence_script(
            reference_files, candidate_files, include_dirs, ctx.reference_top, proof_type, ctx.depth
        )
        log_chunks.append(f"=== proof script ===\n{proof_script}")
        eq_result = run_yosys_script(ctx.yosys, proof_script, workdir, ctx.timeout)
        log_chunks.append(command_log(eq_result, "equivalence_proof"))
    write_text(artifact_dir / "equivalence.log", "\n".join(log_chunks))

    output = eq_result.combined_output
    counterexample = ""
    if induction_used:
        status = "pass"
        result_proof_type = "induction"
        formal_status = "equivalent"
        reason = f"equivalence proven by temporal induction (k={ctx.depth})"
    elif eq_result.timed_out:
        status = "equivalence_timeout"
        result_proof_type = proof_type
        formal_status = "unknown"
        reason = f"yosys equivalence check timed out after {ctx.timeout}s; result inconclusive"
    elif eq_result.exit_code == 0:
        status = "pass"
        result_proof_type = proof_type
        if proof_type == "bounded_seq":
            formal_status = "equivalent_bounded"
            reason = f"equivalence passed (bounded, k={ctx.depth}, zero-initialized state)"
        else:
            formal_status = "equivalent"
            reason = "equivalence passed (combinational, unbounded)"
    elif re.search(r"proof did fail|model found", output, re.IGNORECASE):
        status = "function_fail"
        result_proof_type = proof_type
        formal_status = "not_equivalent"
        counterexample = extract_counterexample(output)
        reason = summarize_lines(output, [r"fail", r"assert", r"proof"], limit=8) or "equivalence proof failed"
    else:
        status = "equivalence_error"
        result_proof_type = proof_type
        formal_status = "unknown"
        reason = summarize_lines(output, [r"error"], limit=8) or "yosys equivalence flow errored"
    result = build_result(
        ctx,
        candidate_file,
        artifact_dir,
        status=status,
        flow="equivalence",
        proof_type=result_proof_type,
        reason=reason,
        candidate_top=detect_candidate_top(candidate_file, ctx.reference_top),
        compile_gate=compile_gate,
    )
    result.reference_precheck = "pass"
    result.candidate_precheck = "pass"
    result.interface_status = "compatible"
    result.formal_status = formal_status
    result.interface_reason = "ports matched"
    result.interface_reason_kind = "strict_port_match"
    result.counterexample_summary = counterexample
    result.reason_bucket = result.status
    result.equivalence_exit_code = eq_result.exit_code
    return result


def verify_candidate(candidate_file: Path, reference: Path, module_name: str, ctx: dict[str, object]) -> CandidateResult:
    module_ctx = ctx["module_ctx"]
    assert isinstance(module_ctx, ModuleContext)
    family_caches = ctx["family_caches"]
    assert isinstance(family_caches, dict)
    artifact_dir = module_ctx.artifacts_root / candidate_file.stem
    clear_artifact_dir(artifact_dir)
    family_cache = family_cache_for(module_ctx.family_root, family_caches)
    ref_support = resolve_support_files_for(family_cache, [reference])
    cand_support = resolve_support_files_for(family_cache, [candidate_file])
    ref_stub, ref_stub_names = generate_missing_support_file(
        unresolved_instance_modules([reference, *ref_support]),
        [reference, *ref_support],
        artifact_dir,
        "_generated_support_gold.v",
    )
    if ref_stub is not None:
        ref_support = [*ref_support, ref_stub]
    cand_stub, cand_stub_names = generate_missing_support_file(
        unresolved_instance_modules([candidate_file, *cand_support]),
        [candidate_file, *cand_support],
        artifact_dir,
        "_generated_support_gate.v",
    )
    if cand_stub is not None:
        cand_support = [*cand_support, cand_stub]
    stub_names = sorted(set(ref_stub_names) | set(cand_stub_names))

    def finalize(result: CandidateResult) -> CandidateResult:
        result.generated_stub_modules = stub_names
        write_json(artifact_dir / "result.json", result.to_row())
        cleanup_transient_artifacts(artifact_dir)
        return result

    compile_gate = run_candidate_compile_gate(candidate_file, module_ctx, cand_support, artifact_dir)
    if not compile_gate.passed:
        return finalize(compile_fail_result(module_ctx, candidate_file, artifact_dir, compile_gate))
    if module_ctx.tb_info is not None:
        sim_result = run_simulation_flow(module_ctx, candidate_file, artifact_dir, compile_gate, cand_support)
        sim_final = sim_result.final_result
        if sim_final is not None and (module_ctx.tb_info.self_checking or sim_final.status == "simulation_runtime_fail"):
            # A print-only tb cannot issue a functional verdict; only self-checking
            # benches (or hard runtime failures) are allowed to conclude here.
            return finalize(sim_final)
        result = run_equivalence_flow(module_ctx, candidate_file, artifact_dir, compile_gate, ref_support, cand_support)
        if sim_result.tb_compile_failed:
            result.reason = f"tb compile failed; fell back to formal: {sim_result.tb_compile_reason}; {result.reason}"
        elif sim_final is not None:
            result.reason = (
                f"print-only tb simulation completed (status={sim_final.status}, not a functional verdict); {result.reason}"
            )
            result.simulation_exit_code = sim_final.simulation_exit_code
        return finalize(result)
    return finalize(run_equivalence_flow(module_ctx, candidate_file, artifact_dir, compile_gate, ref_support, cand_support))


def module_rows_to_json(
    ctx: ModuleContext,
    rows: Sequence[CandidateResult],
    report_json: Path,
    report_csv: Path,
) -> None:
    metrics = pass_metrics(rows)
    simulation_candidates = sum(1 for row in rows if row.flow == "simulation_tb")
    equivalence_candidates = sum(1 for row in rows if row.flow == "equivalence")
    json_payload = {
        "module_dir": ctx.module_dir_name,
        "family": ctx.report_family_name,
        "model": ctx.model,
        "reference_file": str(ctx.reference_file),
        "reference_top": ctx.reference_top,
        "tb_file": str(ctx.tb_info.path) if ctx.tb_info else "",
        "tb_top": ctx.tb_info.top if ctx.tb_info else "",
        "tb_self_checking": ctx.tb_info.self_checking if ctx.tb_info else False,
        "result_count": len(rows),
        "simulation_candidate_count": simulation_candidates,
        "equivalence_candidate_count": equivalence_candidates,
        "simulation_pass_count": metrics["simulation_pass"],
        "equivalence_pass_count": metrics["equivalence_pass"],
        "equivalence_pass_full_count": metrics["equivalence_pass_full"],
        "equivalence_pass_bounded_count": metrics["equivalence_pass_bounded"],
        "counts": dict(Counter(row.status for row in rows)),
        "results": [row.to_row() for row in rows],
    }
    write_json(report_json, json_payload)
    write_csv(report_csv, [row.to_row() for row in rows], DETAIL_FIELDS)


def module_summary_row(module_ctx: ModuleContext, rows: Sequence[CandidateResult]) -> dict[str, object]:
    counts = Counter(row.status for row in rows)
    metrics = pass_metrics(rows)
    summary = {
        "model": module_ctx.model,
        "module_dir": module_ctx.module_dir_name,
        "compile_pass": metrics["compile_pass"],
        "function_pass": metrics["function_pass"],
        "simulation_pass": metrics["simulation_pass"],
        "equivalence_pass": metrics["equivalence_pass"],
        "equivalence_pass_full": metrics["equivalence_pass_full"],
        "equivalence_pass_bounded": metrics["equivalence_pass_bounded"],
    }
    for status in STATUS_VALUES:
        summary[status] = counts.get(status, 0)
    return summary


def aggregate_status(rows: Sequence[CandidateResult], attr: str) -> dict[str, dict[str, int]]:
    buckets: dict[str, Counter[str]] = defaultdict(Counter)
    for row in rows:
        key = getattr(row, attr)
        buckets[key][row.status] += 1

    def sort_key(item: tuple[str, Counter[str]]) -> tuple[int, object]:
        key = str(item[0])
        return (0, int(key)) if key.isdigit() else (1, key)

    return {key: dict(counter) for key, counter in sorted(buckets.items(), key=sort_key)}


def write_suite_reports(
    all_rows: Sequence[CandidateResult],
    module_summaries: Sequence[dict[str, object]],
    report_dir: Path,
    summary_json: Path,
    summary_csv: Path,
    result_root: Path,
    include_global_csvs: bool = True,
    skipped_modules: Sequence[dict[str, str]] = (),
) -> None:
    detailed_csv = derive_detailed_csv_path(summary_csv)
    detailed_summary_json = derive_detailed_summary_json_path(summary_json)
    write_csv(detailed_csv, [row.to_row() for row in all_rows], DETAIL_FIELDS)
    write_csv(summary_csv, module_summaries, SUMMARY_FIELDS)
    overall_status_counts = Counter(row.status for row in all_rows)
    payload = {
        "result_root": str(result_root),
        "report_dir": str(report_dir),
        "summary_csv": str(summary_csv),
        "summary_json": str(summary_json),
        "module_count": len(module_summaries),
        "candidate_count": len(all_rows),
        "overall_status_counts": dict(overall_status_counts),
        "skipped_modules": list(skipped_modules),
        "module_summaries": list(module_summaries),
    }
    write_json(summary_json, payload)
    detailed_payload = {
        "total_rows": len(all_rows),
        "status_counts_by_module": aggregate_status(all_rows, "module_dir"),
        "status_counts_by_model": aggregate_status(all_rows, "model"),
        "status_counts_by_attempt": aggregate_status(all_rows, "attempt"),
        "overall_status_counts": dict(overall_status_counts),
        "observed_candidates": sorted(row.candidate_file for row in all_rows),
    }
    write_json(detailed_summary_json, detailed_payload)
    if not include_global_csvs:
        # Filtered runs (e.g. --model) must not clobber the all-model compile/syntax CSVs.
        return
    compile_rows = [row.syntax_row() for row in all_rows]
    write_csv(DEFAULT_COMPILE_CSV, compile_rows, COMPILE_FIELDS)
    write_csv(DEFAULT_SYNTAX_DETAIL_CSV, compile_rows, COMPILE_FIELDS)
    model_summary_rows = []
    for model, bucket in sorted(group_rows(compile_rows, ["model"]).items()):
        counts = Counter(item["status"] for item in bucket)
        model_summary_rows.append({"model": model, "pass": counts.get("pass", 0), "fail": counts.get("fail", 0), "total": len(bucket)})
    write_csv(DEFAULT_SYNTAX_MODEL_CSV, model_summary_rows, ["model", "pass", "fail", "total"])
    model_module_rows = []
    for (model, module_dir), bucket in sorted(group_rows(compile_rows, ["model", "module_dir"]).items()):
        counts = Counter(item["status"] for item in bucket)
        model_module_rows.append(
            {
                "model": model,
                "module_dir": module_dir,
                "pass": counts.get("pass", 0),
                "fail": counts.get("fail", 0),
                "total": len(bucket),
            }
        )
    write_csv(DEFAULT_SYNTAX_MODEL_MODULE_CSV, model_module_rows, ["model", "module_dir", "pass", "fail", "total"])


def group_rows(rows: Sequence[dict[str, object]], keys: Sequence[str]) -> dict[tuple[object, ...] | object, list[dict[str, object]]]:
    buckets: dict[tuple[object, ...] | object, list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        key: tuple[object, ...] | object
        if len(keys) == 1:
            key = row[keys[0]]
        else:
            key = tuple(row[name] for name in keys)
        buckets[key].append(row)
    return buckets


def candidate_files_in_module_dir(module_dir: Path) -> list[Path]:
    return sorted(path for path in module_dir.glob("*_t*.v") if path.is_file())


def run_module(
    module_ctx: ModuleContext,
    family_caches: dict[Path, FamilyCache],
    report_dir: Path | None = None,
    report_json: Path | None = None,
    report_csv: Path | None = None,
) -> list[CandidateResult]:
    candidate_files = candidate_files_in_module_dir(module_ctx.candidate_module_dir)
    rows = [
        verify_candidate(
            candidate_file,
            module_ctx.reference_file,
            module_ctx.module_dir_name,
            {"module_ctx": module_ctx, "family_caches": family_caches},
        )
        for candidate_file in candidate_files
    ]
    if report_dir is not None:
        # Per-model subdirectory: without it, each model's run overwrites the
        # previous model's per-module reports.
        model_report_dir = report_dir / module_ctx.model
        report_json = report_json or (model_report_dir / f"{module_ctx.module_dir_name}.json")
        report_csv = report_csv or (model_report_dir / f"{module_ctx.module_dir_name}.csv")
    if report_json is not None and report_csv is not None:
        module_rows_to_json(module_ctx, rows, report_json, report_csv)
    return rows


def detect_model_from_candidate_dir(candidate_module_dir: Path, result_root: Path) -> str:
    try:
        relative = candidate_module_dir.resolve().relative_to(result_root.resolve())
    except ValueError as exc:
        raise ValueError(f"{candidate_module_dir} is not under {result_root}") from exc
    parts = relative.parts
    if len(parts) < 2:
        raise ValueError(f"expected Result/<model>/<module>, got {candidate_module_dir}")
    return parts[0]


def run_verify_command(args: argparse.Namespace) -> int:
    target = Path(args.directory or ".").resolve()
    if target.is_file():
        target = target.parent
    result_root = Path(args.result_root).resolve()
    model = detect_model_from_candidate_dir(target, result_root)
    module_ctx = build_module_context(target, result_root, model, args.iverilog, args.vvp, args.yosys, args.depth, args.timeout)
    report_dir = Path(args.report_dir).resolve() if args.report_dir else None
    family_caches: dict[Path, FamilyCache] = {}
    rows = run_module(module_ctx, family_caches, report_dir=report_dir)
    print(
        json.dumps(
            {
                "module": module_ctx.module_dir_name,
                "model": model,
                "rows": len(rows),
                **pass_metrics(rows),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


def resolve_reference_from_arg(reference_arg: str | None, module_dir_name: str | None) -> Path:
    if reference_arg is None:
        if module_dir_name is None:
            raise ValueError("reference or module-dir is required")
        des_module_dir = resolve_des_module_dir(module_dir_name)
        if des_module_dir is None:
            raise ValueError(f"cannot map module {module_dir_name} into Des")
        return des_module_dir
    path = Path(reference_arg).resolve()
    if path.is_dir():
        return path
    return path.parent


def discover_candidate_module_dirs(candidates_root: Path, module_dir_name: str | None) -> list[Path]:
    if candidates_root.is_dir() and any(candidates_root.glob("*_t*.v")):
        return [candidates_root]
    if module_dir_name is None:
        raise ValueError("--module-dir is required when candidates is not a single module directory")
    model_module = candidates_root / module_dir_name
    if model_module.is_dir():
        return [model_module]
    module_dirs = []
    for model_dir in sorted(path for path in candidates_root.iterdir() if path.is_dir()):
        candidate_dir = model_dir / module_dir_name
        if candidate_dir.is_dir():
            module_dirs.append(candidate_dir)
    return module_dirs


def run_check_command(args: argparse.Namespace) -> int:
    candidates_root = Path(args.candidates).resolve()
    module_dir_name = args.module_dir
    reference_dir = resolve_reference_from_arg(args.reference, module_dir_name)
    if module_dir_name is None:
        module_dir_name = reference_dir.name
    family_caches: dict[Path, FamilyCache] = {}
    all_rows: list[CandidateResult] = []
    candidate_dirs = discover_candidate_module_dirs(candidates_root, module_dir_name)
    if not candidate_dirs:
        raise ValueError(
            f"no candidate module directories found under {candidates_root} for module '{module_dir_name}'"
            " (note: mips_16 result dirs use a 'mips_' prefix, e.g. mips_alu)"
        )
    for candidate_dir in candidate_dirs:
        result_root = DEFAULT_RESULT_ROOT if DEFAULT_RESULT_ROOT in candidate_dir.parents else candidate_dir.parent.parent
        model = candidate_dir.parent.name
        reference_file = discover_reference_file(reference_dir)
        tb_info, same_dir_support = classify_module_dir(reference_dir, reference_file)
        module_ctx = ModuleContext(
            result_root=result_root,
            model=model,
            candidate_module_dir=candidate_dir,
            module_dir_name=module_dir_name,
            des_module_dir=reference_dir,
            family_root=reference_dir.parent,
            family_name=reference_dir.parent.name,
            report_family_name=REPORT_FAMILY_NAMES.get(reference_dir.parent.name, reference_dir.parent.name),
            reference_file=reference_file,
            reference_top=resolve_reference_top(reference_file, reference_dir.name, tb_info),
            tb_info=tb_info,
            prefix_files=prefix_files_for_family(reference_dir.parent),
            same_dir_support=same_dir_support,
            base_include_dirs=stable_path_list([reference_dir.parent, reference_dir]),
            iverilog=args.iverilog,
            vvp=args.vvp,
            yosys=args.yosys,
            depth=args.depth,
            timeout=args.timeout,
            artifacts_root=candidate_dir,
        )
        rows = run_module(module_ctx, family_caches)
        all_rows.extend(rows)
    report_json = Path(args.report).resolve() if args.report else None
    report_csv = Path(args.csv_report).resolve() if args.csv_report else None
    if report_json is not None:
        write_json(report_json, {"results": [row.to_row() for row in all_rows], "counts": dict(Counter(row.status for row in all_rows))})
    if report_csv is not None:
        write_csv(report_csv, [row.to_row() for row in all_rows], DETAIL_FIELDS)
    print(json.dumps({"rows": len(all_rows), **pass_metrics(all_rows)}, ensure_ascii=False, indent=2))
    return 0


def iter_suite_module_dirs(result_root: Path, model_filter: str | None) -> list[tuple[str, Path]]:
    module_dirs: list[tuple[str, Path]] = []
    for model_dir in sorted(path for path in result_root.iterdir() if path.is_dir()):
        if model_filter and model_dir.name != model_filter:
            continue
        for module_dir in sorted(path for path in model_dir.iterdir() if path.is_dir()):
            if candidate_files_in_module_dir(module_dir):
                module_dirs.append((model_dir.name, module_dir))
    return module_dirs


def run_suite_command(args: argparse.Namespace) -> int:
    result_root = Path(args.result_root).resolve()
    report_dir = Path(args.report_dir).resolve()
    summary_json = Path(args.summary_json).resolve()
    summary_csv = Path(args.summary_csv).resolve()
    log_file = Path(args.log_file).resolve()
    ensure_dir(report_dir)
    family_caches: dict[Path, FamilyCache] = {}
    all_rows: list[CandidateResult] = []
    module_summaries: list[dict[str, object]] = []
    skipped_modules: list[dict[str, str]] = []
    module_entries = iter_suite_module_dirs(result_root, args.model)
    ensure_parent(log_file)
    log_file.write_text("")
    emit_progress(
        f"suite start result_root={result_root} modules={len(module_entries)} report_dir={report_dir}",
        log_file=log_file,
    )
    start_time = time.monotonic()
    for index, (model, module_dir) in enumerate(module_entries, start=1):
        module_start = time.monotonic()
        try:
            module_ctx = build_module_context(module_dir, result_root, model, args.iverilog, args.vvp, args.yosys, args.depth, args.timeout)
        except Exception as exc:
            emit_progress(f"[{index}/{len(module_entries)}] skip {module_dir}: {exc}", log_file=log_file, stream=sys.stderr)
            skipped_modules.append({"model": model, "module_dir": module_dir.name, "error": str(exc)})
            continue
        try:
            rows = run_module(module_ctx, family_caches, report_dir=report_dir)
        except Exception as exc:
            emit_progress(
                f"[{index}/{len(module_entries)}] error {model}/{module_ctx.module_dir_name}: {exc}",
                log_file=log_file,
                stream=sys.stderr,
            )
            skipped_modules.append({"model": model, "module_dir": module_ctx.module_dir_name, "error": str(exc)})
            continue
        all_rows.extend(rows)
        summary = module_summary_row(module_ctx, rows)
        summary["report_json"] = str(report_dir / model / f"{module_ctx.module_dir_name}.json")
        summary["report_csv"] = str(report_dir / model / f"{module_ctx.module_dir_name}.csv")
        module_summaries.append(summary)
        elapsed = time.monotonic() - module_start
        module_metrics = pass_metrics(rows)
        overall_metrics = pass_metrics(all_rows)
        emit_progress(
            f"[{index}/{len(module_entries)}] {model}/{module_ctx.module_dir_name} "
            f"done in {elapsed:.1f}s | module: "
            f"compile_pass={module_metrics['compile_pass']} function_pass={module_metrics['function_pass']} "
            f"sim_pass={module_metrics['simulation_pass']} eq_pass={module_metrics['equivalence_pass']} | "
            f"overall_rows={len(all_rows)} overall: "
            f"compile_pass={overall_metrics['compile_pass']} function_pass={overall_metrics['function_pass']}",
            log_file=log_file,
        )
    include_global_csvs = args.model is None
    write_suite_reports(
        all_rows,
        module_summaries,
        report_dir,
        summary_json,
        summary_csv,
        result_root,
        include_global_csvs=include_global_csvs,
        skipped_modules=skipped_modules,
    )
    if not include_global_csvs:
        emit_progress(
            "filtered run (--model): global compile/syntax CSVs left untouched",
            log_file=log_file,
        )
    total_elapsed = time.monotonic() - start_time
    final_summary = {
        "modules": len(module_summaries),
        "rows": len(all_rows),
        "skipped_modules": len(skipped_modules),
        **pass_metrics(all_rows),
    }
    emit_progress(
        f"suite complete in {total_elapsed:.1f}s | modules={final_summary['modules']} rows={final_summary['rows']} "
        f"| compile_pass={final_summary['compile_pass']} function_pass={final_summary['function_pass']}",
        log_file=log_file,
    )
    print(json.dumps(final_summary, ensure_ascii=False, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Unified Result verifier based on Des references.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    verify = subparsers.add_parser("verify", help="Verify all candidates inside one Result/<model>/<module> directory.")
    verify.add_argument("directory", nargs="?", help="Candidate module directory under Result.")
    verify.add_argument("--result-root", default=str(DEFAULT_RESULT_ROOT))
    verify.add_argument("--report-dir")
    add_tool_args(verify)
    verify.set_defaults(func=run_verify_command)

    check = subparsers.add_parser("check", help="Verify candidates for one module.")
    check.add_argument("--reference")
    check.add_argument("--candidates", required=True)
    check.add_argument("--module-dir")
    check.add_argument("--report")
    check.add_argument("--csv-report")
    add_tool_args(check)
    check.set_defaults(func=run_check_command)

    suite = subparsers.add_parser("suite", help="Run verification across Result.")
    suite.add_argument("--result-root", default=str(DEFAULT_RESULT_ROOT))
    suite.add_argument("--report-dir", default=str(DEFAULT_REPORT_DIR))
    suite.add_argument("--summary-json", default=str(DEFAULT_SUMMARY_JSON))
    suite.add_argument("--summary-csv", default=str(DEFAULT_SUMMARY_CSV))
    suite.add_argument("--log-file", default=str(DEFAULT_SUITE_LOG))
    suite.add_argument("--model")
    add_tool_args(suite)
    suite.set_defaults(func=run_suite_command)
    return parser


def add_tool_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--iverilog", default=DEFAULT_IVERILOG)
    parser.add_argument("--vvp", default=DEFAULT_VVP)
    parser.add_argument("--yosys", default=DEFAULT_YOSYS)
    parser.add_argument("--depth", type=int, default=16, help="bounded-check / induction depth in cycles")
    parser.add_argument("--timeout", type=int, default=120, help="per-subprocess timeout in seconds")


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
