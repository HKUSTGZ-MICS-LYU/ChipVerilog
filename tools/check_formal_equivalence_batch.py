#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
import subprocess
import sys
import tempfile
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path

from check_test_equivalence import (
    MODULE_BLOCK_RE,
    build_or1200_primitive_models,
    build_precheck_script,
    build_proof_script,
    clean_output,
    detect_proof_type,
    extract_module_info,
    repair_or1200_reference_root,
    run_yosys_script,
    strip_comments,
    summarize_error,
)


INCLUDE_RE = re.compile(r'^\s*`include\s+"([^"]+)"', re.M)
ANSI_PORT_RE = re.compile(
    r"^\s*(input|output|inout)\s+"
    r"(?:(?:reg|wire|logic|signed|unsigned)\s+)*"
    r"(?:(\[[^]]+\])\s+)?"
    r"([A-Za-z_][\w$]*)\s*$",
    re.S,
)
BODY_DECL_RE = re.compile(
    r"(?m)^\s*(input|output|inout)\s+"
    r"(?:(?:reg|wire|logic|signed|unsigned)\s+)*"
    r"(?:(\[[^]]+\])\s+)?"
    r"([^;]+);"
)


@dataclass(frozen=True)
class PortInfo:
    direction: str | None
    width: str | None


@dataclass(frozen=True)
class ModuleInterface:
    module_name: str
    ordered_ports: tuple[str, ...]
    ports: dict[str, PortInfo]


@dataclass
class CompareResult:
    model: str
    module_dir: str
    candidate_file: str
    reference_file: str
    reference_top: str
    candidate_top: str
    reference_precheck: str
    candidate_precheck: str
    interface_status: str
    formal_status: str
    proof_type: str
    reason: str
    counterexample_summary: str
    counterexample: dict[str, object] | None


def write_csv_report(path: Path, results: list[CompareResult]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "model",
        "module_dir",
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
        "counterexample_json",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for result in results:
            row = asdict(result)
            row["counterexample_json"] = (
                json.dumps(result.counterexample, ensure_ascii=False)
                if result.counterexample is not None
                else ""
            )
            row.pop("counterexample", None)
            writer.writerow(row)


def format_logic_value(value: str | None) -> dict[str, str] | None:
    if value is None:
        return None

    payload = {"bin": value}
    if value and set(value) <= {"0", "1"}:
        width = max(1, (len(value) + 3) // 4)
        payload["hex"] = f"0x{int(value, 2):0{width}x}"
    return payload


def format_logic_value_text(value: dict[str, str] | None) -> str:
    if value is None:
        return "unknown"
    if "hex" in value:
        return value["hex"]
    return value["bin"]


def expand_wave_values(signal: dict[str, object], depth: int) -> list[str | None]:
    wave = str(signal.get("wave", ""))
    data = [str(item) for item in signal.get("data", [])]
    data_index = 1 if data and data[0] == "" else 0
    current: str | None = None
    values: list[str | None] = []

    for char in wave:
        if char == ".":
            pass
        elif char in "01xz":
            current = char
        elif char == "=":
            if data_index < len(data):
                current = data[data_index]
                data_index += 1
        values.append(current)

    if len(values) < depth + 1:
        values.extend([current] * (depth + 1 - len(values)))
    return values[1 : depth + 1]


def load_counterexample_signals(dump_path: Path) -> dict[str, dict[str, object]]:
    text = dump_path.read_text(encoding="utf-8")
    payload = json.loads(text.replace("\\", "\\\\"))
    return {
        str(signal["name"]): signal
        for signal in payload.get("signal", [])
        if isinstance(signal, dict) and "name" in signal
    }


def build_counterexample(
    dump_path: Path,
    depth: int,
    input_ports: list[str],
    output_ports: list[str],
) -> tuple[str, dict[str, object] | None]:
    if not dump_path.exists():
        return "", None

    signals = load_counterexample_signals(dump_path)
    trigger_values = expand_wave_values(signals.get("trigger", {}), depth)
    input_series = {
        name: expand_wave_values(signals.get(f"in_{name}", {}), depth) for name in input_ports
    }
    gold_series = {
        name: expand_wave_values(signals.get(f"gold.{name}", {}), depth) for name in output_ports
    }
    gate_series = {
        name: expand_wave_values(signals.get(f"gate.{name}", {}), depth) for name in output_ports
    }

    trace: list[dict[str, object]] = []
    failing_step: int | None = None
    mismatch_outputs: dict[str, dict[str, dict[str, str] | None]] = {}

    for step in range(1, depth + 1):
        inputs = {
            name: format_logic_value(input_series[name][step - 1])
            for name in input_ports
        }
        gold_outputs = {
            name: format_logic_value(gold_series[name][step - 1])
            for name in output_ports
        }
        gate_outputs = {
            name: format_logic_value(gate_series[name][step - 1])
            for name in output_ports
        }

        trigger = trigger_values[step - 1]
        trace.append(
            {
                "step": step,
                "trigger": trigger,
                "inputs": inputs,
                "gold_outputs": gold_outputs,
                "gate_outputs": gate_outputs,
            }
        )

        if failing_step is None and trigger == "1":
            failing_step = step
            mismatch_outputs = {
                name: {"gold": gold_outputs[name], "gate": gate_outputs[name]}
                for name in output_ports
                if gold_outputs[name] != gate_outputs[name]
            }

    if failing_step is None:
        for item in trace:
            mismatch_outputs = {
                name: {"gold": item["gold_outputs"][name], "gate": item["gate_outputs"][name]}
                for name in output_ports
                if item["gold_outputs"][name] != item["gate_outputs"][name]
            }
            if mismatch_outputs:
                failing_step = int(item["step"])
                break

    if failing_step is None:
        return "", None

    summary = f"step {failing_step} failed"

    return summary, {
        "failing_step": failing_step,
        "mismatch_outputs": mismatch_outputs,
        "trace": trace,
    }


def find_module_block(path: Path, module_name: str) -> re.Match[str]:
    text = strip_comments(path.read_text(encoding="utf-8", errors="ignore"))
    for match in MODULE_BLOCK_RE.finditer(text):
        if match.group(1) == module_name:
            return match
    raise ValueError(f"Module {module_name} not found in {path}")


def normalize_width(width: str | None) -> str | None:
    if width is None:
        return None
    return " ".join(width.replace("\n", " ").split())


def parse_header_port_names(header_text: str) -> tuple[str, ...]:
    names: list[str] = []
    for raw_token in header_text.replace("\n", " ").split(","):
        token = raw_token.strip()
        if not token:
            continue
        match = re.search(r"([A-Za-z_][\w$]*)\s*$", token)
        if match is None:
            raise ValueError(f"Failed to parse port token: {token}")
        names.append(match.group(1))
    return tuple(names)


def parse_port_map(module_match: re.Match[str]) -> dict[str, PortInfo]:
    port_map: dict[str, PortInfo] = {}

    header_text = module_match.group(2)
    for raw_token in header_text.replace("\n", " ").split(","):
        token = raw_token.strip()
        if not token:
            continue
        match = ANSI_PORT_RE.match(token)
        if match is None:
            continue
        direction, width, name = match.groups()
        port_map[name] = PortInfo(direction=direction, width=normalize_width(width))

    body_text = module_match.group(3)
    for match in BODY_DECL_RE.finditer(body_text):
        direction, width, names_text = match.groups()
        for raw_name in names_text.split(","):
            name = raw_name.strip()
            if not name:
                continue
            init_pos = name.find("=")
            if init_pos >= 0:
                name = name[:init_pos].strip()
            if not re.fullmatch(r"[A-Za-z_][\w$]*", name):
                continue
            port_map[name] = PortInfo(direction=direction, width=normalize_width(width))

    return port_map


def extract_module_interface(path: Path, module_name: str) -> ModuleInterface:
    module_match = find_module_block(path, module_name)
    ordered_ports = parse_header_port_names(module_match.group(2))
    return ModuleInterface(
        module_name=module_name,
        ordered_ports=ordered_ports,
        ports=parse_port_map(module_match),
    )


def compare_interfaces(reference: ModuleInterface, candidate: ModuleInterface) -> tuple[bool, str]:
    ref_ports = set(reference.ordered_ports)
    cand_ports = set(candidate.ordered_ports)

    missing = sorted(ref_ports - cand_ports)
    extra = sorted(cand_ports - ref_ports)
    if missing or extra:
        return False, "missing ports:"

    mismatches: list[str] = []
    for name in reference.ordered_ports:
        ref_info = reference.ports.get(name)
        cand_info = candidate.ports.get(name)
        if ref_info is None or cand_info is None:
            continue
        if ref_info.direction and cand_info.direction and ref_info.direction != cand_info.direction:
            mismatches.append(
                f"{name} direction mismatch ({ref_info.direction} vs {cand_info.direction})"
            )
        if ref_info.width and cand_info.width and ref_info.width != cand_info.width:
            mismatches.append(f"{name} width mismatch ({ref_info.width} vs {cand_info.width})")

    if mismatches:
        return False, "missing ports:"
    return True, "Interfaces match"


def collect_included_filenames(files: list[Path]) -> set[str]:
    names: set[str] = set()
    for file in files:
        text = strip_comments(file.read_text(encoding="utf-8", errors="ignore"))
        names.update(INCLUDE_RE.findall(text))
    return names


def infer_include_dirs(files: list[Path], search_roots: list[Path]) -> list[Path]:
    include_dirs = {file.parent.resolve() for file in files}
    filenames = collect_included_filenames(files)
    search_cache: dict[tuple[Path, str], list[Path]] = {}

    for filename in filenames:
        for root in search_roots:
            key = (root.resolve(), filename)
            if key not in search_cache:
                search_cache[key] = list(root.rglob(filename))
            for match in search_cache[key]:
                include_dirs.add(match.parent.resolve())

    return sorted(include_dirs)


def discover_reference_file(reference_path: Path) -> Path:
    if reference_path.is_file():
        return reference_path.resolve()
    if not reference_path.is_dir():
        raise FileNotFoundError(f"Reference path not found: {reference_path}")

    verilog_files = sorted(reference_path.glob("*.v"))
    if not verilog_files:
        raise FileNotFoundError(f"No Verilog file found in {reference_path}")
    if len(verilog_files) > 1:
        raise ValueError(
            f"Reference directory must contain exactly one Verilog file, found {len(verilog_files)}"
        )
    return verilog_files[0].resolve()


def discover_support_files(support_root: Path, reference_file: Path) -> list[Path]:
    if not support_root.exists():
        return []
    return sorted(
        path.resolve()
        for path in support_root.glob("*/*.v")
        if path.resolve() != reference_file.resolve()
    )


def prepare_or1200_support_workspace(
    support_root: Path, reference_file: Path
) -> tuple[Path, Path, list[Path], Path]:
    tempdir = Path(tempfile.mkdtemp(prefix="or1200_equiv_ref_"))
    temp_ref_root = tempdir / "verilog"
    temp_ref_root.mkdir(parents=True, exist_ok=False)

    defines = support_root / "or1200_defines.v"
    if defines.exists():
        shutil.copy2(defines, temp_ref_root / defines.name)

    copied_support_files: list[Path] = []
    for src in sorted(support_root.glob("*/*.v")):
        dest = temp_ref_root / src.name
        shutil.copy2(src, dest)
        if src.name != "or1200_defines.v":
            copied_support_files.append(dest)

    repair_or1200_reference_root(temp_ref_root)
    primitives = temp_ref_root / "or1200_temp_primitives.v"
    primitives.write_text(build_or1200_primitive_models(), encoding="ascii")
    copied_support_files.append(primitives)

    prepared_reference = temp_ref_root / reference_file.name
    support_files = sorted(path for path in copied_support_files if path != prepared_reference)
    return tempdir, temp_ref_root, support_files, prepared_reference


def discover_candidate_groups(candidate_path: Path, module_dir: str) -> list[tuple[str, Path]]:
    if not candidate_path.exists():
        raise FileNotFoundError(f"Candidate path not found: {candidate_path}")

    if candidate_path.is_dir():
        direct_files = sorted(candidate_path.glob("*.v"))
        if direct_files:
            model = candidate_path.parent.name if candidate_path.name == module_dir else candidate_path.name
            return [(model, file.resolve()) for file in direct_files]

        grouped_files = sorted(candidate_path.glob(f"*/{module_dir}/*.v"))
        if grouped_files:
            return [(file.parent.parent.name, file.resolve()) for file in grouped_files]

    raise FileNotFoundError(
        f"No candidate Verilog files found under {candidate_path} for module {module_dir}"
    )


def precheck_design(
    yosys: str,
    files: list[Path],
    include_dirs: list[Path],
    top: str,
    timeout: int,
) -> tuple[bool, str]:
    ok, output = run_yosys_script(
        yosys,
        build_precheck_script(files=files, include_dirs=include_dirs, top=top),
        timeout,
    )
    if ok:
        return True, "pass"
    return False, summarize_error(output)


def run_equivalence(
    yosys: str,
    gold_files: list[Path],
    gate_files: list[Path],
    reference_top: str,
    candidate_top: str,
    reference_includes: list[Path],
    candidate_includes: list[Path],
    input_ports: list[str],
    output_ports: list[str],
    proof_type: str,
    has_rst: bool,
    depth: int,
    timeout: int,
) -> tuple[str, str, str, dict[str, object] | None]:
    proof_script = build_proof_script(
        gold_files=gold_files,
        gold_includes=reference_includes,
        gate_files=gate_files,
        gate_includes=candidate_includes,
        reference_top=reference_top,
        candidate_top=candidate_top,
        proof_type=proof_type,
        seq_depth=depth,
        has_rst=has_rst,
    )
    sat_options = ["-show-inputs", "-show-public", "-show", "trigger"]

    with tempfile.TemporaryDirectory(prefix="yosys_result_equiv_") as tempdir_name:
        tempdir = Path(tempdir_name)
        dump_path = tempdir / "counterexample.json"
        script_lines = proof_script.splitlines()
        for index, line in enumerate(script_lines):
            if line.startswith("sat "):
                script_lines[index] = line + " " + " ".join(
                    [*sat_options, "-dump_json", str(dump_path)]
                )
                break
        script_path = tempdir / "run.ys"
        script_path.write_text("\n".join(script_lines), encoding="ascii")

        try:
            result = subprocess.run(
                [yosys, "-s", str(script_path)],
                text=True,
                capture_output=True,
                timeout=timeout,
                check=False,
            )
        except subprocess.TimeoutExpired:
            return "tool_limited", f"Timeout after {timeout}s", "", None

        output = clean_output((result.stdout or "") + (result.stderr or ""))
        ok = result.returncode == 0

        if "SAT proof finished - no model found: SUCCESS!" in output:
            if proof_type == "strict_comb":
                return "equivalent", "Strict combinational proof passed", "", None
            return "equivalent", f"Bounded proof passed within {depth} cycles", "", None

        if "SAT proof finished - model found: FAIL!" in output:
            counterexample_summary, counterexample = build_counterexample(
                dump_path=dump_path,
                depth=depth,
                input_ports=input_ports,
                output_ports=output_ports,
            )
            return (
                "not_equivalent",
                "找到反例，候选设计与参考设计不等价",
                counterexample_summary,
                counterexample,
            )

        if ok:
            return "tool_limited", summarize_error(output), "", None
        return "tool_limited", summarize_error(output), "", None


def write_report(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def print_result(result: CompareResult) -> None:
    suffix = f" counterexample={result.counterexample_summary}" if result.counterexample_summary else ""
    print(
        f"{result.model}/{Path(result.candidate_file).name}: "
        f"gold={result.reference_precheck} "
        f"gate={result.candidate_precheck} "
        f"interface={result.interface_status} "
        f"formal={result.formal_status} "
        f"reason={result.reason}{suffix}"
    )


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(
        description="Run formal equivalence checking for one reference Verilog against many candidates."
    )
    parser.add_argument(
        "--reference",
        type=Path,
        default=repo_root / "Src" / "or1200_hp" / "des" / "verilog" / "or1200_alu",
        help="Reference Verilog file or a directory containing exactly one .v file.",
    )
    parser.add_argument(
        "--candidates",
        type=Path,
        default=repo_root / "Result",
        help="Candidate directory. Supports a single module directory or a Result root.",
    )
    parser.add_argument(
        "--module-dir",
        default="or1200_alu",
        help="Module subdirectory name to scan under Result, for example or1200_alu.",
    )
    parser.add_argument(
        "--support-root",
        type=Path,
        default=None,
        help="Optional family root that contains sibling reference modules used as dependencies.",
    )
    parser.add_argument(
        "--include-dir",
        action="append",
        default=[],
        type=Path,
        help="Extra include directory. Can be used multiple times.",
    )
    parser.add_argument("--yosys", default="yosys")
    parser.add_argument("--depth", type=int, default=8)
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument(
        "--report",
        type=Path,
        default=repo_root / "reports" / "formal_equivalence_or1200_alu_all_results.json",
    )
    parser.add_argument(
        "--csv-report",
        type=Path,
        default=repo_root / "reports" / "formal_equivalence_or1200_alu_all_results.csv",
    )
    return parser.parse_args()


def summarize_counts(results: list[CompareResult], key: str) -> dict[str, int]:
    return dict(sorted(Counter(getattr(result, key) for result in results).items()))


def summarize_nested_counts(
    results: list[CompareResult], primary_key: str, secondary_key: str
) -> dict[str, dict[str, int]]:
    counts: dict[str, Counter[str]] = defaultdict(Counter)
    for result in results:
        counts[getattr(result, primary_key)][getattr(result, secondary_key)] += 1
    return {
        primary: dict(sorted(counter.items()))
        for primary, counter in sorted(counts.items(), key=lambda item: item[0])
    }


def main() -> int:
    args = parse_args()
    yosys = shutil.which(args.yosys)
    if yosys is None:
        print(f"Tool not found: {args.yosys}", file=sys.stderr)
        return 2

    repo_root = Path(__file__).resolve().parent.parent
    reference_file = discover_reference_file(args.reference)
    support_root = (
        args.support_root.resolve()
        if args.support_root is not None
        else reference_file.parent.parent.resolve()
    )
    temp_cleanup_root: Path | None = None

    try:
        if args.module_dir.startswith("or1200_"):
            (
                temp_cleanup_root,
                effective_support_root,
                support_files,
                reference_file,
            ) = prepare_or1200_support_workspace(support_root, reference_file)
        else:
            effective_support_root = support_root
            support_files = discover_support_files(support_root, reference_file)

        candidate_groups = discover_candidate_groups(args.candidates.resolve(), args.module_dir)

        reference_top = extract_module_info(reference_file).name
        reference_interface = extract_module_interface(reference_file, reference_top)
        input_ports = [
            name for name in reference_interface.ordered_ports
            if reference_interface.ports[name].direction == "input"
        ]
        output_ports = [
            name for name in reference_interface.ordered_ports
            if reference_interface.ports[name].direction == "output"
        ]
        search_roots = [repo_root]
        extra_include_dirs = [path.resolve() for path in args.include_dir]
        gold_files = [reference_file, *support_files]
        reference_proof_type = detect_proof_type(gold_files, reference_top)
        if reference_proof_type not in {"strict_comb", "bounded_seq"}:
            reference_proof_type = "bounded_seq"
        reference_include_dirs = sorted(
            set(infer_include_dirs(gold_files, search_roots) + extra_include_dirs)
        )

        gold_ok, gold_msg = precheck_design(
            yosys=yosys,
            files=gold_files,
            include_dirs=reference_include_dirs,
            top=reference_top,
            timeout=args.timeout,
        )

        results: list[CompareResult] = []
        for model, candidate_file in candidate_groups:
            candidate_top = extract_module_info(candidate_file).name
            candidate_interface = extract_module_interface(candidate_file, candidate_top)
            gate_files = [candidate_file, *support_files]
            candidate_proof_type = detect_proof_type(gate_files, candidate_top)
            if candidate_proof_type not in {"strict_comb", "bounded_seq"}:
                candidate_proof_type = "bounded_seq"
            proof_type = (
                "bounded_seq"
                if "bounded_seq" in {reference_proof_type, candidate_proof_type}
                else "strict_comb"
            )
            candidate_include_dirs = sorted(
                set(infer_include_dirs(gate_files, search_roots) + extra_include_dirs)
            )
            gate_ok, gate_msg = precheck_design(
                yosys=yosys,
                files=gate_files,
                include_dirs=candidate_include_dirs,
                top=candidate_top,
                timeout=args.timeout,
            )

            if not gold_ok:
                result = CompareResult(
                    model=model,
                    module_dir=args.module_dir,
                    candidate_file=str(candidate_file),
                    reference_file=str(reference_file),
                    reference_top=reference_top,
                    candidate_top=candidate_top,
                    reference_precheck="fail",
                    candidate_precheck="pass" if gate_ok else "fail",
                    interface_status="skip",
                    formal_status="skip",
                    proof_type=proof_type,
                    reason=f"Reference precheck failed: {gold_msg}",
                    counterexample_summary="",
                    counterexample=None,
                )
                results.append(result)
                print_result(result)
                continue

            if not gate_ok:
                result = CompareResult(
                    model=model,
                    module_dir=args.module_dir,
                    candidate_file=str(candidate_file),
                    reference_file=str(reference_file),
                    reference_top=reference_top,
                    candidate_top=candidate_top,
                    reference_precheck="pass",
                    candidate_precheck="fail",
                    interface_status="skip",
                    formal_status="skip",
                    proof_type=proof_type,
                    reason=f"Candidate precheck failed: {gate_msg}",
                    counterexample_summary="",
                    counterexample=None,
                )
                results.append(result)
                print_result(result)
                continue

            compatible, interface_reason = compare_interfaces(reference_interface, candidate_interface)
            if not compatible:
                result = CompareResult(
                    model=model,
                    module_dir=args.module_dir,
                    candidate_file=str(candidate_file),
                    reference_file=str(reference_file),
                    reference_top=reference_top,
                    candidate_top=candidate_top,
                    reference_precheck="pass",
                    candidate_precheck="pass",
                    interface_status="incompatible",
                    formal_status="skip",
                    proof_type=proof_type,
                    reason=interface_reason,
                    counterexample_summary="",
                    counterexample=None,
                )
                results.append(result)
                print_result(result)
                continue

            formal_status, reason, counterexample_summary, counterexample = run_equivalence(
                yosys=yosys,
                gold_files=gold_files,
                gate_files=gate_files,
                reference_top=reference_top,
                candidate_top=candidate_top,
                reference_includes=reference_include_dirs,
                candidate_includes=candidate_include_dirs,
                input_ports=input_ports,
                output_ports=output_ports,
                proof_type=proof_type,
                has_rst="rst" in candidate_interface.ports,
                depth=args.depth,
                timeout=args.timeout,
            )
            result = CompareResult(
                model=model,
                module_dir=args.module_dir,
                candidate_file=str(candidate_file),
                reference_file=str(reference_file),
                reference_top=reference_top,
                candidate_top=candidate_top,
                reference_precheck="pass",
                candidate_precheck="pass",
                interface_status="compatible",
                formal_status=formal_status,
                proof_type=proof_type,
                reason=reason,
                counterexample_summary=counterexample_summary,
                counterexample=counterexample,
            )
            results.append(result)
            print_result(result)

        summary = {
            "reference_file": str(reference_file),
            "candidate_path": str(args.candidates.resolve()),
            "module_dir": args.module_dir,
            "depth": args.depth,
            "timeout": args.timeout,
            "yosys": yosys,
            "results": [asdict(result) for result in results],
            "total_candidates": len(results),
            "counts": summarize_counts(results, "formal_status"),
            "interface_counts": summarize_counts(results, "interface_status"),
            "precheck_counts": summarize_counts(results, "candidate_precheck"),
            "model_counts": summarize_counts(results, "model"),
            "formal_status_by_model": summarize_nested_counts(results, "model", "formal_status"),
            "interface_status_by_model": summarize_nested_counts(results, "model", "interface_status"),
        }
        write_report(args.report.resolve(), summary)
        write_csv_report(args.csv_report.resolve(), results)
        print(f"Report written to {args.report.resolve()}")
        print(f"CSV report written to {args.csv_report.resolve()}")

        success = all(result.formal_status == "equivalent" for result in results)
        return 0 if success else 1
    finally:
        if temp_cleanup_root is not None:
            shutil.rmtree(temp_cleanup_root, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
