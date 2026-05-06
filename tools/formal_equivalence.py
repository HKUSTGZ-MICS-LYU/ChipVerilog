#!/usr/bin/env python3
from __future__ import annotations

import argparse
import concurrent.futures
import csv
import functools
import json
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Callable


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parent.parent

MODULE_BLOCK_RE = re.compile(
    r"\bmodule\s+([A-Za-z_][\w$]*)\s*(?:#\s*\(.*?\)\s*)?\((.*?)\)\s*;(.*?)\bendmodule\b",
    re.S,
)
EDGE_TRIGGER_RE = re.compile(
    r"\balways(?:_ff)?\b\s*@\s*\([^)]*\b(?:posedge|negedge)\b",
    re.I | re.S,
)
BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.S)
LINE_COMMENT_RE = re.compile(r"//.*?$", re.M)
INSTANCE_RE = re.compile(
    r"^\s*([A-Za-z_][\w$]*)\s+(?:#\s*\([^;]*?\)\s*)?([A-Za-z_][\w$]*)\s*\(",
    re.M,
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
MODULE_DECL_RE = re.compile(r"\bmodule\s+([A-Za-z_][\w$]*)\b")
ATTEMPT_RE = re.compile(r"_t(?P<attempt>\d+)\.v$")
JASPER_ERROR_RE = re.compile(r"\b(?:ERROR|FATAL)\b")
TARGET_RE = re.compile(r"^(?P<base>.+)_t(?P<index>\d+)$")
COMPILE_EXPECTED_ATTEMPTS = 5
CORDIC_TESTBENCH_OUTPUT_ERROR_RE = re.compile(r"\berrors?\b", re.I)
COMPILE_ERROR_LINE_RE = re.compile(r"\b(?:error|syntax error|errors in)\b", re.I)
SIGNED_SHIFTER_MODULE_RE = re.compile(
    r"(?P<header>\bmodule\s+signed_shifter\b.*?;\s*)(?P<body>.*?)(?P<footer>\bendmodule\b)",
    re.S,
)
SIGNED_SHIFTER_LOOP_BODY_RE = re.compile(
    r"always\s*@\s*\*\s*begin\s*"
    r"Q\s*=\s*D\s*;\s*"
    r"for\s*\(\s*j\s*=\s*0\s*;\s*j\s*<\s*i\s*;\s*j\s*=\s*j\s*\+\s*1\s*\)\s*begin\s*"
    r"Q\s*=\s*\{\s*D\[(?:`)?XY_BITS\]\s*,\s*Q\[(?:`)?XY_BITS:1\]\s*\}\s*;\s*"
    r"end\s*end",
    re.S,
)
CORDIC_TESTBENCH_DEFAULT_DEFINES: tuple[tuple[str, str], ...] = (
    ("PIPELINE", ""),
    ("ROTATE", ""),
    ("RADIAN_16", ""),
    ("XY_BITS", "16"),
    ("THETA_BITS", "16"),
    ("ITERATIONS", "16"),
    ("ITERATION_BITS", "4"),
    ("CORDIC_GAIN", "17'd53955"),
    ("CORDIC_1", "17'd19896"),
)
CORDIC_TESTBENCH_PATH = REPO_ROOT / "Src" / "verilog_cordic_core" / "rtl" / "tb_cordic.v"
MIPS_PREFIX_SHIM_NAMES: tuple[str, ...] = (
    "mips_16_defs.v",
    "defines.v",
    "define.v",
    "mips_16_define.v",
)
I2C_PREFIX_FILE_NAMES: tuple[str, ...] = (
    "timescale.v",
    "i2c_master_defines.v",
)


@dataclass(frozen=True)
class ModuleInfo:
    name: str
    ports: tuple[str, ...]
    has_edge_triggered_logic: bool
    dependencies: tuple[str, ...]


@dataclass(frozen=True)
class PortInfo:
    direction: str | None
    width: str | None


@dataclass(frozen=True)
class ModuleInterface:
    module_name: str
    ordered_ports: tuple[str, ...]
    ports: dict[str, PortInfo]


@dataclass(frozen=True)
class NormalizedPortInfo:
    direction: str
    width_bits: int


@dataclass(frozen=True)
class NormalizedModuleInterface:
    module_name: str
    ordered_ports: tuple[str, ...]
    ports: dict[str, NormalizedPortInfo]


@dataclass(frozen=True)
class GateWrapperSpec:
    raw_candidate_top: str
    wrapper_top: str
    impl_top: str
    canonical_to_candidate: dict[str, str]


@dataclass(frozen=True)
class InterfaceComparison:
    compatible: bool
    interface_reason_kind: str
    interface_reason: str
    aliases_applied: tuple[dict[str, str], ...]
    gate_wrapper: GateWrapperSpec | None


@dataclass
class CompareResult:
    backend: str
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
    reason_bucket: str
    reason: str
    interface_reason_kind: str
    interface_reason: str
    interface_aliases_applied: list[dict[str, str]]
    counterexample_summary: str
    counterexample: dict[str, object] | None


@dataclass(frozen=True)
class CordicTestbenchOutcome:
    compile_ok: bool
    run_ok: bool
    compile_output: str
    run_output: str


@dataclass(frozen=True)
class SupportDesignContext:
    cleanup_root: Path | None
    effective_support_root: Path
    prefix_files: tuple[Path, ...]
    support_files: tuple[Path, ...]
    proof_support_files: tuple[Path, ...]
    reference_file: Path


@dataclass(frozen=True)
class CompileModuleContext:
    family: str
    module_dir: str
    family_root: Path
    reference_file: Path
    expected_top: str | None
    top_error: str | None
    support_context: SupportDesignContext | None
    prefix_files: tuple[Path, ...]
    support_files: tuple[Path, ...]
    search_roots: tuple[Path, ...]


@dataclass(frozen=True)
class CompileDetailRow:
    model: str
    family: str
    module_dir: str
    candidate_file: str
    attempt: int | None
    scope: str
    expected_top: str
    status: str
    exit_code: int
    error_excerpt: str


def strip_comments(text: str) -> str:
    text = BLOCK_COMMENT_RE.sub("", text)
    return LINE_COMMENT_RE.sub("", text)


def ordered_unique(items: list[str]) -> list[str]:
    ordered: list[str] = []
    seen: set[str] = set()
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        ordered.append(item)
    return ordered


@functools.lru_cache(maxsize=None)
def extract_tolerant_module_names(path: Path) -> tuple[str, ...]:
    stripped = strip_comments(path.read_text(encoding="utf-8", errors="ignore"))
    return tuple(MODULE_DECL_RE.findall(stripped))


@functools.lru_cache(maxsize=None)
def extract_unique_tolerant_module_names(path: Path) -> tuple[str, ...]:
    return tuple(ordered_unique(list(extract_tolerant_module_names(path))))


def extract_all_module_infos(path: Path) -> dict[str, ModuleInfo]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    stripped = strip_comments(text)
    matches = list(MODULE_BLOCK_RE.finditer(stripped))
    if not matches:
        raise ValueError(f"Failed to parse module header from {path}")

    infos: dict[str, ModuleInfo] = {}
    for match in matches:
        ports = tuple(
            token.strip()
            for token in match.group(2).replace("\n", " ").split(",")
            if token.strip()
        )
        block = match.group(0)
        info = ModuleInfo(
            name=match.group(1),
            ports=ports,
            has_edge_triggered_logic=bool(EDGE_TRIGGER_RE.search(block)),
            dependencies=(),
        )
        if info.name in infos:
            raise ValueError(f"Duplicate module name {info.name} in {path}")
        infos[info.name] = info
    return infos


def extract_module_info(path: Path) -> ModuleInfo:
    infos = extract_all_module_infos(path)
    return next(iter(infos.values()))


def collect_module_infos(files: list[Path]) -> dict[str, ModuleInfo]:
    module_blocks: dict[str, str] = {}
    infos: dict[str, ModuleInfo] = {}

    for file in files:
        try:
            file_infos = extract_all_module_infos(file)
        except ValueError:
            continue
        stripped = strip_comments(file.read_text(encoding="utf-8", errors="ignore"))
        for match in MODULE_BLOCK_RE.finditer(stripped):
            name = match.group(1)
            if name in infos:
                raise ValueError(f"Duplicate module name {name} in {file}")
            infos[name] = file_infos[name]
            module_blocks[name] = match.group(0)

    known_modules = set(infos)
    enriched: dict[str, ModuleInfo] = {}
    for name, info in infos.items():
        deps = {
            match.group(1)
            for match in INSTANCE_RE.finditer(module_blocks[name])
            if match.group(1) in known_modules and match.group(1) != name
        }
        enriched[name] = ModuleInfo(
            name=info.name,
            ports=info.ports,
            has_edge_triggered_logic=info.has_edge_triggered_logic,
            dependencies=tuple(sorted(deps)),
        )
    return enriched


def detect_proof_type(files: list[Path], top_module: str) -> str:
    try:
        infos = collect_module_infos(files)
    except ValueError:
        return "unknown"

    if top_module not in infos:
        return "unknown"

    stack = [top_module]
    seen: set[str] = set()
    while stack:
        current = stack.pop()
        if current in seen:
            continue
        seen.add(current)
        info = infos[current]
        if info.has_edge_triggered_logic:
            return "bounded_seq"
        stack.extend(dep for dep in info.dependencies if dep not in seen)
    return "strict_comb"


def ys_quote(value: str | Path) -> str:
    text = str(value).replace("\\", "/")
    return '"' + text.replace('"', '\\"') + '"'


def format_read_verilog(
    files: list[Path],
    include_dirs: list[Path],
    *,
    library: bool = False,
) -> str:
    includes = " ".join(f"-I{Path(path).as_posix()}" for path in include_dirs)
    file_args = " ".join(ys_quote(path) for path in files)
    library_flag = " -lib" if library else ""
    return f"read_verilog -sv{library_flag} {includes} {file_args}".strip()


def clean_output(text: str) -> str:
    lines = []
    for line in text.splitlines():
        stripped = line.rstrip()
        if not stripped or "setlocale: LC_ALL" in stripped:
            continue
        lines.append(stripped)
    return "\n".join(lines) if lines else "No output"


def summarize_error(output: str) -> str:
    lines = output.splitlines()
    errors = [line for line in lines if line.startswith("ERROR:")]
    if errors:
        return errors[-1]
    return lines[-1] if lines else "No output"


def run_command_details(cmd: list[str], cwd: Path, timeout: int) -> tuple[bool, str, int]:
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return False, f"Timeout after {timeout}s", -1

    output = clean_output((result.stdout or "") + (result.stderr or ""))
    return result.returncode == 0, output, result.returncode


def run_command(cmd: list[str], cwd: Path, timeout: int) -> tuple[bool, str]:
    ok, output, _ = run_command_details(cmd, cwd=cwd, timeout=timeout)
    return ok, output


def extract_defined_macros(text: str) -> set[str]:
    return {
        match.group(1)
        for match in re.finditer(r"(?m)^\s*`define\s+([A-Za-z_][\w$]*)\b", text)
    }


def build_cordic_candidate_source(candidate_file: Path) -> str:
    candidate_text = candidate_file.read_text(encoding="utf-8", errors="ignore")
    return inject_missing_cordic_default_defines(candidate_text)


def inject_missing_cordic_default_defines(candidate_text: str) -> str:
    defined = extract_defined_macros(candidate_text)
    prefix_lines: list[str] = []
    for macro_name, macro_value in CORDIC_TESTBENCH_DEFAULT_DEFINES:
        if macro_name in defined:
            continue
        if macro_value:
            prefix_lines.append(f"`define {macro_name} {macro_value}")
        else:
            prefix_lines.append(f"`define {macro_name}")
    if not prefix_lines:
        return candidate_text
    return "\n".join([*prefix_lines, candidate_text])


def rewrite_signed_shifter_module_text(text: str) -> tuple[str, bool]:
    module_match = SIGNED_SHIFTER_MODULE_RE.search(text)
    if module_match is None:
        return text, False

    body = module_match.group("body")
    rewritten_body, replacements = SIGNED_SHIFTER_LOOP_BODY_RE.subn(
        "always @ * begin\n    Q = $signed(D) >>> i;\n  end",
        body,
        count=1,
    )
    if replacements == 0:
        return text, False

    rewritten_module = "".join(
        [
            module_match.group("header"),
            rewritten_body,
            module_match.group("footer"),
        ]
    )
    return (
        text[: module_match.start()]
        + rewritten_module
        + text[module_match.end() :],
        True,
    )


def build_formal_friendly_cordic_source(source_file: Path) -> str:
    text = source_file.read_text(encoding="utf-8", errors="ignore")
    rewritten_text, _ = rewrite_signed_shifter_module_text(text)
    return rewritten_text


def requires_formal_friendly_cordic_rewrite(module_dir: str) -> bool:
    return module_dir in {"signed_shifter", "rotator"}


def copy_formal_friendly_verilog_file(source_file: Path, destination_file: Path) -> bool:
    destination_file.parent.mkdir(parents=True, exist_ok=True)
    rewritten_text, changed = rewrite_signed_shifter_module_text(
        source_file.read_text(encoding="utf-8", errors="ignore")
    )
    destination_file.write_text(rewritten_text, encoding="utf-8")
    return changed


def prepare_formal_friendly_cordic_support_context(
    support_context: SupportDesignContext,
) -> SupportDesignContext:
    tempdir = Path(tempfile.mkdtemp(prefix="cordic_formal_ref_"))
    temp_root = tempdir / "support"
    temp_root.mkdir(parents=True, exist_ok=False)

    path_map: dict[Path, Path] = {}

    def copy_path(path: Path) -> Path:
        resolved = path.resolve()
        existing = path_map.get(resolved)
        if existing is not None:
            return existing
        destination = temp_root / resolved.name
        copy_formal_friendly_verilog_file(resolved, destination)
        destination = destination.resolve()
        path_map[resolved] = destination
        return destination

    return SupportDesignContext(
        cleanup_root=tempdir,
        effective_support_root=temp_root.resolve(),
        prefix_files=tuple(copy_path(path) for path in support_context.prefix_files),
        support_files=tuple(copy_path(path) for path in support_context.support_files),
        proof_support_files=tuple(copy_path(path) for path in support_context.proof_support_files),
        reference_file=copy_path(support_context.reference_file),
    )


def prepare_formal_friendly_candidate_file(module_dir: str, candidate_file: Path) -> tuple[Path, Path | None]:
    if not requires_formal_friendly_cordic_rewrite(module_dir):
        return candidate_file.resolve(), None
    tempdir = Path(tempfile.mkdtemp(prefix="cordic_formal_candidate_"))
    rewritten_candidate = tempdir / candidate_file.name
    rewritten_text, _ = rewrite_signed_shifter_module_text(
        candidate_file.resolve().read_text(encoding="utf-8", errors="ignore")
    )
    rewritten_candidate.write_text(
        inject_missing_cordic_default_defines(rewritten_text),
        encoding="utf-8",
    )
    return rewritten_candidate.resolve(), tempdir.resolve()


def extract_cordic_testbench_failure_lines(output: str) -> list[str]:
    return [
        line.strip()
        for line in output.splitlines()
        if CORDIC_TESTBENCH_OUTPUT_ERROR_RE.search(line)
    ]


def summarize_lines(lines: list[str], *, limit: int = 3) -> str:
    if not lines:
        return ""
    return " | ".join(lines[:limit])


def run_cordic_testbench(candidate_file: Path, timeout: int) -> CordicTestbenchOutcome:
    iverilog = shutil.which("iverilog")
    if iverilog is None:
        raise FileNotFoundError("Tool not found: iverilog")
    vvp = shutil.which("vvp")
    if vvp is None:
        raise FileNotFoundError("Tool not found: vvp")
    if not CORDIC_TESTBENCH_PATH.exists():
        raise FileNotFoundError(f"CORDIC testbench not found: {CORDIC_TESTBENCH_PATH}")

    with tempfile.TemporaryDirectory(prefix="cordic_tb_") as tempdir_name:
        tempdir = Path(tempdir_name)
        (tempdir / "tb_cordic.v").write_text(
            CORDIC_TESTBENCH_PATH.read_text(encoding="utf-8", errors="ignore"),
            encoding="utf-8",
        )
        (tempdir / "cordic.v").write_text(
            build_cordic_candidate_source(candidate_file),
            encoding="utf-8",
        )

        compile_ok, compile_output, _ = run_command_details(
            [iverilog, "-g2012", "-o", "simv", "tb_cordic.v"],
            cwd=tempdir,
            timeout=timeout,
        )
        if not compile_ok:
            return CordicTestbenchOutcome(
                compile_ok=False,
                run_ok=False,
                compile_output=compile_output,
                run_output="",
            )

        run_ok, run_output, _ = run_command_details(
            [vvp, "simv"],
            cwd=tempdir,
            timeout=timeout,
        )
        return CordicTestbenchOutcome(
            compile_ok=True,
            run_ok=run_ok,
            compile_output=compile_output,
            run_output=run_output,
        )


def run_yosys_script(yosys: str, script: str, timeout: int) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="yosys_batch_equiv_") as tempdir:
        script_path = Path(tempdir) / "run.ys"
        script_path.write_text(script, encoding="ascii")
        return run_command([yosys, "-s", str(script_path)], cwd=REPO_ROOT, timeout=timeout)


def build_precheck_script(files: list[Path], include_dirs: list[Path], top: str) -> str:
    return "\n".join(
        [
            format_read_verilog(files, include_dirs),
            f"hierarchy -check -top {top}",
            "",
        ]
    )


def build_interface_normalization_script(
    files: list[Path],
    include_dirs: list[Path],
    top: str,
    json_path: Path,
    library_files: list[Path] | None = None,
) -> str:
    lines: list[str] = []
    if files:
        lines.append(format_read_verilog(files, include_dirs))
    if library_files:
        lines.append(format_read_verilog(library_files, include_dirs, library=True))
    lines.extend(
        [
            f"hierarchy -check -top {top}",
            "proc",
            f"write_json {json_path.as_posix()}",
            "",
        ]
    )
    return "\n".join(lines)


def build_proof_script(
    gold_files: list[Path],
    gold_includes: list[Path],
    gate_files: list[Path],
    gate_includes: list[Path],
    reference_top: str,
    candidate_top: str,
    proof_type: str,
    seq_depth: int,
    has_rst: bool,
    gate_impl_rename_from: str | None = None,
    gate_impl_rename_to: str | None = None,
) -> str:
    sat_args = [
        "sat",
        "-verify",
        "-prove-asserts",
        "-set-init-zero",
        "-seq",
        str(1 if proof_type == "strict_comb" else seq_depth),
    ]
    if proof_type == "bounded_seq" and has_rst:
        sat_args.extend(["-set", "in_rst", "0", "-set-at", "1", "in_rst", "1"])

    gold_lines = [
        format_read_verilog(gold_files, gold_includes),
        f"hierarchy -check -top {reference_top}",
        "proc; memory; opt",
        "flatten",
        "opt",
        f"rename {reference_top} gold",
        "design -stash gold",
        "design -reset",
    ]

    gate_lines = [format_read_verilog(gate_files, gate_includes)]
    if gate_impl_rename_from is not None and gate_impl_rename_to is not None:
        gate_lines.append(f"rename {gate_impl_rename_from} {gate_impl_rename_to}")
    gate_lines.append(f"hierarchy -check -top {candidate_top}")
    if candidate_top != reference_top:
        gate_lines.append(f"rename {candidate_top} {reference_top}")
    gate_lines.extend(
        [
            "proc; memory; opt",
            "flatten",
            "opt",
            f"rename {reference_top} gate",
            "design -stash gate",
            "design -reset",
            "design -copy-from gold -as gold gold",
            "design -copy-from gate -as gate gate",
            "miter -equiv -make_assert -flatten gold gate miter",
            "hierarchy -top miter",
            "clk2fflogic",
            "opt",
            " ".join(sat_args),
            "",
        ]
    )
    return "\n".join(gold_lines + gate_lines)


def repair_or1200_reference_root(temp_ref_root: Path) -> None:
    ctrl = temp_ref_root / "or1200_ctrl.v"
    ctrl_text = ctrl.read_text(encoding="utf-8")
    old_ctrl = (
        "assign simm = (imm_signextend == 1'b1 ? {{16{id_insn[15]}}, id_insn[15:0]} "
        ": {{16'b0}, id_insn[15:0]};"
    )
    new_ctrl = (
        "assign simm = (imm_signextend == 1'b1 ? {{16{id_insn[15]}}, id_insn[15:0]} "
        ": {{16'b0}, id_insn[15:0]});"
    )
    if old_ctrl in ctrl_text:
        ctrl.write_text(ctrl_text.replace(old_ctrl, new_ctrl, 1), encoding="utf-8")

    genpc = temp_ref_root / "or1200_genpc.v"
    genpc_text = genpc.read_text(encoding="utf-8")
    old_genpc = (
        "\t\tpcreg <= #1 ({(except_prefix ? `OR1200_EXCEPT_EPH1_P : "
        "`OR1200_EXCEPT_EPH0_P), `OR1200_EXCEPT_RESET, `OR1200_EXCEPT_V} - 1 >> 2;"
    )
    new_genpc = (
        "\t\tpcreg <= #1 (({(except_prefix ? `OR1200_EXCEPT_EPH1_P : "
        "`OR1200_EXCEPT_EPH0_P), `OR1200_EXCEPT_RESET, `OR1200_EXCEPT_V} - 1) >> 2);"
    )
    if old_genpc in genpc_text:
        genpc.write_text(genpc_text.replace(old_genpc, new_genpc, 1), encoding="utf-8")

    mult_mac = temp_ref_root / "or1200_mult_mac.v"
    mult_mac_text = mult_mac.read_text(encoding="utf-8")
    old_mult_line = (
        "\t\tmac_stall_r <= #1 (|mac_op | (|mac_op_r1 | (|mac_op_r2)) & id_macrc_op"
    )
    new_mult_line = (
        "\t\tmac_stall_r <= #1 (((|mac_op) | ((|mac_op_r1) | (|mac_op_r2))) & id_macrc_op"
    )
    old_mult_end = "\t\t\t\t;"
    new_mult_end = "\t\t\t\t);"
    if old_mult_line in mult_mac_text and old_mult_end in mult_mac_text:
        mult_mac_text = mult_mac_text.replace(old_mult_line, new_mult_line, 1)
        mult_mac_text = mult_mac_text.replace(old_mult_end, new_mult_end, 1)
        mult_mac.write_text(mult_mac_text, encoding="utf-8")

    sprs = temp_ref_root / "or1200_sprs.v"
    sprs_text = sprs.read_text(encoding="utf-8")
    old_sprs = "\n".join(
        [
            "assign sys_data = (spr_dat_cfgr & read_spr_cfgr_sel_32 |",
            "\t\t  (spr_dat_rf & read_spr_rf_sel_32 |",
            "\t\t  (spr_dat_npc & read_spr_npc_sel_32 |",
            "\t\t  (spr_dat_ppc & read_spr_ppc_sel_32 |",
            "\t\t  (sr_32 & read_spr_sr_sel_32 |",
            "\t\t  (epcr & read_spr_epcr_sel_32 |",
            "\t\t  (eear & read_spr_eear_sel_32 |",
            "\t\t  (esr_32 & read_spr_esr_sel_32);",
        ]
    )
    new_sprs = "\n".join(
        [
            "assign sys_data = (spr_dat_cfgr & read_spr_cfgr_sel_32) |",
            "\t\t  (spr_dat_rf & read_spr_rf_sel_32) |",
            "\t\t  (spr_dat_npc & read_spr_npc_sel_32) |",
            "\t\t  (spr_dat_ppc & read_spr_ppc_sel_32) |",
            "\t\t  (sr_32 & read_spr_sr_sel_32) |",
            "\t\t  (epcr & read_spr_epcr_sel_32) |",
            "\t\t  (eear & read_spr_eear_sel_32) |",
            "\t\t  (esr_32 & read_spr_esr_sel_32);",
        ]
    )
    if old_sprs in sprs_text:
        sprs.write_text(sprs_text.replace(old_sprs, new_sprs, 1), encoding="utf-8")

    defines = temp_ref_root / "or1200_defines.v"
    defines_text = defines.read_text(encoding="utf-8")
    defines_text = re.sub(
        r"(?m)^\s*`define OR1200_RAM_MODELS_VIRTEX\s*$",
        "//`define OR1200_RAM_MODELS_VIRTEX",
        defines_text,
        count=1,
    )
    defines_text = re.sub(
        r"(?m)^\s*//`define OR1200_RFRAM_GENERIC\s*$",
        "`define OR1200_RFRAM_GENERIC",
        defines_text,
        count=1,
    )
    defines.write_text(defines_text, encoding="utf-8")


def build_single_port_ram_module(
    name: str,
    depth: int,
    width: int,
    addr_width: int,
    byte_enable: bool = False,
) -> str:
    if byte_enable:
        write_decl = "input [3:0] we;"
        write_active = "|we"
        apply_word = "\n".join(
            [
                "function [31:0] apply_we;",
                "    input [31:0] old_word;",
                "    input [31:0] new_word;",
                "    input [3:0] we_mask;",
                "    begin",
                "        apply_we = old_word;",
                "        if (we_mask[0]) apply_we[7:0] = new_word[7:0];",
                "        if (we_mask[1]) apply_we[15:8] = new_word[15:8];",
                "        if (we_mask[2]) apply_we[23:16] = new_word[23:16];",
                "        if (we_mask[3]) apply_we[31:24] = new_word[31:24];",
                "    end",
                "endfunction",
            ]
        )
        write_body = "\n".join(
            [
                f"        if ({write_active})",
                "            mem[addr] <= apply_we(mem[addr], di, we);",
                "        if (oe)",
                "            doq <= {write_active} ? apply_we(mem[addr], di, we) : mem[addr];".replace(
                    "{write_active}",
                    write_active,
                ),
            ]
        )
    else:
        write_decl = "input we;"
        apply_word = ""
        write_body = "\n".join(
            [
                "        if (we)",
                "            mem[addr] <= di;",
                "        if (oe)",
                "            doq <= we ? di : mem[addr];",
            ]
        )

    return "\n".join(
        [
            f"module {name}(",
            "`ifdef OR1200_BIST",
            "    mbist_si_i, mbist_so_o, mbist_ctrl_i,",
            "`endif",
            "    clk, rst, ce, we, oe, addr, di, doq",
            ");",
            "`ifdef OR1200_BIST",
            "input mbist_si_i;",
            "input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;",
            "output mbist_so_o;",
            "assign mbist_so_o = mbist_si_i;",
            "`endif",
            "input clk;",
            "input rst;",
            "input ce;",
            write_decl,
            "input oe;",
            f"input [{addr_width - 1}:0] addr;",
            f"input [{width - 1}:0] di;",
            f"output reg [{width - 1}:0] doq;",
            f"reg [{width - 1}:0] mem [0:{depth - 1}];",
            "integer i;",
            apply_word,
            "always @(posedge clk or posedge rst)",
            "    if (rst) begin",
            f"        doq <= {{{width}{{1'b0}}}};",
            f"        for (i = 0; i < {depth}; i = i + 1)",
            f"            mem[i] <= {{{width}{{1'b0}}}};",
            "    end else if (ce) begin",
            write_body,
            "    end",
            "endmodule",
            "",
        ]
    )


def build_abstract_single_port_ram_module(
    name: str,
    width: int,
    addr_width: int,
    byte_enable: bool = False,
) -> str:
    if byte_enable:
        write_decl = "input [3:0] we;"
        write_active = "|we"
        merge_decl = "\n".join(
            [
                "function [31:0] merge_word;",
                "    input [31:0] old_word;",
                "    input [31:0] new_word;",
                "    input [3:0] we_mask;",
                "    begin",
                "        merge_word = old_word;",
                "        if (we_mask[0]) merge_word[7:0] = new_word[7:0];",
                "        if (we_mask[1]) merge_word[15:8] = new_word[15:8];",
                "        if (we_mask[2]) merge_word[23:16] = new_word[23:16];",
                "        if (we_mask[3]) merge_word[31:24] = new_word[31:24];",
                "    end",
                "endfunction",
            ]
        )
        update_shadow = "shadow_data <= merge_word(read_word(addr), di, we);"
        drive_doq = (
            "doq <= {write_active} ? merge_word(read_word(addr), di, we) : read_word(addr);".replace(
                "{write_active}",
                write_active,
            )
        )
    else:
        write_decl = "input we;"
        merge_decl = ""
        update_shadow = "shadow_data <= di;"
        drive_doq = "doq <= we ? di : read_word(addr);"

    return "\n".join(
        [
            f"module {name}(",
            "`ifdef OR1200_BIST",
            "    mbist_si_i, mbist_so_o, mbist_ctrl_i,",
            "`endif",
            "    clk, rst, ce, we, oe, addr, di, doq",
            ");",
            "`ifdef OR1200_BIST",
            "input mbist_si_i;",
            "input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;",
            "output mbist_so_o;",
            "assign mbist_so_o = mbist_si_i;",
            "`endif",
            "input clk;",
            "input rst;",
            "input ce;",
            write_decl,
            "input oe;",
            f"input [{addr_width - 1}:0] addr;",
            f"input [{width - 1}:0] di;",
            f"output reg [{width - 1}:0] doq;",
            f"reg [{addr_width - 1}:0] shadow_addr;",
            f"reg [{width - 1}:0] shadow_data;",
            "reg shadow_valid;",
            "function [{width_minus_one}:0] base_word;".replace(
                "{width_minus_one}",
                str(width - 1),
            ),
            f"    input [{addr_width - 1}:0] word_addr;",
            "    integer i;",
            "    begin",
            f"        for (i = 0; i < {width}; i = i + 1)",
            f"            base_word[i] = word_addr[i % {addr_width}] ^ i[0];",
            "    end",
            "endfunction",
            "function [{width_minus_one}:0] read_word;".replace(
                "{width_minus_one}",
                str(width - 1),
            ),
            f"    input [{addr_width - 1}:0] word_addr;",
            "    begin",
            "        if (shadow_valid && shadow_addr == word_addr)",
            "            read_word = shadow_data;",
            "        else",
            "            read_word = base_word(word_addr);",
            "    end",
            "endfunction",
            merge_decl,
            "always @(posedge clk or posedge rst)",
            "    if (rst) begin",
            f"        doq <= {{{width}{{1'b0}}}};",
            f"        shadow_addr <= {{{addr_width}{{1'b0}}}};",
            f"        shadow_data <= {{{width}{{1'b0}}}};",
            "        shadow_valid <= 1'b0;",
            "    end else if (ce) begin",
            f"        if ({write_active if byte_enable else 'we'}) begin",
            "            shadow_addr <= addr;",
            f"            {update_shadow}",
            "            shadow_valid <= 1'b1;",
            "        end",
            "        if (oe)",
            f"            {drive_doq}",
            "    end",
            "endmodule",
            "",
        ]
    )


def build_rfram_generic_module() -> str:
    return "\n".join(
        [
            "module or1200_rfram_generic(",
            "    clk, rst,",
            "    ce_a, addr_a, do_a,",
            "    ce_b, addr_b, do_b,",
            "    ce_w, we_w, addr_w, di_w",
            ");",
            "parameter dw = 32;",
            "input clk;",
            "input rst;",
            "input ce_a;",
            "input [4:0] addr_a;",
            "output [dw-1:0] do_a;",
            "input ce_b;",
            "input [4:0] addr_b;",
            "output [dw-1:0] do_b;",
            "input ce_w;",
            "input we_w;",
            "input [4:0] addr_w;",
            "input [dw-1:0] di_w;",
            "reg [dw-1:0] mem [0:31];",
            "integer i;",
            "assign do_a = ce_a ? mem[addr_a] : {dw{1'b0}};",
            "assign do_b = ce_b ? mem[addr_b] : {dw{1'b0}};",
            "always @(posedge clk or posedge rst)",
            "    if (rst) begin",
            "        for (i = 0; i < 32; i = i + 1)",
            "            mem[i] <= {dw{1'b0}};",
            "    end else if (ce_w && we_w) begin",
            "        mem[addr_w] <= di_w;",
            "    end",
            "endmodule",
            "",
        ]
    )


def build_abstract_rfram_generic_module() -> str:
    return "\n".join(
        [
            "module or1200_rfram_generic(",
            "    clk, rst,",
            "    ce_a, addr_a, do_a,",
            "    ce_b, addr_b, do_b,",
            "    ce_w, we_w, addr_w, di_w",
            ");",
            "parameter dw = 32;",
            "input clk;",
            "input rst;",
            "input ce_a;",
            "input [4:0] addr_a;",
            "output [dw-1:0] do_a;",
            "input ce_b;",
            "input [4:0] addr_b;",
            "output [dw-1:0] do_b;",
            "input ce_w;",
            "input we_w;",
            "input [4:0] addr_w;",
            "input [dw-1:0] di_w;",
            "reg [4:0] shadow_addr;",
            "reg [dw-1:0] shadow_data;",
            "reg shadow_valid;",
            "function [dw-1:0] base_word;",
            "    input [4:0] word_addr;",
            "    integer i;",
            "    begin",
            "        for (i = 0; i < dw; i = i + 1)",
            "            base_word[i] = word_addr[i % 5] ^ i[0];",
            "    end",
            "endfunction",
            "assign do_a = ce_a ? ((shadow_valid && shadow_addr == addr_a) ? shadow_data : base_word(addr_a)) : {dw{1'b0}};",
            "assign do_b = ce_b ? ((shadow_valid && shadow_addr == addr_b) ? shadow_data : base_word(addr_b)) : {dw{1'b0}};",
            "always @(posedge clk or posedge rst)",
            "    if (rst) begin",
            "        shadow_addr <= 5'b0;",
            "        shadow_data <= {dw{1'b0}};",
            "        shadow_valid <= 1'b0;",
            "    end else if (ce_w && we_w) begin",
            "        shadow_addr <= addr_w;",
            "        shadow_data <= di_w;",
            "        shadow_valid <= 1'b1;",
            "    end",
            "endmodule",
            "",
        ]
    )


def build_or1200_primitive_models() -> str:
    modules = [
        ("or1200_spram_128x32", 128, 32, 7, False),
        ("or1200_spram_1024x32", 1024, 32, 10, False),
        ("or1200_spram_2048x32", 2048, 32, 11, False),
        ("or1200_spram_32x24", 32, 24, 5, False),
        ("or1200_spram_256x21", 256, 21, 8, False),
        ("or1200_spram_512x20", 512, 20, 9, False),
        ("or1200_spram_64x14", 64, 14, 6, False),
        ("or1200_spram_64x22", 64, 22, 6, False),
        ("or1200_spram_64x24", 64, 24, 6, False),
        ("or1200_spram_1024x32_bw", 1024, 32, 10, True),
        ("or1200_spram_2048x32_bw", 2048, 32, 11, True),
    ]
    parts = [
        "// Temporary OR1200 primitive models used only for equivalence checking.",
        "",
    ]
    for name, depth, width, addr_width, byte_enable in modules:
        parts.append(
            build_single_port_ram_module(
                name=name,
                depth=depth,
                width=width,
                addr_width=addr_width,
                byte_enable=byte_enable,
            )
        )
    parts.append(build_rfram_generic_module())
    return "\n".join(parts)


def build_or1200_abstract_primitive_models() -> str:
    modules = [
        ("or1200_spram_128x32", 32, 7, False),
        ("or1200_spram_1024x32", 32, 10, False),
        ("or1200_spram_2048x32", 32, 11, False),
        ("or1200_spram_32x24", 24, 5, False),
        ("or1200_spram_256x21", 21, 8, False),
        ("or1200_spram_512x20", 20, 9, False),
        ("or1200_spram_64x14", 14, 6, False),
        ("or1200_spram_64x22", 22, 6, False),
        ("or1200_spram_64x24", 24, 6, False),
        ("or1200_spram_1024x32_bw", 32, 10, True),
        ("or1200_spram_2048x32_bw", 32, 11, True),
    ]
    parts = [
        "// Abstract OR1200 primitive models used only during equivalence proofs.",
        "",
    ]
    for name, width, addr_width, byte_enable in modules:
        parts.append(
            build_abstract_single_port_ram_module(
                name=name,
                width=width,
                addr_width=addr_width,
                byte_enable=byte_enable,
            )
        )
    parts.append(build_abstract_rfram_generic_module())
    return "\n".join(parts)


def write_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def write_check_csv_report(path: Path, results: list[CompareResult]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "backend",
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
        "reason_bucket",
        "reason",
        "interface_reason_kind",
        "interface_reason",
        "interface_aliases_applied",
        "counterexample_summary",
        "counterexample_json",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for result in results:
            row = asdict(result)
            row["interface_aliases_applied"] = json.dumps(
                result.interface_aliases_applied,
                ensure_ascii=False,
            )
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

    return f"step {failing_step} failed", {
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


def load_interface_aliases(path: Path) -> tuple[dict[str, str], dict[str, dict[str, str]]]:
    if not path.exists():
        return {}, {}

    payload = json.loads(path.read_text(encoding="utf-8"))
    global_aliases = payload.get("global", {})
    module_aliases = payload.get("modules", {})
    if not isinstance(global_aliases, dict) or not isinstance(module_aliases, dict):
        raise ValueError(f"Invalid interface alias file: {path}")

    normalized_global = {
        str(reference_port): str(candidate_port)
        for reference_port, candidate_port in global_aliases.items()
    }
    normalized_modules: dict[str, dict[str, str]] = {}
    for module_name, mapping in module_aliases.items():
        if not isinstance(mapping, dict):
            raise ValueError(f"Invalid alias map for module {module_name!r} in {path}")
        normalized_modules[str(module_name)] = {
            str(reference_port): str(candidate_port)
            for reference_port, candidate_port in mapping.items()
        }
    return normalized_global, normalized_modules


def aliases_for_module(
    global_aliases: dict[str, str],
    module_aliases: dict[str, dict[str, str]],
    module_dir: str,
) -> dict[str, str]:
    merged = dict(global_aliases)
    merged.update(module_aliases.get(module_dir, {}))
    return merged


def extract_normalized_interface(
    yosys: str,
    files: list[Path],
    include_dirs: list[Path],
    top: str,
    timeout: int,
    library_files: list[Path] | None = None,
) -> tuple[NormalizedModuleInterface | None, str]:
    with tempfile.TemporaryDirectory(prefix="yosys_interface_extract_") as tempdir_name:
        tempdir = Path(tempdir_name)
        script_path = tempdir / "extract.ys"
        json_path = tempdir / "design.json"
        script = build_interface_normalization_script(
            files=files,
            include_dirs=include_dirs,
            top=top,
            json_path=json_path,
            library_files=library_files,
        )
        script_path.write_text(script, encoding="ascii")
        try:
            result = subprocess.run(
                [yosys, "-s", str(script_path)],
                text=True,
                capture_output=True,
                timeout=timeout,
                check=False,
            )
        except subprocess.TimeoutExpired:
            return None, f"Timeout after {timeout}s"

        output = clean_output((result.stdout or "") + (result.stderr or ""))
        if result.returncode != 0:
            return None, summarize_error(output)
        if not json_path.exists():
            return None, "Yosys interface extraction did not produce JSON output"

        payload = json.loads(json_path.read_text(encoding="utf-8"))
        modules = payload.get("modules", {})
        module_payload = modules.get(top)
        if not isinstance(module_payload, dict):
            return None, f"Top module {top!r} missing from Yosys JSON output"

        ports_payload = module_payload.get("ports", {})
        if not isinstance(ports_payload, dict):
            return None, f"Top module {top!r} has no port payload in Yosys JSON output"

        ordered_ports = tuple(str(name) for name in ports_payload.keys())
        ports: dict[str, NormalizedPortInfo] = {}
        for name, port_payload in ports_payload.items():
            if not isinstance(port_payload, dict):
                return None, f"Invalid port payload for {name!r} in top module {top!r}"
            direction = str(port_payload.get("direction", ""))
            bits = port_payload.get("bits", [])
            if direction not in {"input", "output", "inout"}:
                return None, f"Invalid direction for port {name!r} in top module {top!r}"
            if not isinstance(bits, list) or not bits:
                return None, f"Invalid bit payload for port {name!r} in top module {top!r}"
            ports[str(name)] = NormalizedPortInfo(direction=direction, width_bits=len(bits))

    return NormalizedModuleInterface(module_name=top, ordered_ports=ordered_ports, ports=ports), "ok"


def format_width_bits(width_bits: int) -> str:
    return f"{width_bits} bit" if width_bits == 1 else f"{width_bits} bits"


def build_width_equivalent_details(
    reference: NormalizedModuleInterface,
    candidate: NormalizedModuleInterface,
    reference_raw: ModuleInterface,
    candidate_raw: ModuleInterface,
    canonical_to_candidate: dict[str, str],
) -> list[str]:
    details: list[str] = []
    for name in reference.ordered_ports:
        ref_raw = reference_raw.ports.get(name)
        cand_raw_name = canonical_to_candidate.get(name, name)
        cand_raw = candidate_raw.ports.get(cand_raw_name)
        ref_normalized = reference.ports.get(name)
        cand_normalized = candidate.ports.get(name)
        if (
            ref_raw is None
            or cand_raw is None
            or ref_raw.width is None
            or cand_raw.width is None
            or ref_normalized is None
            or cand_normalized is None
        ):
            continue
        if ref_raw.width == cand_raw.width:
            continue
        if ref_normalized.width_bits != cand_normalized.width_bits:
            continue
        details.append(
            f"{name} ({ref_raw.width} vs {cand_raw.width} -> {format_width_bits(ref_normalized.width_bits)})"
        )
    return details


def build_alias_wrapper_source(
    reference: NormalizedModuleInterface,
    wrapper_top: str,
    impl_top: str,
    canonical_to_candidate: dict[str, str],
) -> str:
    declarations: list[str] = []
    connections: list[str] = []
    for name in reference.ordered_ports:
        port = reference.ports[name]
        width = "" if port.width_bits == 1 else f"[{port.width_bits - 1}:0] "
        declarations.append(f"    {port.direction} {width}{name}")
        connections.append(f"        .{canonical_to_candidate[name]}({name})")

    return "\n".join(
        [
            f"module {wrapper_top}(",
            ",\n".join(declarations),
            ");",
            f"    {impl_top} u_gate (",
            ",\n".join(connections),
            "    );",
            "endmodule",
            "",
        ]
    )


def compare_normalized_interfaces(
    reference: NormalizedModuleInterface,
    candidate: NormalizedModuleInterface,
    reference_raw: ModuleInterface,
    candidate_raw: ModuleInterface,
    alias_map: dict[str, str],
) -> InterfaceComparison:
    aliases_applied: list[dict[str, str]] = []
    invalid_aliases: list[str] = []
    candidate_name_to_reference = defaultdict(list)
    for reference_port, candidate_port in alias_map.items():
        candidate_name_to_reference[candidate_port].append(reference_port)
        if reference_port not in reference.ports:
            invalid_aliases.append(
                f"{reference_port}->{candidate_port} (unknown reference port)"
            )

    alias_conflicts = [
        f"{candidate_port} -> {sorted(reference_ports)}"
        for candidate_port, reference_ports in sorted(candidate_name_to_reference.items())
        if len(reference_ports) > 1
    ]
    if alias_conflicts or invalid_aliases:
        return InterfaceComparison(
            compatible=False,
            interface_reason_kind="alias_conflict",
            interface_reason="alias conflict: " + "; ".join(alias_conflicts + invalid_aliases),
            aliases_applied=tuple(),
            gate_wrapper=None,
        )

    canonical_ports: dict[str, NormalizedPortInfo] = {}
    canonical_to_candidate: dict[str, str] = {}
    for candidate_name, candidate_info in candidate.ports.items():
        canonical_name = candidate_name
        for reference_name, aliased_candidate in alias_map.items():
            if aliased_candidate == candidate_name:
                canonical_name = reference_name
                aliases_applied.append(
                    {
                        "reference_port": reference_name,
                        "candidate_port": candidate_name,
                    }
                )
                break

        if canonical_name in canonical_ports:
            existing_candidate = canonical_to_candidate[canonical_name]
            return InterfaceComparison(
                compatible=False,
                interface_reason_kind="alias_conflict",
                interface_reason=(
                    f"alias conflict: canonical port {canonical_name} maps to both "
                    f"{existing_candidate} and {candidate_name}"
                ),
                aliases_applied=tuple(sorted(aliases_applied, key=lambda item: item["reference_port"])),
                gate_wrapper=None,
            )
        canonical_ports[canonical_name] = candidate_info
        canonical_to_candidate[canonical_name] = candidate_name

    ref_port_names = set(reference.ports)
    cand_port_names = set(canonical_ports)
    missing = sorted(ref_port_names - cand_port_names)
    extra = sorted(cand_port_names - ref_port_names)
    if missing or extra:
        details: list[str] = []
        if missing:
            details.append(f"missing ports: {', '.join(missing)}")
        if extra:
            details.append(f"extra ports: {', '.join(extra)}")
        return InterfaceComparison(
            compatible=False,
            interface_reason_kind="missing_extra",
            interface_reason="; ".join(details),
            aliases_applied=tuple(sorted(aliases_applied, key=lambda item: item["reference_port"])),
            gate_wrapper=None,
        )

    direction_mismatches: list[str] = []
    width_mismatches: list[str] = []
    for name in reference.ordered_ports:
        reference_port = reference.ports[name]
        candidate_port = canonical_ports[name]
        if reference_port.direction != candidate_port.direction:
            direction_mismatches.append(
                f"{name} direction mismatch ({reference_port.direction} vs {candidate_port.direction})"
            )
        if reference_port.width_bits != candidate_port.width_bits:
            width_mismatches.append(
                f"{name} width mismatch ({format_width_bits(reference_port.width_bits)} vs "
                f"{format_width_bits(candidate_port.width_bits)})"
            )

    if direction_mismatches:
        return InterfaceComparison(
            compatible=False,
            interface_reason_kind="direction_mismatch",
            interface_reason="; ".join(direction_mismatches),
            aliases_applied=tuple(sorted(aliases_applied, key=lambda item: item["reference_port"])),
            gate_wrapper=None,
        )

    if width_mismatches:
        return InterfaceComparison(
            compatible=False,
            interface_reason_kind="width_mismatch",
            interface_reason="; ".join(width_mismatches),
            aliases_applied=tuple(sorted(aliases_applied, key=lambda item: item["reference_port"])),
            gate_wrapper=None,
        )

    width_equivalent_details = build_width_equivalent_details(
        reference=reference,
        candidate=NormalizedModuleInterface(
            module_name=candidate.module_name,
            ordered_ports=tuple(canonical_to_candidate[name] for name in reference.ordered_ports),
            ports=canonical_ports,
        ),
        reference_raw=reference_raw,
        candidate_raw=candidate_raw,
        canonical_to_candidate=canonical_to_candidate,
    )
    raw_order_diff = (
        not aliases_applied
        and reference_raw.ordered_ports != candidate_raw.ordered_ports
        and set(reference_raw.ordered_ports) == set(candidate_raw.ordered_ports)
    )

    reason_notes: list[str] = []
    reason_kind = "exact_match"
    if aliases_applied:
        reason_kind = "alias_applied"
        alias_text = ", ".join(
            f"{item['reference_port']}->{item['candidate_port']}" for item in aliases_applied
        )
        reason_notes.append(f"applied aliases: {alias_text}")
    if width_equivalent_details:
        if not aliases_applied:
            reason_kind = "width_equivalent"
        reason_notes.append("normalized width expressions: " + "; ".join(width_equivalent_details))
    if raw_order_diff:
        if not aliases_applied and not width_equivalent_details:
            reason_kind = "port_order_only"
        reason_notes.append("ignored port declaration order differences")
    if not reason_notes:
        reason_notes.append("normalized interface matches exactly")

    gate_wrapper = None
    if aliases_applied:
        gate_wrapper = GateWrapperSpec(
            raw_candidate_top=candidate.module_name,
            wrapper_top=f"{candidate.module_name}__alias_wrap",
            impl_top=f"{candidate.module_name}__impl",
            canonical_to_candidate=dict(canonical_to_candidate),
        )

    return InterfaceComparison(
        compatible=True,
        interface_reason_kind=reason_kind,
        interface_reason="; ".join(reason_notes),
        aliases_applied=tuple(sorted(aliases_applied, key=lambda item: item["reference_port"])),
        gate_wrapper=gate_wrapper,
    )


def parse_attempt(candidate_file: str) -> int | None:
    match = ATTEMPT_RE.search(candidate_file)
    if match is None:
        return None
    return int(match.group("attempt"))


def candidate_name_sort_key(candidate_name: str) -> tuple[bool, int, str]:
    attempt = parse_attempt(candidate_name)
    return (attempt is None, attempt or 0, candidate_name)


def sort_candidate_names(candidate_names: list[str]) -> list[str]:
    return sorted(candidate_names, key=candidate_name_sort_key)


def expected_candidate_names(module_dir: str, count: int) -> list[str]:
    return [f"{module_dir}_t{attempt}.v" for attempt in range(1, count + 1)]


def resolve_expected_candidate_names(
    module_dir: str,
    candidate_groups: list[tuple[str, Path]],
    expected_attempts: int | None,
) -> tuple[str, list[str]]:
    if expected_attempts is None:
        return "auto", sort_candidate_names(
            sorted({candidate_file.name for _, candidate_file in candidate_groups})
        )
    return "fixed_attempts", expected_candidate_names(module_dir, expected_attempts)


def summarize_jasper_error(output: str) -> str:
    lines = output.splitlines()
    generic_prefixes = (
        "ERROR: problem encountered at line",
        "ERROR (ESEC042):",
    )
    for line in reversed(lines):
        stripped = line.strip()
        if any(stripped.startswith(prefix) for prefix in generic_prefixes):
            continue
        if JASPER_ERROR_RE.search(stripped):
            return stripped
    for line in reversed(lines):
        stripped = line.strip()
        if JASPER_ERROR_RE.search(stripped):
            return stripped
    return summarize_error(output)


def classify_reason_bucket(
    formal_status: str,
    interface_status: str,
    reason: str,
) -> str:
    lower = reason.lower()
    if formal_status == "equivalent":
        return "equivalent"
    if formal_status == "not_equivalent":
        return "not_equivalent"
    if interface_status == "incompatible":
        return "interface_mismatch"
    if "timeout after" in lower:
        return "tool_timeout"
    if "precheck failed" in lower:
        return "precheck_fail"
    if formal_status == "tool_limited":
        return "license_or_tool_error"
    if formal_status == "skip":
        return "precheck_fail"
    return "license_or_tool_error"


def detect_clock_port(interface: NormalizedModuleInterface) -> str | None:
    preferred = ("clk", "clock", "wb_clk_i", "clk_i")
    for name in preferred:
        if name in interface.ports:
            return name
    for name in interface.ordered_ports:
        lower = name.lower()
        if lower in {"clk", "clock"} or lower.endswith(("_clk", "clk_i", "_clk_i")):
            return name
    return None


def detect_reset_expr(interface: NormalizedModuleInterface) -> str | None:
    preferred = (
        "rst",
        "reset",
        "wb_rst_i",
        "rst_i",
        "reset_i",
        "rstn",
        "resetn",
        "rst_n",
        "reset_n",
    )
    port_name: str | None = None
    for name in preferred:
        if name in interface.ports:
            port_name = name
            break
    if port_name is None:
        for name in interface.ordered_ports:
            lower = name.lower()
            if "reset" in lower or lower.startswith("rst") or lower.endswith("_rst_i"):
                port_name = name
                break
    if port_name is None:
        return None
    lower = port_name.lower()
    if lower.endswith("n") or lower.endswith("_n"):
        return f"~{port_name}"
    return port_name


def collect_included_filenames(files: list[Path]) -> set[str]:
    names: set[str] = set()
    for file in files:
        text = strip_comments(file.read_text(encoding="utf-8", errors="ignore"))
        names.update(INCLUDE_RE.findall(text))
    return names


def dedupe_paths(paths: list[Path]) -> list[Path]:
    ordered: list[Path] = []
    seen: set[Path] = set()
    for path in paths:
        resolved = path.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        ordered.append(resolved)
    return ordered


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


def build_include_dirs(
    files: list[Path],
    search_roots: list[Path],
    extra_include_dirs: list[Path],
    support_context: SupportDesignContext | None = None,
) -> list[Path]:
    preferred_dirs: list[Path] = []
    if support_context is not None:
        preferred_dirs.append(support_context.effective_support_root)
        preferred_dirs.extend(path.parent.resolve() for path in support_context.prefix_files)

    file_dirs = [path.parent.resolve() for path in files]
    inferred_dirs = infer_include_dirs(files, search_roots)
    return dedupe_paths([*preferred_dirs, *file_dirs, *inferred_dirs, *extra_include_dirs])


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


def prepare_or1200_support_workspace(support_root: Path, reference_file: Path) -> SupportDesignContext:
    tempdir = Path(tempfile.mkdtemp(prefix="or1200_equiv_ref_"))
    temp_ref_root = tempdir / "verilog"
    temp_ref_root.mkdir(parents=True, exist_ok=False)

    prefix_files: list[Path] = []
    defines = support_root / "or1200_defines.v"
    if defines.exists():
        copied_defines = temp_ref_root / defines.name
        shutil.copy2(defines, copied_defines)
        prefix_files.append(copied_defines)

    copied_support_files: list[Path] = []
    for src in sorted(support_root.glob("*/*.v")):
        dest = temp_ref_root / src.name
        shutil.copy2(src, dest)
        copied_support_files.append(dest)

    repair_or1200_reference_root(temp_ref_root)
    primitives = temp_ref_root / "or1200_temp_primitives.v"
    primitives.write_text(build_or1200_primitive_models(), encoding="ascii")
    copied_support_files.append(primitives)
    proof_primitives = temp_ref_root / "or1200_temp_primitives_abstract.v"
    proof_primitives.write_text(build_or1200_abstract_primitive_models(), encoding="ascii")

    prepared_reference = temp_ref_root / reference_file.name
    support_files = [path for path in copied_support_files if path != prepared_reference]
    proof_support_files = [
        proof_primitives if path == primitives else path
        for path in support_files
    ]
    return SupportDesignContext(
        cleanup_root=tempdir,
        effective_support_root=temp_ref_root,
        prefix_files=tuple(prefix_files),
        support_files=tuple(support_files),
        proof_support_files=tuple(proof_support_files),
        reference_file=prepared_reference,
    )


def prepare_mips_support_workspace(support_root: Path, reference_file: Path) -> SupportDesignContext:
    tempdir = Path(tempfile.mkdtemp(prefix="mips_equiv_ref_"))
    temp_root = tempdir / "mips_support"
    temp_root.mkdir(parents=True, exist_ok=False)

    prefix_files: list[Path] = []
    defines = support_root / "mips_16_defs.v"
    if defines.exists():
        defines_text = defines.read_text(encoding="utf-8", errors="ignore")
        for index, shim_name in enumerate(MIPS_PREFIX_SHIM_NAMES):
            shim_path = temp_root / shim_name
            shim_path.write_text(defines_text, encoding="utf-8")
            if index == 0:
                prefix_files.append(shim_path.resolve())

    return SupportDesignContext(
        cleanup_root=tempdir,
        effective_support_root=temp_root.resolve(),
        prefix_files=tuple(prefix_files),
        support_files=tuple(discover_support_files(support_root.resolve(), reference_file)),
        proof_support_files=tuple(discover_support_files(support_root.resolve(), reference_file)),
        reference_file=reference_file.resolve(),
    )


def prepare_i2c_support_workspace(support_root: Path, reference_file: Path) -> SupportDesignContext:
    tempdir = Path(tempfile.mkdtemp(prefix="i2c_equiv_ref_"))
    temp_root = tempdir / "i2c_support"
    temp_root.mkdir(parents=True, exist_ok=False)

    prefix_files: list[Path] = []
    for filename in I2C_PREFIX_FILE_NAMES:
        source = support_root / filename
        if not source.exists():
            continue
        destination = temp_root / filename
        shutil.copy2(source, destination)
        prefix_files.append(destination.resolve())

    return SupportDesignContext(
        cleanup_root=tempdir,
        effective_support_root=temp_root.resolve(),
        prefix_files=tuple(prefix_files),
        support_files=tuple(discover_support_files(support_root.resolve(), reference_file)),
        proof_support_files=tuple(discover_support_files(support_root.resolve(), reference_file)),
        reference_file=reference_file.resolve(),
    )


def prepare_support_context(
    module_dir: str,
    support_root: Path,
    reference_file: Path,
) -> SupportDesignContext:
    if module_dir.startswith("or1200_"):
        return prepare_or1200_support_workspace(support_root, reference_file)
    if module_dir.startswith("i2c_"):
        return prepare_i2c_support_workspace(support_root, reference_file)
    if module_dir.startswith("mips_"):
        return prepare_mips_support_workspace(support_root, reference_file)
    return SupportDesignContext(
        cleanup_root=None,
        effective_support_root=support_root.resolve(),
        prefix_files=tuple(),
        support_files=tuple(discover_support_files(support_root.resolve(), reference_file)),
        proof_support_files=tuple(discover_support_files(support_root.resolve(), reference_file)),
        reference_file=reference_file.resolve(),
    )


def resolve_compile_reference(module_dir: str) -> tuple[str, Path, Path]:
    if module_dir.startswith("or1200_"):
        family_root = REPO_ROOT / "Src" / "or1200_hp" / "des" / "verilog"
        return (
            "or1200_hp",
            family_root / module_dir / f"{module_dir}.v",
            family_root,
        )

    if module_dir.startswith("i2c_"):
        family_root = REPO_ROOT / "Src" / "i2c" / "des" / "verilog"
        return (
            "i2c",
            family_root / module_dir / f"{module_dir}.v",
            family_root,
        )

    if module_dir in {"cordic", "rotator", "signed_shifter"}:
        family_root = REPO_ROOT / "Src" / "verilog_cordic_core" / "des"
        return (
            "verilog_cordic_core",
            family_root / module_dir / f"{module_dir}.v",
            family_root,
        )

    if module_dir.startswith("mips_"):
        family_root = REPO_ROOT / "Src" / "mips_16" / "des"
        suffix = module_dir[len("mips_") :]
        return (
            "mips_16",
            family_root / suffix / f"{suffix}.v",
            family_root,
        )

    if module_dir in {"fpu_addsub_pipeline", "fpu_mul_pipeline"}:
        family_root = REPO_ROOT / "Src" / "double_fpu" / "des"
        return (
            "double_fpu",
            family_root / "pipeline" / module_dir / f"{module_dir}.v",
            family_root,
        )

    if module_dir.startswith("fpu_"):
        family_root = REPO_ROOT / "Src" / "double_fpu" / "des"
        return (
            "double_fpu",
            family_root / "verilog" / module_dir / f"{module_dir}.v",
            family_root,
        )

    raise FileNotFoundError(f"Unsupported module directory: {module_dir}")


def discover_compile_support_files(family_root: Path, reference_file: Path) -> list[Path]:
    return sorted(
        path.resolve()
        for path in family_root.rglob("*.v")
        if path.resolve() != reference_file.resolve() and extract_tolerant_module_names(path)
    )


def resolve_expected_top(module_dir: str, design_file: Path) -> tuple[str | None, str | None]:
    module_names = extract_unique_tolerant_module_names(design_file)
    if not module_names:
        return None, f"No module declarations found in {design_file}"

    if module_dir in module_names:
        return module_dir, None

    if module_dir.startswith("mips_"):
        suffix = module_dir[len("mips_") :]
        if suffix in module_names:
            return suffix, None

    if len(module_names) == 1:
        return module_names[0], None

    return None, "ambiguous_top: " + ", ".join(module_names)


def require_resolved_top(module_dir: str, design_file: Path, *, role: str) -> str:
    expected_top, top_error = resolve_expected_top(module_dir, design_file)
    if expected_top is None:
        detail = top_error or "unknown error"
        raise ValueError(f"{role} top resolution failed for {design_file}: {detail}")
    return expected_top


def resolve_compile_expected_top(module_dir: str, reference_file: Path) -> tuple[str | None, str | None]:
    return resolve_expected_top(module_dir, reference_file)


def build_compile_module_context(module_dir: str) -> CompileModuleContext:
    family, reference_file, family_root = resolve_compile_reference(module_dir)
    if not reference_file.exists():
        raise FileNotFoundError(f"Reference file not found for {module_dir}: {reference_file}")

    expected_top, top_error = resolve_compile_expected_top(module_dir, reference_file)
    support_context: SupportDesignContext | None = None
    prefix_files: tuple[Path, ...] = tuple()
    support_files: tuple[Path, ...]
    search_roots: tuple[Path, ...]

    if family == "or1200_hp":
        support_context = prepare_support_context(module_dir, family_root.resolve(), reference_file.resolve())
        prefix_files = support_context.prefix_files
        support_files = support_context.support_files
        search_roots = tuple(dedupe_paths([REPO_ROOT, support_context.effective_support_root]))
    else:
        support_files = tuple(discover_compile_support_files(family_root.resolve(), reference_file.resolve()))
        search_roots = (family_root.resolve(),)

    return CompileModuleContext(
        family=family,
        module_dir=module_dir,
        family_root=family_root.resolve(),
        reference_file=reference_file.resolve(),
        expected_top=expected_top,
        top_error=top_error,
        support_context=support_context,
        prefix_files=prefix_files,
        support_files=support_files,
        search_roots=search_roots,
    )


def filter_compile_support_files(
    candidate_file: Path,
    support_files: tuple[Path, ...],
) -> list[Path]:
    candidate_modules = set(extract_unique_tolerant_module_names(candidate_file))
    filtered: list[Path] = []
    for support_file in support_files:
        support_modules = set(extract_unique_tolerant_module_names(support_file))
        if candidate_modules and candidate_modules.intersection(support_modules):
            continue
        filtered.append(support_file)
    return filtered


def compile_macro_defines_for_scope(
    context: CompileModuleContext,
    candidate_file: Path,
    scope: str,
) -> tuple[tuple[str, str], ...]:
    if scope != "with_support" or context.family != "verilog_cordic_core":
        return tuple()
    defined = extract_defined_macros(candidate_file.read_text(encoding="utf-8", errors="ignore"))
    return tuple(
        (macro_name, macro_value)
        for macro_name, macro_value in CORDIC_TESTBENCH_DEFAULT_DEFINES
        if macro_name not in defined
    )


def build_compile_error_excerpt(output: str, *, ok: bool) -> str:
    if ok:
        return ""
    lines = output.splitlines()
    if not lines:
        return "No output"
    error_lines = [line.strip() for line in lines if COMPILE_ERROR_LINE_RE.search(line)]
    excerpt_lines = error_lines[:8] if error_lines else [line.strip() for line in lines[:8]]
    return " | ".join(excerpt_lines)


def run_iverilog_compile(
    *,
    source_files: list[Path],
    include_dirs: list[Path],
    macro_defines: tuple[tuple[str, str], ...] = tuple(),
    top: str,
    iverilog: str,
    cwd: Path,
    timeout: int,
) -> tuple[bool, str, int]:
    with tempfile.TemporaryDirectory(prefix="iverilog_compile_suite_") as tempdir:
        output_file = Path(tempdir) / f"{top}.out"
        cmd = [iverilog, "-g2012"]
        for macro_name, macro_value in macro_defines:
            if macro_value:
                cmd.append(f"-D{macro_name}={macro_value}")
            else:
                cmd.append(f"-D{macro_name}")
        for include_dir in include_dirs:
            cmd.extend(["-I", str(include_dir)])
        cmd.extend(["-s", top, "-o", str(output_file)])
        cmd.extend(str(path) for path in source_files)
        return run_command_details(cmd, cwd=cwd, timeout=timeout)


def discover_compile_models(result_root: Path, model_filter: str | None) -> list[str]:
    models = sorted(path.name for path in result_root.iterdir() if path.is_dir())
    if model_filter is None:
        return models
    if model_filter not in models:
        raise FileNotFoundError(f"Model not found under {result_root}: {model_filter}")
    return [model_filter]


def discover_compile_module_dirs(result_root: Path, models: list[str]) -> list[str]:
    modules: set[str] = set()
    for model in models:
        modules.update(path.name for path in (result_root / model).iterdir() if path.is_dir())
    return sorted(modules)


def cleanup_compile_contexts(contexts: dict[str, CompileModuleContext]) -> None:
    for context in contexts.values():
        if context.support_context is None:
            continue
        if context.support_context.cleanup_root is not None:
            shutil.rmtree(context.support_context.cleanup_root, ignore_errors=True)


def discover_candidate_groups(
    candidate_path: Path,
    module_dir: str,
    model_filter: str | None,
) -> list[tuple[str, Path]]:
    if not candidate_path.exists():
        raise FileNotFoundError(f"Candidate path not found: {candidate_path}")

    if candidate_path.is_dir():
        direct_files = sorted(candidate_path.glob("*.v"))
        if direct_files:
            model = candidate_path.parent.name if candidate_path.name == module_dir else candidate_path.name
            if model_filter is not None and model != model_filter:
                return []
            return [(model, file.resolve()) for file in direct_files]

        model_module_dir = candidate_path / module_dir
        if model_module_dir.is_dir():
            direct_model_files = sorted(model_module_dir.glob("*.v"))
            if direct_model_files:
                model = candidate_path.name
                if model_filter is not None and model != model_filter:
                    return []
                return [(model, file.resolve()) for file in direct_model_files]

        grouped_files = sorted(candidate_path.glob(f"*/{module_dir}/*.v"))
        if grouped_files:
            pairs = [(file.parent.parent.name, file.resolve()) for file in grouped_files]
            if model_filter is not None:
                pairs = [pair for pair in pairs if pair[0] == model_filter]
            return pairs

    raise FileNotFoundError(
        f"No candidate Verilog files found under {candidate_path} for module {module_dir}"
    )


def write_jasper_filelist(path: Path, files: list[Path], include_dirs: list[Path]) -> None:
    lines = [f"+incdir+{include_dir.as_posix()}" for include_dir in include_dirs]
    lines.extend(file.as_posix() for file in files)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def run_jasper_script(
    jg: str,
    script: str,
    timeout: int,
    sec_app: bool,
) -> tuple[bool, str, int]:
    with tempfile.TemporaryDirectory(prefix="jasper_batch_equiv_") as tempdir_name:
        tempdir = Path(tempdir_name)
        script_path = tempdir / "run.tcl"
        proj_dir = tempdir / "proj"
        script_path.write_text(script, encoding="utf-8")
        cmd = [jg]
        if sec_app:
            cmd.append("-sec")
        cmd.extend(["-batch", "-proj", str(proj_dir), str(script_path)])
        try:
            result = subprocess.run(
                cmd,
                text=True,
                capture_output=True,
                timeout=timeout,
                check=False,
            )
        except subprocess.TimeoutExpired:
            return False, f"Timeout after {timeout}s", -1

    output = clean_output((result.stdout or "") + (result.stderr or ""))
    return result.returncode == 0, output, result.returncode


def build_jasper_precheck_script(filelist: Path, top: str) -> str:
    return "\n".join(
        [
            "clear -all",
            f"analyze -sv -f {filelist.as_posix()}",
            f"elaborate -top {top}",
            "exit",
        ]
    )


def build_jasper_sec_script(
    spec_filelist: Path,
    imp_filelist: Path,
    reference_top: str,
    candidate_top: str,
    proof_type: str,
    clock_port: str | None,
    reset_expr: str | None,
) -> str:
    lines = [
        "clear -all",
        "check_sec -compile_context spec",
        f"analyze -sv -f {spec_filelist.as_posix()}",
        f"elaborate -top {reference_top}",
        "check_sec -compile_context imp",
        f"analyze -sv -f {imp_filelist.as_posix()}",
        f"elaborate -top {candidate_top}",
        "check_sec -setup",
    ]
    if proof_type == "strict_comb":
        lines.extend(["clock -none", "reset -none"])
    else:
        lines.append(f"clock {clock_port}" if clock_port is not None else "clock -infer")
        lines.append(f"reset {reset_expr}" if reset_expr is not None else "reset -none")
    lines.extend(["check_sec -prove", "exit"])
    return "\n".join(lines)


def precheck_design_yosys(
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


def precheck_design_jasper(
    jg: str,
    files: list[Path],
    include_dirs: list[Path],
    top: str,
    timeout: int,
) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="jasper_precheck_") as tempdir_name:
        tempdir = Path(tempdir_name)
        filelist = tempdir / "design.f"
        write_jasper_filelist(filelist, files, include_dirs)
        script = build_jasper_precheck_script(filelist=filelist, top=top)
        ok, output, rc = run_jasper_script(jg=jg, script=script, timeout=timeout, sec_app=False)
    if ok and rc == 0 and not JASPER_ERROR_RE.search(output):
        return True, "pass"
    return False, summarize_jasper_error(output)


def precheck_design(
    backend: str,
    tool_path: str,
    files: list[Path],
    include_dirs: list[Path],
    top: str,
    timeout: int,
) -> tuple[bool, str]:
    if backend == "jasper":
        return precheck_design_jasper(
            jg=tool_path,
            files=files,
            include_dirs=include_dirs,
            top=top,
            timeout=timeout,
        )
    return precheck_design_yosys(
        yosys=tool_path,
        files=files,
        include_dirs=include_dirs,
        top=top,
        timeout=timeout,
    )


def run_equivalence_yosys(
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
    gate_wrapper_source: str | None,
    gate_impl_rename_from: str | None,
    gate_impl_rename_to: str | None,
) -> tuple[str, str, str, dict[str, object] | None]:
    sat_options = ["-show-inputs", "-show-public", "-show", "trigger"]

    with tempfile.TemporaryDirectory(prefix="yosys_result_equiv_") as tempdir_name:
        tempdir = Path(tempdir_name)
        dump_path = tempdir / "counterexample.json"
        gate_files_to_use = list(gate_files)
        if gate_wrapper_source is not None:
            wrapper_path = tempdir / f"{candidate_top}.v"
            wrapper_path.write_text(gate_wrapper_source, encoding="ascii")
            gate_files_to_use.append(wrapper_path)

        proof_script = build_proof_script(
            gold_files=gold_files,
            gold_includes=reference_includes,
            gate_files=gate_files_to_use,
            gate_includes=candidate_includes,
            reference_top=reference_top,
            candidate_top=candidate_top,
            proof_type=proof_type,
            seq_depth=depth,
            has_rst=has_rst,
            gate_impl_rename_from=gate_impl_rename_from,
            gate_impl_rename_to=gate_impl_rename_to,
        )
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


def run_equivalence_jasper(
    jg: str,
    gold_files: list[Path],
    gate_files: list[Path],
    reference_top: str,
    candidate_top: str,
    reference_includes: list[Path],
    candidate_includes: list[Path],
    proof_type: str,
    clock_port: str | None,
    reset_expr: str | None,
    timeout: int,
    gate_wrapper_source: str | None,
) -> tuple[str, str, str, dict[str, object] | None]:
    with tempfile.TemporaryDirectory(prefix="jasper_result_equiv_") as tempdir_name:
        tempdir = Path(tempdir_name)
        spec_filelist = tempdir / "spec.f"
        imp_filelist = tempdir / "imp.f"
        gate_files_to_use = list(gate_files)
        if gate_wrapper_source is not None:
            wrapper_path = tempdir / f"{candidate_top}.v"
            wrapper_path.write_text(gate_wrapper_source, encoding="ascii")
            gate_files_to_use.append(wrapper_path)
        write_jasper_filelist(spec_filelist, gold_files, reference_includes)
        write_jasper_filelist(imp_filelist, gate_files_to_use, candidate_includes)
        script = build_jasper_sec_script(
            spec_filelist=spec_filelist,
            imp_filelist=imp_filelist,
            reference_top=reference_top,
            candidate_top=candidate_top,
            proof_type=proof_type,
            clock_port=clock_port,
            reset_expr=reset_expr,
        )
        ok, output, rc = run_jasper_script(jg=jg, script=script, timeout=timeout, sec_app=True)

    if rc == -1:
        return "tool_limited", f"Timeout after {timeout}s", "", None

    if "SEC Proof Result: proven." in output:
        return "equivalent", "Jasper SEC proof passed", "", None

    if "SEC Proof Result: cex." in output:
        cex_line = next(
            (
                line.strip()
                for line in output.splitlines()
                if "counterexample (cex)" in line.lower() or "SEC Proof Result: cex." in line
            ),
            "Jasper SEC found a counterexample",
        )
        return "not_equivalent", "Jasper SEC found a counterexample", cex_line, None

    if ok and rc == 0:
        return (
            "tool_limited",
            "Jasper SEC finished without a definitive proven/cex result",
            "",
            None,
        )
    return "tool_limited", summarize_jasper_error(output), "", None


def run_equivalence(
    backend: str,
    tool_path: str,
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
    clock_port: str | None,
    reset_expr: str | None,
    gate_wrapper_source: str | None,
    gate_impl_rename_from: str | None,
    gate_impl_rename_to: str | None,
) -> tuple[str, str, str, dict[str, object] | None]:
    if backend == "jasper":
        return run_equivalence_jasper(
            jg=tool_path,
            gold_files=gold_files,
            gate_files=gate_files,
            reference_top=reference_top,
            candidate_top=candidate_top,
            reference_includes=reference_includes,
            candidate_includes=candidate_includes,
            proof_type=proof_type,
            clock_port=clock_port,
            reset_expr=reset_expr,
            timeout=timeout,
            gate_wrapper_source=gate_wrapper_source,
        )
    return run_equivalence_yosys(
        yosys=tool_path,
        gold_files=gold_files,
        gate_files=gate_files,
        reference_top=reference_top,
        candidate_top=candidate_top,
        reference_includes=reference_includes,
        candidate_includes=candidate_includes,
        input_ports=input_ports,
        output_ports=output_ports,
        proof_type=proof_type,
        has_rst=has_rst,
        depth=depth,
        timeout=timeout,
        gate_wrapper_source=gate_wrapper_source,
        gate_impl_rename_from=gate_impl_rename_from,
        gate_impl_rename_to=gate_impl_rename_to,
    )


def format_check_result_line(result: CompareResult) -> str:
    suffix = f" counterexample={result.counterexample_summary}" if result.counterexample_summary else ""
    interface_suffix = ""
    if result.interface_reason_kind:
        interface_suffix = (
            f" interface_reason_kind={result.interface_reason_kind}"
            f" interface_reason={result.interface_reason}"
        )
    return (
        f"{result.backend}:{result.model}/{Path(result.candidate_file).name}: "
        f"gold={result.reference_precheck} "
        f"gate={result.candidate_precheck} "
        f"interface={result.interface_status} "
        f"formal={result.formal_status} "
        f"bucket={result.reason_bucket} "
        f"reason={result.reason}{interface_suffix}{suffix}"
    )


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


def resolve_backend_tools(backend: str, yosys: str, jg: str) -> tuple[str, str]:
    yosys_path = shutil.which(yosys)
    if yosys_path is None:
        raise FileNotFoundError(f"Tool not found: {yosys}")

    tool_name = jg if backend == "jasper" else yosys
    tool_path = shutil.which(tool_name)
    if tool_path is None:
        raise FileNotFoundError(f"Tool not found: {tool_name}")
    return yosys_path, tool_path


def execute_cordic_testbench_check(
    *,
    backend: str,
    candidates: Path,
    module_dir: str,
    model: str | None,
    timeout: int,
    expected_attempts: int | None,
    report: Path,
    csv_report: Path,
    live_log: Callable[[str], None] | None = None,
    live_log_block: Callable[[str], None] | None = None,
) -> tuple[int, dict[str, object], list[str]]:
    logs: list[str] = []

    def emit(message: str) -> None:
        logs.append(message)
        if live_log is not None:
            live_log(message)

    emit(f"start: backend={backend} module={module_dir} model={model or 'all'}")
    candidate_groups = discover_candidate_groups(candidates.resolve(), module_dir, model)
    candidate_expectation_mode, expected_names = resolve_expected_candidate_names(
        module_dir,
        candidate_groups,
        expected_attempts,
    )
    results: list[CompareResult] = []
    try:
        for current_model, candidate_file in candidate_groups:
            try:
                outcome = run_cordic_testbench(candidate_file, timeout)
            except FileNotFoundError as exc:
                result = CompareResult(
                    backend=backend,
                    model=current_model,
                    module_dir=module_dir,
                    candidate_file=str(candidate_file),
                    reference_file=str(CORDIC_TESTBENCH_PATH.resolve()),
                    reference_top="tb",
                    candidate_top="cordic",
                    reference_precheck="fail",
                    candidate_precheck="fail",
                    interface_status="skip",
                    formal_status="skip",
                    proof_type="simulation_tb",
                    reason_bucket=classify_reason_bucket(
                        formal_status="skip",
                        interface_status="skip",
                        reason=f"Reference precheck failed: {exc}",
                    ),
                    reason=f"Reference precheck failed: {exc}",
                    interface_reason_kind="",
                    interface_reason="",
                    interface_aliases_applied=[],
                    counterexample_summary="",
                    counterexample=None,
                )
                results.append(result)
                emit(format_check_result_line(result))
                continue

            if not outcome.compile_ok:
                result = CompareResult(
                    backend=backend,
                    model=current_model,
                    module_dir=module_dir,
                    candidate_file=str(candidate_file),
                    reference_file=str(CORDIC_TESTBENCH_PATH.resolve()),
                    reference_top="tb",
                    candidate_top="cordic",
                    reference_precheck="pass",
                    candidate_precheck="fail",
                    interface_status="skip",
                    formal_status="skip",
                    proof_type="simulation_tb",
                    reason_bucket=classify_reason_bucket(
                        formal_status="skip",
                        interface_status="skip",
                        reason="Candidate precheck failed: tb_cordic compile failed",
                    ),
                    reason=(
                        "Candidate precheck failed: tb_cordic compile failed: "
                        f"{build_compile_error_excerpt(outcome.compile_output, ok=False)}"
                    ),
                    interface_reason_kind="",
                    interface_reason="",
                    interface_aliases_applied=[],
                    counterexample_summary="",
                    counterexample=None,
                )
                results.append(result)
                emit(format_check_result_line(result))
                continue

            if not outcome.run_ok:
                result = CompareResult(
                    backend=backend,
                    model=current_model,
                    module_dir=module_dir,
                    candidate_file=str(candidate_file),
                    reference_file=str(CORDIC_TESTBENCH_PATH.resolve()),
                    reference_top="tb",
                    candidate_top="cordic",
                    reference_precheck="pass",
                    candidate_precheck="pass",
                    interface_status="compatible",
                    formal_status="tool_limited",
                    proof_type="simulation_tb",
                    reason_bucket=classify_reason_bucket(
                        formal_status="tool_limited",
                        interface_status="compatible",
                        reason=f"tb_cordic run failed: {outcome.run_output}",
                    ),
                    reason=f"tb_cordic run failed: {build_compile_error_excerpt(outcome.run_output, ok=False)}",
                    interface_reason_kind="testbench_matched",
                    interface_reason="tb_cordic compiled against candidate cordic",
                    interface_aliases_applied=[],
                    counterexample_summary="",
                    counterexample=None,
                )
                results.append(result)
                emit(format_check_result_line(result))
                continue

            failure_lines = extract_cordic_testbench_failure_lines(outcome.run_output)
            if failure_lines:
                result = CompareResult(
                    backend=backend,
                    model=current_model,
                    module_dir=module_dir,
                    candidate_file=str(candidate_file),
                    reference_file=str(CORDIC_TESTBENCH_PATH.resolve()),
                    reference_top="tb",
                    candidate_top="cordic",
                    reference_precheck="pass",
                    candidate_precheck="pass",
                    interface_status="compatible",
                    formal_status="not_equivalent",
                    proof_type="simulation_tb",
                    reason_bucket=classify_reason_bucket(
                        formal_status="not_equivalent",
                        interface_status="compatible",
                        reason="tb_cordic reported mismatches",
                    ),
                    reason=(
                        "tb_cordic reported mismatches: "
                        f"{summarize_lines(failure_lines)}"
                    ),
                    interface_reason_kind="testbench_matched",
                    interface_reason="tb_cordic compiled against candidate cordic",
                    interface_aliases_applied=[],
                    counterexample_summary=summarize_lines(failure_lines, limit=1),
                    counterexample={"tb_failure_lines": failure_lines[:10]},
                )
                results.append(result)
                emit(format_check_result_line(result))
                continue

            result = CompareResult(
                backend=backend,
                model=current_model,
                module_dir=module_dir,
                candidate_file=str(candidate_file),
                reference_file=str(CORDIC_TESTBENCH_PATH.resolve()),
                reference_top="tb",
                candidate_top="cordic",
                reference_precheck="pass",
                candidate_precheck="pass",
                interface_status="compatible",
                formal_status="equivalent",
                proof_type="simulation_tb",
                reason_bucket=classify_reason_bucket(
                    formal_status="equivalent",
                    interface_status="compatible",
                    reason="tb_cordic passed",
                ),
                reason="tb_cordic passed",
                interface_reason_kind="testbench_matched",
                interface_reason="tb_cordic compiled against candidate cordic",
                interface_aliases_applied=[],
                counterexample_summary="",
                counterexample=None,
            )
            results.append(result)
            emit(format_check_result_line(result))

        observed_names = sort_candidate_names([Path(result.candidate_file).name for result in results])
        missing_names = [name for name in expected_names if name not in observed_names]
        summary = {
            "backend": backend,
            "reference_file": str(CORDIC_TESTBENCH_PATH.resolve()),
            "candidate_path": str(candidates.resolve()),
            "module_dir": module_dir,
            "model_filter": model,
            "depth": None,
            "timeout": timeout,
            "tool_path": "iverilog+vvp",
            "results": [asdict(result) for result in results],
            "total_candidates": len(results),
            "observed_candidate_names": observed_names,
            "observed_candidates": len(observed_names),
            "candidate_expectation_mode": candidate_expectation_mode,
            "expected_attempts": expected_attempts,
            "expected_candidate_names": expected_names,
            "missing_candidate_names": missing_names,
            "missing_candidates": len(missing_names),
            "counts": summarize_counts(results, "formal_status"),
            "interface_counts": summarize_counts(results, "interface_status"),
            "precheck_counts": summarize_counts(results, "candidate_precheck"),
            "model_counts": summarize_counts(results, "model"),
            "reason_bucket_counts": summarize_counts(results, "reason_bucket"),
            "interface_reason_kind_counts": summarize_counts(results, "interface_reason_kind"),
            "formal_status_by_model": summarize_nested_counts(results, "model", "formal_status"),
            "interface_status_by_model": summarize_nested_counts(
                results, "model", "interface_status"
            ),
            "reason_bucket_by_model": summarize_nested_counts(results, "model", "reason_bucket"),
            "interface_reason_kind_by_model": summarize_nested_counts(
                results, "model", "interface_reason_kind"
            ),
            "simulation_testbench": str(CORDIC_TESTBENCH_PATH.resolve()),
        }
        write_json(report.resolve(), summary)
        write_check_csv_report(csv_report.resolve(), results)
        emit(f"Report written to {report.resolve()}")
        emit(f"CSV report written to {csv_report.resolve()}")
        if live_log_block is not None and logs:
            live_log_block("\n".join(logs))
        success = all(result.formal_status == "equivalent" for result in results)
        return (0 if success else 1), summary, logs
    finally:
        if live_log_block is not None and logs and not results:
            live_log_block("\n".join(logs))


def execute_check(
    *,
    reference: Path,
    candidates: Path,
    module_dir: str,
    support_root: Path | None,
    include_dirs: list[Path],
    backend: str,
    model: str | None,
    yosys_path: str,
    tool_path: str,
    depth: int,
    timeout: int,
    expected_attempts: int | None,
    report: Path,
    csv_report: Path,
    interface_aliases: Path,
    live_log: Callable[[str], None] | None = None,
    live_log_block: Callable[[str], None] | None = None,
) -> tuple[int, dict[str, object], list[str]]:
    if module_dir == "cordic":
        return execute_cordic_testbench_check(
            backend=backend,
            candidates=candidates,
            module_dir=module_dir,
            model=model,
            timeout=timeout,
            expected_attempts=expected_attempts,
            report=report,
            csv_report=csv_report,
            live_log=live_log,
            live_log_block=live_log_block,
        )

    reference_file = discover_reference_file(reference)
    global_aliases, module_aliases = load_interface_aliases(interface_aliases.resolve())
    support_root_path = (
        support_root.resolve() if support_root is not None else reference_file.parent.parent.resolve()
    )
    support_context = prepare_support_context(module_dir, support_root_path, reference_file)
    if requires_formal_friendly_cordic_rewrite(module_dir):
        support_context = prepare_formal_friendly_cordic_support_context(support_context)
    logs: list[str] = []

    def emit(message: str) -> None:
        logs.append(message)
        if live_log is not None:
            live_log(message)

    def finish_module_setup_failure(
        reason: str,
        *,
        observed_names: list[str],
        candidate_expectation_mode: str,
        expected_names: list[str],
    ) -> tuple[int, dict[str, object], list[str]]:
        missing_names = [name for name in expected_names if name not in observed_names]
        summary = {
            "backend": backend,
            "reference_file": str(support_context.reference_file),
            "candidate_path": str(candidates.resolve()),
            "module_dir": module_dir,
            "model_filter": model,
            "depth": depth,
            "timeout": timeout,
            "tool_path": tool_path,
            "results": [],
            "total_candidates": 0,
            "observed_candidate_names": observed_names,
            "observed_candidates": len(observed_names),
            "candidate_expectation_mode": candidate_expectation_mode,
            "expected_attempts": expected_attempts,
            "expected_candidate_names": expected_names,
            "missing_candidate_names": missing_names,
            "missing_candidates": len(missing_names),
            "counts": {},
            "interface_counts": {},
            "precheck_counts": {},
            "model_counts": {},
            "reason_bucket_counts": {},
            "interface_reason_kind_counts": {},
            "formal_status_by_model": {},
            "interface_status_by_model": {},
            "reason_bucket_by_model": {},
            "interface_reason_kind_by_model": {},
            "module_error": reason,
        }
        emit(reason)
        write_json(report.resolve(), summary)
        write_check_csv_report(csv_report.resolve(), [])
        emit(f"Report written to {report.resolve()}")
        emit(f"CSV report written to {csv_report.resolve()}")
        if live_log_block is not None and logs:
            live_log_block("\n".join(logs))
        return 2, summary, logs

    try:
        emit(f"start: backend={backend} module={module_dir} model={model or 'all'}")
        candidate_groups = discover_candidate_groups(candidates.resolve(), module_dir, model)
        discovered_candidate_names = sort_candidate_names(
            [candidate_file.name for _, candidate_file in candidate_groups]
        )
        candidate_expectation_mode, expected_names = resolve_expected_candidate_names(
            module_dir,
            candidate_groups,
            expected_attempts,
        )
        try:
            reference_top = require_resolved_top(
                module_dir,
                support_context.reference_file,
                role="reference",
            )
            reference_raw_interface = extract_module_interface(
                support_context.reference_file, reference_top
            )
        except Exception as exc:
            return finish_module_setup_failure(
                f"Reference setup failed: {exc}",
                observed_names=discovered_candidate_names,
                candidate_expectation_mode=candidate_expectation_mode,
                expected_names=expected_names,
            )
        reference_support_files = tuple(
            filter_compile_support_files(
                support_context.reference_file,
                support_context.support_files,
            )
        )
        reference_proof_support_files = tuple(
            filter_compile_support_files(
                support_context.reference_file,
                support_context.proof_support_files,
            )
        )
        search_roots = dedupe_paths([REPO_ROOT, support_context.effective_support_root])
        extra_include_dirs = [path.resolve() for path in include_dirs]
        gold_files = [
            *support_context.prefix_files,
            support_context.reference_file,
            *reference_support_files,
        ]
        gold_proof_files = [
            *support_context.prefix_files,
            support_context.reference_file,
            *reference_proof_support_files,
        ]
        gold_interface_files = [*support_context.prefix_files, support_context.reference_file]
        reference_proof_type = detect_proof_type(gold_proof_files, reference_top)
        if reference_proof_type not in {"strict_comb", "bounded_seq"}:
            reference_proof_type = "bounded_seq"
        reference_include_dirs = build_include_dirs(
            gold_proof_files,
            search_roots,
            extra_include_dirs,
            support_context=support_context,
        )

        gold_ok, gold_msg = precheck_design(
            backend=backend,
            tool_path=tool_path,
            files=gold_files,
            include_dirs=reference_include_dirs,
            top=reference_top,
            timeout=timeout,
        )
        reference_normalized_interface: NormalizedModuleInterface | None = None
        reference_normalization_msg = ""
        if gold_ok:
            (
                reference_normalized_interface,
                reference_normalization_msg,
            ) = extract_normalized_interface(
                yosys=yosys_path,
                files=gold_interface_files,
                include_dirs=reference_include_dirs,
                top=reference_top,
                timeout=timeout,
                library_files=list(reference_support_files),
            )

        input_ports = (
            [
                name
                for name in reference_normalized_interface.ordered_ports
                if reference_normalized_interface.ports[name].direction == "input"
            ]
            if reference_normalized_interface is not None
            else []
        )
        output_ports = (
            [
                name
                for name in reference_normalized_interface.ordered_ports
                if reference_normalized_interface.ports[name].direction == "output"
            ]
            if reference_normalized_interface is not None
            else []
        )
        clock_port = (
            detect_clock_port(reference_normalized_interface)
            if reference_normalized_interface is not None
            else None
        )
        reset_expr = (
            detect_reset_expr(reference_normalized_interface)
            if reference_normalized_interface is not None
            else None
        )
        module_alias_map = aliases_for_module(
            global_aliases=global_aliases,
            module_aliases=module_aliases,
            module_dir=module_dir,
        )

        results: list[CompareResult] = []
        for current_model, candidate_file in candidate_groups:
            effective_candidate_file, candidate_cleanup_root = prepare_formal_friendly_candidate_file(
                module_dir,
                candidate_file,
            )
            try:
                candidate_top = effective_candidate_file.stem
                try:
                    candidate_top = require_resolved_top(
                        module_dir,
                        effective_candidate_file,
                        role="candidate",
                    )
                    candidate_raw_interface = extract_module_interface(
                        effective_candidate_file,
                        candidate_top,
                    )
                except ValueError as exc:
                    result = CompareResult(
                        backend=backend,
                        model=current_model,
                        module_dir=module_dir,
                        candidate_file=str(candidate_file),
                        reference_file=str(support_context.reference_file),
                        reference_top=reference_top,
                        candidate_top=candidate_top,
                        reference_precheck="pass" if gold_ok else "fail",
                        candidate_precheck="fail",
                        interface_status="skip",
                        formal_status="skip",
                        proof_type="unknown",
                        reason_bucket=classify_reason_bucket(
                            formal_status="skip",
                            interface_status="skip",
                            reason=f"Candidate precheck failed: {exc}",
                        ),
                        reason=f"Candidate precheck failed: {exc}",
                        interface_reason_kind="",
                        interface_reason="",
                        interface_aliases_applied=[],
                        counterexample_summary="",
                        counterexample=None,
                    )
                    results.append(result)
                    emit(format_check_result_line(result))
                    continue
                gate_support_files = filter_compile_support_files(
                    effective_candidate_file,
                    reference_support_files,
                )
                gate_proof_support_files = filter_compile_support_files(
                    effective_candidate_file,
                    reference_proof_support_files,
                )
                gate_files = [
                    *support_context.prefix_files,
                    effective_candidate_file,
                    *gate_support_files,
                ]
                gate_proof_files = [
                    *support_context.prefix_files,
                    effective_candidate_file,
                    *gate_proof_support_files,
                ]
                gate_interface_files = [*support_context.prefix_files, effective_candidate_file]
                candidate_proof_type = detect_proof_type(gate_proof_files, candidate_top)
                if candidate_proof_type not in {"strict_comb", "bounded_seq"}:
                    candidate_proof_type = "bounded_seq"
                proof_type = (
                    "bounded_seq"
                    if "bounded_seq" in {reference_proof_type, candidate_proof_type}
                    else "strict_comb"
                )
                candidate_include_dirs = build_include_dirs(
                    gate_proof_files,
                    search_roots,
                    extra_include_dirs,
                    support_context=support_context,
                )
                gate_ok, gate_msg = precheck_design(
                    backend=backend,
                    tool_path=tool_path,
                    files=gate_files,
                    include_dirs=candidate_include_dirs,
                    top=candidate_top,
                    timeout=timeout,
                )

                if not gold_ok:
                    result = CompareResult(
                        backend=backend,
                        model=current_model,
                        module_dir=module_dir,
                        candidate_file=str(candidate_file),
                        reference_file=str(support_context.reference_file),
                        reference_top=reference_top,
                        candidate_top=candidate_top,
                        reference_precheck="fail",
                        candidate_precheck="pass" if gate_ok else "fail",
                        interface_status="skip",
                        formal_status="skip",
                        proof_type=proof_type,
                        reason=f"Reference precheck failed: {gold_msg}",
                        interface_reason_kind="",
                        interface_reason="",
                        interface_aliases_applied=[],
                        reason_bucket=classify_reason_bucket(
                            formal_status="skip",
                            interface_status="skip",
                            reason=f"Reference precheck failed: {gold_msg}",
                        ),
                        counterexample_summary="",
                        counterexample=None,
                    )
                    results.append(result)
                    emit(format_check_result_line(result))
                    continue

                if not gate_ok:
                    result = CompareResult(
                        backend=backend,
                        model=current_model,
                        module_dir=module_dir,
                        candidate_file=str(candidate_file),
                        reference_file=str(support_context.reference_file),
                        reference_top=reference_top,
                        candidate_top=candidate_top,
                        reference_precheck="pass",
                        candidate_precheck="fail",
                        interface_status="skip",
                        formal_status="skip",
                        proof_type=proof_type,
                        reason=f"Candidate precheck failed: {gate_msg}",
                        interface_reason_kind="",
                        interface_reason="",
                        interface_aliases_applied=[],
                        reason_bucket=classify_reason_bucket(
                            formal_status="skip",
                            interface_status="skip",
                            reason=f"Candidate precheck failed: {gate_msg}",
                        ),
                        counterexample_summary="",
                        counterexample=None,
                    )
                    results.append(result)
                    emit(format_check_result_line(result))
                    continue

                if reference_normalized_interface is None:
                    result = CompareResult(
                        backend=backend,
                        model=current_model,
                        module_dir=module_dir,
                        candidate_file=str(candidate_file),
                        reference_file=str(support_context.reference_file),
                        reference_top=reference_top,
                        candidate_top=candidate_top,
                        reference_precheck="pass",
                        candidate_precheck="pass",
                        interface_status="skip",
                        formal_status="skip",
                        proof_type=proof_type,
                        reason="Reference interface normalization failed",
                        interface_reason_kind="normalization_failed",
                        interface_reason=(
                            "reference interface normalization failed: "
                            f"{reference_normalization_msg}"
                        ),
                        interface_aliases_applied=[],
                        reason_bucket=classify_reason_bucket(
                            formal_status="skip",
                            interface_status="skip",
                            reason="Reference interface normalization failed",
                        ),
                        counterexample_summary="",
                        counterexample=None,
                    )
                    results.append(result)
                    emit(format_check_result_line(result))
                    continue

                (
                    candidate_normalized_interface,
                    candidate_normalization_msg,
                ) = extract_normalized_interface(
                    yosys=yosys_path,
                    files=gate_interface_files,
                    include_dirs=candidate_include_dirs,
                    top=candidate_top,
                    timeout=timeout,
                    library_files=list(gate_support_files),
                )
                if candidate_normalized_interface is None:
                    result = CompareResult(
                        backend=backend,
                        model=current_model,
                        module_dir=module_dir,
                        candidate_file=str(candidate_file),
                        reference_file=str(support_context.reference_file),
                        reference_top=reference_top,
                        candidate_top=candidate_top,
                        reference_precheck="pass",
                        candidate_precheck="pass",
                        interface_status="incompatible",
                        formal_status="skip",
                        proof_type=proof_type,
                        reason="Interface normalization rejected candidate",
                        interface_reason_kind="normalization_failed",
                        interface_reason=(
                            "candidate interface normalization failed: "
                            f"{candidate_normalization_msg}"
                        ),
                        interface_aliases_applied=[],
                        reason_bucket=classify_reason_bucket(
                            formal_status="skip",
                            interface_status="incompatible",
                            reason="Interface normalization rejected candidate",
                        ),
                        counterexample_summary="",
                        counterexample=None,
                    )
                    results.append(result)
                    emit(format_check_result_line(result))
                    continue

                interface_comparison = compare_normalized_interfaces(
                    reference=reference_normalized_interface,
                    candidate=candidate_normalized_interface,
                    reference_raw=reference_raw_interface,
                    candidate_raw=candidate_raw_interface,
                    alias_map=module_alias_map,
                )
                if not interface_comparison.compatible:
                    result = CompareResult(
                        backend=backend,
                        model=current_model,
                        module_dir=module_dir,
                        candidate_file=str(candidate_file),
                        reference_file=str(support_context.reference_file),
                        reference_top=reference_top,
                        candidate_top=candidate_top,
                        reference_precheck="pass",
                        candidate_precheck="pass",
                        interface_status="incompatible",
                        formal_status="skip",
                        proof_type=proof_type,
                        reason="Interface normalization rejected candidate",
                        interface_reason_kind=interface_comparison.interface_reason_kind,
                        interface_reason=interface_comparison.interface_reason,
                        interface_aliases_applied=list(interface_comparison.aliases_applied),
                        reason_bucket=classify_reason_bucket(
                            formal_status="skip",
                            interface_status="incompatible",
                            reason="Interface normalization rejected candidate",
                        ),
                        counterexample_summary="",
                        counterexample=None,
                    )
                    results.append(result)
                    emit(format_check_result_line(result))
                    continue

                gate_wrapper_source = None
                gate_impl_rename_from = None
                gate_impl_rename_to = None
                effective_candidate_top = candidate_top
                if interface_comparison.gate_wrapper is not None:
                    effective_candidate_top = interface_comparison.gate_wrapper.wrapper_top
                    instance_top = (
                        interface_comparison.gate_wrapper.raw_candidate_top
                        if backend == "jasper"
                        else interface_comparison.gate_wrapper.impl_top
                    )
                    gate_wrapper_source = build_alias_wrapper_source(
                        reference=reference_normalized_interface,
                        wrapper_top=interface_comparison.gate_wrapper.wrapper_top,
                        impl_top=instance_top,
                        canonical_to_candidate=interface_comparison.gate_wrapper.canonical_to_candidate,
                    )
                    if backend != "jasper":
                        gate_impl_rename_from = interface_comparison.gate_wrapper.raw_candidate_top
                        gate_impl_rename_to = interface_comparison.gate_wrapper.impl_top

                formal_status, reason, counterexample_summary, counterexample = run_equivalence(
                    backend=backend,
                    tool_path=tool_path,
                    gold_files=gold_proof_files,
                    gate_files=gate_proof_files,
                    reference_top=reference_top,
                    candidate_top=effective_candidate_top,
                    reference_includes=reference_include_dirs,
                    candidate_includes=candidate_include_dirs,
                    input_ports=input_ports,
                    output_ports=output_ports,
                    proof_type=proof_type,
                    has_rst="rst" in reference_normalized_interface.ports,
                    depth=depth,
                    timeout=timeout,
                    clock_port=clock_port,
                    reset_expr=reset_expr,
                    gate_wrapper_source=gate_wrapper_source,
                    gate_impl_rename_from=gate_impl_rename_from,
                    gate_impl_rename_to=gate_impl_rename_to,
                )
                result = CompareResult(
                    backend=backend,
                    model=current_model,
                    module_dir=module_dir,
                    candidate_file=str(candidate_file),
                    reference_file=str(support_context.reference_file),
                    reference_top=reference_top,
                    candidate_top=candidate_top,
                    reference_precheck="pass",
                    candidate_precheck="pass",
                    interface_status="compatible",
                    formal_status=formal_status,
                    proof_type=proof_type,
                    reason_bucket=classify_reason_bucket(
                        formal_status=formal_status,
                        interface_status="compatible",
                        reason=reason,
                    ),
                    reason=reason,
                    interface_reason_kind=interface_comparison.interface_reason_kind,
                    interface_reason=interface_comparison.interface_reason,
                    interface_aliases_applied=list(interface_comparison.aliases_applied),
                    counterexample_summary=counterexample_summary,
                    counterexample=counterexample,
                )
                results.append(result)
                emit(format_check_result_line(result))
            finally:
                if candidate_cleanup_root is not None:
                    shutil.rmtree(candidate_cleanup_root, ignore_errors=True)

        observed_names = sort_candidate_names([Path(result.candidate_file).name for result in results])
        missing_names = [name for name in expected_names if name not in observed_names]

        summary = {
            "backend": backend,
            "reference_file": str(support_context.reference_file),
            "candidate_path": str(candidates.resolve()),
            "module_dir": module_dir,
            "model_filter": model,
            "depth": depth,
            "timeout": timeout,
            "tool_path": tool_path,
            "results": [asdict(result) for result in results],
            "total_candidates": len(results),
            "observed_candidate_names": observed_names,
            "observed_candidates": len(observed_names),
            "candidate_expectation_mode": candidate_expectation_mode,
            "expected_attempts": expected_attempts,
            "expected_candidate_names": expected_names,
            "missing_candidate_names": missing_names,
            "missing_candidates": len(missing_names),
            "counts": summarize_counts(results, "formal_status"),
            "interface_counts": summarize_counts(results, "interface_status"),
            "precheck_counts": summarize_counts(results, "candidate_precheck"),
            "model_counts": summarize_counts(results, "model"),
            "reason_bucket_counts": summarize_counts(results, "reason_bucket"),
            "interface_reason_kind_counts": summarize_counts(results, "interface_reason_kind"),
            "formal_status_by_model": summarize_nested_counts(results, "model", "formal_status"),
            "interface_status_by_model": summarize_nested_counts(
                results, "model", "interface_status"
            ),
            "reason_bucket_by_model": summarize_nested_counts(results, "model", "reason_bucket"),
            "interface_reason_kind_by_model": summarize_nested_counts(
                results, "model", "interface_reason_kind"
            ),
        }
        write_json(report.resolve(), summary)
        write_check_csv_report(csv_report.resolve(), results)
        emit(f"Report written to {report.resolve()}")
        emit(f"CSV report written to {csv_report.resolve()}")
        if live_log_block is not None and logs:
            live_log_block("\n".join(logs))

        success = all(result.formal_status == "equivalent" for result in results)
        return (0 if success else 1), summary, logs
    finally:
        if support_context.cleanup_root is not None:
            shutil.rmtree(support_context.cleanup_root, ignore_errors=True)


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
                    "backend": payload.get("backend", "yosys"),
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
                    "reason_bucket": result.get("reason_bucket", "license_or_tool_error"),
                    "reason": result["reason"],
                    "interface_reason_kind": result.get("interface_reason_kind", ""),
                    "interface_reason": result.get("interface_reason", ""),
                    "interface_aliases_applied": json.dumps(
                        result.get("interface_aliases_applied", []),
                        ensure_ascii=False,
                    ),
                    "counterexample_summary": result.get("counterexample_summary", ""),
                }
            )
    return rows


def write_detailed_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "backend",
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
        "reason_bucket",
        "reason",
        "interface_reason_kind",
        "interface_reason",
        "interface_aliases_applied",
        "counterexample_summary",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def nested_row_counts(rows: list[dict[str, object]], first: str, second: str) -> dict[str, dict[str, int]]:
    counts: dict[str, Counter[str]] = defaultdict(Counter)
    for row in rows:
        counts[str(row[first])][str(row[second])] += 1
    return {
        key: dict(sorted(counter.items()))
        for key, counter in sorted(counts.items(), key=lambda item: item[0])
    }


def collect_missing_candidates(report_files: list[Path]) -> list[dict[str, object]]:
    missing: list[dict[str, object]] = []
    for report_file in report_files:
        payload = json.loads(report_file.read_text(encoding="utf-8"))
        expectation_mode = payload.get("candidate_expectation_mode")
        if expectation_mode is None and payload.get("expected_attempts") is not None:
            expectation_mode = "fixed_attempts"
        if expectation_mode != "fixed_attempts":
            continue
        for candidate_name in payload.get("missing_candidate_names", []):
            missing.append(
                {
                    "backend": payload.get("backend", "yosys"),
                    "module_dir": payload["module_dir"],
                    "model": payload.get("model_filter"),
                    "attempt": parse_attempt(candidate_name),
                    "candidate_name": candidate_name,
                }
            )
    missing.sort(
        key=lambda row: (
            str(row["module_dir"]),
            "" if row["model"] is None else str(row["model"]),
            -1 if row["attempt"] is None else int(row["attempt"]),
        )
    )
    return missing


def build_detailed_summary(rows: list[dict[str, object]], report_files: list[Path]) -> dict[str, object]:
    overall_formal = Counter(str(row["formal_status"]) for row in rows)
    overall_interface = Counter(str(row["interface_status"]) for row in rows)
    overall_reason_bucket = Counter(str(row["reason_bucket"]) for row in rows)
    overall_interface_reason_kind = Counter(str(row["interface_reason_kind"]) for row in rows)
    missing_candidates = collect_missing_candidates(report_files)

    equivalent_rows = [
        {
            "backend": row["backend"],
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
            "backend": row["backend"],
            "module_dir": row["module_dir"],
            "model": row["model"],
            "attempt": row["attempt"],
            "candidate_name": row["candidate_name"],
            "reason_bucket": row["reason_bucket"],
            "reason": row["reason"],
            "interface_reason_kind": row["interface_reason_kind"],
            "interface_reason": row["interface_reason"],
        }
        for row in rows
        if row["formal_status"] == "skip"
    ]
    failing_rows = [
        {
            "backend": row["backend"],
            "module_dir": row["module_dir"],
            "model": row["model"],
            "attempt": row["attempt"],
            "candidate_name": row["candidate_name"],
            "reason_bucket": row["reason_bucket"],
            "reason": row["reason"],
            "interface_reason_kind": row["interface_reason_kind"],
            "interface_reason": row["interface_reason"],
            "counterexample_summary": row["counterexample_summary"],
        }
        for row in rows
        if row["formal_status"] == "not_equivalent"
    ]
    tool_limited_rows = [
        {
            "backend": row["backend"],
            "module_dir": row["module_dir"],
            "model": row["model"],
            "attempt": row["attempt"],
            "candidate_name": row["candidate_name"],
            "reason_bucket": row["reason_bucket"],
            "reason": row["reason"],
            "interface_reason_kind": row["interface_reason_kind"],
            "interface_reason": row["interface_reason"],
        }
        for row in rows
        if row["formal_status"] == "tool_limited"
    ]

    return {
        "report_file_count": len(report_files),
        "total_rows": len(rows),
        "overall_formal_counts": dict(sorted(overall_formal.items())),
        "overall_interface_counts": dict(sorted(overall_interface.items())),
        "overall_reason_bucket_counts": dict(sorted(overall_reason_bucket.items())),
        "overall_interface_reason_kind_counts": dict(sorted(overall_interface_reason_kind.items())),
        "formal_counts_by_module": nested_row_counts(rows, "module_dir", "formal_status"),
        "formal_counts_by_model": nested_row_counts(rows, "model", "formal_status"),
        "formal_counts_by_attempt": nested_row_counts(rows, "attempt", "formal_status"),
        "reason_bucket_counts_by_module": nested_row_counts(rows, "module_dir", "reason_bucket"),
        "reason_bucket_counts_by_model": nested_row_counts(rows, "model", "reason_bucket"),
        "reason_bucket_counts_by_attempt": nested_row_counts(rows, "attempt", "reason_bucket"),
        "interface_reason_kind_counts_by_module": nested_row_counts(
            rows, "module_dir", "interface_reason_kind"
        ),
        "interface_reason_kind_counts_by_model": nested_row_counts(
            rows, "model", "interface_reason_kind"
        ),
        "interface_reason_kind_counts_by_attempt": nested_row_counts(
            rows, "attempt", "interface_reason_kind"
        ),
        "observed_candidates": len(rows),
        "missing_candidates": len(missing_candidates),
        "missing_candidate_rows": missing_candidates,
        "equivalent_candidates": equivalent_rows,
        "skipped_candidates": skipped_rows,
        "not_equivalent_candidates": failing_rows,
        "tool_limited_candidates": tool_limited_rows,
    }


def build_markdown_summary(summary: dict[str, object]) -> str:
    lines = [
        "# Formal Equivalence Summary",
        "",
        f"- Observed candidates: {summary['observed_candidates']}",
        f"- Missing candidates: {summary['missing_candidates']}",
        f"- Equivalent: {summary['overall_formal_counts'].get('equivalent', 0)}",
        f"- Not equivalent: {summary['overall_formal_counts'].get('not_equivalent', 0)}",
        f"- Skip: {summary['overall_formal_counts'].get('skip', 0)}",
        f"- Tool limited: {summary['overall_formal_counts'].get('tool_limited', 0)}",
        "",
        "## Reason Buckets",
    ]
    for bucket, count in sorted(summary["overall_reason_bucket_counts"].items()):
        lines.append(f"- {bucket}: {count}")

    if summary["missing_candidate_rows"]:
        lines.extend(["", "## Missing Candidates"])
        for row in summary["missing_candidate_rows"]:
            lines.append(f"- {row['module_dir']}/{row['candidate_name']}")
    return "\n".join(lines) + "\n"


def run_summarize_outputs(
    *,
    report_dir: Path,
    detail_csv: Path,
    summary_json: Path,
    summary_md: Path,
) -> tuple[int, dict[str, object] | None, list[str]]:
    report_files = discover_report_files(report_dir.resolve())
    if not report_files:
        return 2, None, [f"No report JSON files found in {report_dir}"]

    rows = build_flat_rows(report_files)
    rows.sort(
        key=lambda row: (
            str(row["module_dir"]),
            str(row["model"]),
            -1 if row["attempt"] is None else int(row["attempt"]),
        )
    )

    write_detailed_csv(detail_csv.resolve(), rows)
    summary = build_detailed_summary(rows, report_files)
    write_json(summary_json.resolve(), summary)
    summary_md.resolve().parent.mkdir(parents=True, exist_ok=True)
    summary_md.resolve().write_text(build_markdown_summary(summary), encoding="utf-8")
    logs = [
        f"Detailed CSV written to {detail_csv.resolve()}",
        f"Detailed summary written to {summary_json.resolve()}",
        f"Markdown summary written to {summary_md.resolve()}",
    ]
    return 0, summary, logs


def discover_modules(root: Path) -> list[str]:
    return sorted(path.name for path in root.iterdir() if path.is_dir())


def discover_prefixed_modules(root: Path, prefix: str) -> list[str]:
    return [f"{prefix}{name}" for name in discover_modules(root)]


def build_suite_plan(args: argparse.Namespace, excludes: set[str]) -> list[tuple[str, str, Path]]:
    plan: list[tuple[str, str, Path]] = []

    def add_entries(family: str, root: Path, module_names: list[str], path_builder: Callable[[str], Path]) -> None:
        for module_dir in module_names:
            if module_dir in excludes:
                continue
            plan.append((family, module_dir, path_builder(module_dir)))

    double_root = args.double_root.resolve()
    double_pipeline_root = args.double_pipeline_root.resolve()
    or1200_root = args.or1200_root.resolve()
    i2c_root = args.i2c_root.resolve()
    mips_root = args.mips_root.resolve()
    cordic_root = args.cordic_root.resolve()

    add_entries(
        "double_fpu",
        double_root,
        discover_modules(double_root),
        lambda module_dir: double_root / module_dir,
    )
    add_entries(
        "double_fpu",
        double_pipeline_root,
        discover_modules(double_pipeline_root),
        lambda module_dir: double_pipeline_root / module_dir,
    )
    add_entries(
        "or1200",
        or1200_root,
        discover_modules(or1200_root),
        lambda module_dir: or1200_root / module_dir,
    )
    add_entries(
        "i2c",
        i2c_root,
        discover_modules(i2c_root),
        lambda module_dir: i2c_root / module_dir,
    )

    mips_source_modules = discover_modules(mips_root)
    add_entries(
        "mips_16",
        mips_root,
        [f"mips_{module_dir}" for module_dir in mips_source_modules],
        lambda module_dir: mips_root / module_dir[len("mips_") :],
    )
    add_entries(
        "verilog_cordic_core",
        cordic_root,
        discover_modules(cordic_root),
        lambda module_dir: cordic_root / module_dir,
    )
    return sorted(plan, key=lambda item: (item[0], item[1]))


def write_suite_csv(path: Path, rows: list[dict[str, object]]) -> None:
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
        "missing_candidates",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def compile_success(verilog_file: Path, iverilog: str, timeout: int) -> tuple[bool, str]:
    stem = verilog_file.stem
    match = TARGET_RE.match(stem)
    top = match.group("base") if match else stem

    with tempfile.TemporaryDirectory(prefix="iverilog_check_") as tempdir:
        output_file = Path(tempdir) / f"{top}.out"
        ok, output = run_command(
            [
                iverilog,
                "-g2012",
                "-I",
                str(verilog_file.parent),
                "-s",
                top,
                "-o",
                str(output_file),
                str(verilog_file),
            ],
            cwd=verilog_file.parent,
            timeout=timeout,
        )
    if ok:
        return True, "Compile success"
    return False, "\n".join(output.splitlines()[:8])


def run_compile_scope(
    *,
    context: CompileModuleContext,
    model: str,
    candidate_file: Path,
    scope: str,
    iverilog: str,
    timeout: int,
) -> CompileDetailRow:
    expected_top = context.expected_top or "ambiguous_top"
    attempt = parse_attempt(candidate_file.name)
    macro_defines: tuple[tuple[str, str], ...] = tuple()

    if context.expected_top is None:
        return CompileDetailRow(
            model=model,
            family=context.family,
            module_dir=context.module_dir,
            candidate_file=str(candidate_file),
            attempt=attempt,
            scope=scope,
            expected_top=expected_top,
            status="fail",
            exit_code=-1,
            error_excerpt=context.top_error or "ambiguous_top",
        )

    if scope == "standalone":
        source_files = [candidate_file.resolve()]
        include_dirs = [candidate_file.parent.resolve()]
    elif scope == "with_support":
        filtered_support_files = filter_compile_support_files(candidate_file.resolve(), context.support_files)
        source_files = [candidate_file.resolve(), *filtered_support_files]
        include_dirs = build_include_dirs(
            files=[*context.prefix_files, candidate_file.resolve(), *filtered_support_files],
            search_roots=list(context.search_roots),
            extra_include_dirs=[],
            support_context=context.support_context,
        )
        macro_defines = compile_macro_defines_for_scope(context, candidate_file.resolve(), scope)
    else:
        raise ValueError(f"Unsupported scope: {scope}")

    ok, output, exit_code = run_iverilog_compile(
        source_files=source_files,
        include_dirs=include_dirs,
        macro_defines=macro_defines,
        top=context.expected_top,
        iverilog=iverilog,
        cwd=candidate_file.parent.resolve(),
        timeout=timeout,
    )
    return CompileDetailRow(
        model=model,
        family=context.family,
        module_dir=context.module_dir,
        candidate_file=str(candidate_file),
        attempt=attempt,
        scope=scope,
        expected_top=context.expected_top,
        status="pass" if ok else "fail",
        exit_code=exit_code,
        error_excerpt=build_compile_error_excerpt(output, ok=ok),
    )


def write_compile_detail_csv(path: Path, rows: list[CompileDetailRow]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "model",
        "family",
        "module_dir",
        "candidate_file",
        "attempt",
        "scope",
        "expected_top",
        "status",
        "exit_code",
        "error_excerpt",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(asdict(row))


def write_compile_summary_csv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def add_compile_suite_parser(subparsers: argparse._SubParsersAction[argparse.ArgumentParser]) -> None:
    parser = subparsers.add_parser(
        "compile-suite",
        description="Run standalone and support-assisted iverilog compile checks for Result candidates.",
    )
    parser.add_argument("--result-root", type=Path, default=REPO_ROOT / "Result")
    parser.add_argument(
        "--report-dir",
        type=Path,
        default=REPO_ROOT / "reports" / "iverilog_compile",
    )
    parser.add_argument(
        "--scope",
        choices=("standalone", "with_support", "both"),
        default="both",
    )
    parser.add_argument("--model", default=None, help="Optional model name filter, for example claude.")
    parser.add_argument("--iverilog", default="iverilog")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--jobs", type=int, default=4)
    parser.set_defaults(func=run_compile_suite_command)


def run_compile_suite_command(args: argparse.Namespace) -> int:
    iverilog = shutil.which(args.iverilog)
    if iverilog is None:
        print(f"Tool not found: {args.iverilog}", file=sys.stderr, flush=True)
        return 2

    result_root = args.result_root.resolve()
    if not result_root.exists():
        print(f"Result root not found: {result_root}", file=sys.stderr, flush=True)
        return 2

    try:
        models = discover_compile_models(result_root, args.model)
        module_dirs = discover_compile_module_dirs(result_root, models)
        contexts = {module_dir: build_compile_module_context(module_dir) for module_dir in module_dirs}
    except (FileNotFoundError, ValueError) as exc:
        print(str(exc), file=sys.stderr, flush=True)
        return 2

    scopes = ["standalone", "with_support"] if args.scope == "both" else [args.scope]
    report_dir = args.report_dir.resolve()
    detail_path = report_dir / "compile_detail.csv"
    summary_by_module_path = report_dir / "compile_summary_by_model_module.csv"
    summary_by_model_path = report_dir / "compile_summary_by_model.csv"

    candidate_map: dict[tuple[str, str], list[Path]] = {}
    for model in models:
        model_root = result_root / model
        for module_dir in module_dirs:
            module_root = model_root / module_dir
            files = []
            if module_root.is_dir():
                files = sorted(
                    module_root.glob("*.v"),
                    key=lambda path: (parse_attempt(path.name) is None, parse_attempt(path.name) or 0, path.name),
                )
            candidate_map[(model, module_dir)] = [path.resolve() for path in files]

    future_map: dict[concurrent.futures.Future[CompileDetailRow], tuple[str, str, Path, str]] = {}
    detail_rows: list[CompileDetailRow] = []
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as executor:
            for model in models:
                for module_dir in module_dirs:
                    context = contexts[module_dir]
                    for candidate_file in candidate_map[(model, module_dir)]:
                        for scope in scopes:
                            future = executor.submit(
                                run_compile_scope,
                                context=context,
                                model=model,
                                candidate_file=candidate_file,
                                scope=scope,
                                iverilog=iverilog,
                                timeout=args.timeout,
                            )
                            future_map[future] = (model, module_dir, candidate_file, scope)

            for future in concurrent.futures.as_completed(future_map):
                detail_rows.append(future.result())
    finally:
        cleanup_compile_contexts(contexts)

    detail_rows.sort(
        key=lambda row: (
            row.model,
            row.family,
            row.module_dir,
            row.attempt is None,
            row.attempt or 0,
            row.scope,
            row.candidate_file,
        )
    )
    write_compile_detail_csv(detail_path, detail_rows)

    counts_by_scope: dict[tuple[str, str], Counter[str]] = defaultdict(Counter)
    for row in detail_rows:
        counts_by_scope[(row.model, row.module_dir)][f"{row.scope}_{row.status}"] += 1

    summary_by_module_rows: list[dict[str, object]] = []
    missing_modules_by_model: dict[str, list[str]] = defaultdict(list)
    for model in models:
        for module_dir in module_dirs:
            context = contexts[module_dir]
            observed_candidates = len(candidate_map[(model, module_dir)])
            if observed_candidates == 0:
                missing_modules_by_model[model].append(module_dir)
            counts = counts_by_scope[(model, module_dir)]
            summary_by_module_rows.append(
                {
                    "family": context.family,
                    "model": model,
                    "module_dir": module_dir,
                    "expected_attempts": COMPILE_EXPECTED_ATTEMPTS,
                    "observed_candidates": observed_candidates,
                    "standalone_pass": counts.get("standalone_pass", 0),
                    "standalone_fail": counts.get("standalone_fail", 0),
                    "with_support_pass": counts.get("with_support_pass", 0),
                    "with_support_fail": counts.get("with_support_fail", 0),
                }
            )

    summary_by_module_rows.sort(key=lambda row: (str(row["family"]), str(row["model"]), str(row["module_dir"])))
    write_compile_summary_csv(
        summary_by_module_path,
        summary_by_module_rows,
        [
            "family",
            "model",
            "module_dir",
            "expected_attempts",
            "observed_candidates",
            "standalone_pass",
            "standalone_fail",
            "with_support_pass",
            "with_support_fail",
        ],
    )

    summary_by_model_rows: list[dict[str, object]] = []
    for model in models:
        model_rows = [row for row in summary_by_module_rows if row["model"] == model]
        summary_by_model_rows.append(
            {
                "model": model,
                "expected_module_count": len(module_dirs),
                "observed_module_count": sum(1 for row in model_rows if int(row["observed_candidates"]) > 0),
                "missing_module_count": sum(1 for row in model_rows if int(row["observed_candidates"]) == 0),
                "observed_candidates": sum(int(row["observed_candidates"]) for row in model_rows),
                "standalone_pass": sum(int(row["standalone_pass"]) for row in model_rows),
                "standalone_fail": sum(int(row["standalone_fail"]) for row in model_rows),
                "with_support_pass": sum(int(row["with_support_pass"]) for row in model_rows),
                "with_support_fail": sum(int(row["with_support_fail"]) for row in model_rows),
            }
        )

    write_compile_summary_csv(
        summary_by_model_path,
        summary_by_model_rows,
        [
            "model",
            "expected_module_count",
            "observed_module_count",
            "missing_module_count",
            "observed_candidates",
            "standalone_pass",
            "standalone_fail",
            "with_support_pass",
            "with_support_fail",
        ],
    )

    overall = Counter()
    for row in summary_by_model_rows:
        overall["observed_candidates"] += int(row["observed_candidates"])
        overall["standalone_pass"] += int(row["standalone_pass"])
        overall["standalone_fail"] += int(row["standalone_fail"])
        overall["with_support_pass"] += int(row["with_support_pass"])
        overall["with_support_fail"] += int(row["with_support_fail"])

    print("overall totals:", flush=True)
    print(
        "  "
        f"observed_candidates={overall['observed_candidates']}  "
        f"standalone_pass={overall['standalone_pass']}  "
        f"standalone_fail={overall['standalone_fail']}  "
        f"with_support_pass={overall['with_support_pass']}  "
        f"with_support_fail={overall['with_support_fail']}",
        flush=True,
    )
    print("per-model totals:", flush=True)
    for row in summary_by_model_rows:
        print(
            "  "
            f"{row['model']}: observed_candidates={row['observed_candidates']}  "
            f"standalone_pass={row['standalone_pass']}  "
            f"standalone_fail={row['standalone_fail']}  "
            f"with_support_pass={row['with_support_pass']}  "
            f"with_support_fail={row['with_support_fail']}",
            flush=True,
        )
    print("missing modules:", flush=True)
    if not any(missing_modules_by_model.values()):
        print("  none", flush=True)
    else:
        for model in models:
            missing = missing_modules_by_model.get(model, [])
            if not missing:
                print(f"  {model}: none", flush=True)
                continue
            print(f"  {model}: {', '.join(missing)}", flush=True)
    print(f"detail csv: {detail_path}", flush=True)
    print(f"summary by model/module csv: {summary_by_module_path}", flush=True)
    print(f"summary by model csv: {summary_by_model_path}", flush=True)
    return 0


def legacy_equivalence_check(
    reference_file: Path,
    candidate_file: Path,
    yosys: str,
    depth: int,
    timeout: int,
) -> tuple[bool, str]:
    top = reference_file.stem
    script = "\n".join(
        [
            f"read_verilog {reference_file.resolve()}",
            "proc; memory; opt",
            f"rename {top} gold",
            "design -stash gold",
            "design -reset",
            f"read_verilog {candidate_file.resolve()}",
            "proc; memory; opt",
            f"rename {top} gate",
            "design -stash gate",
            "design -reset",
            "design -copy-from gold -as gold gold",
            "design -copy-from gate -as gate gate",
            "miter -equiv -make_assert -flatten gold gate miter",
            "hierarchy -top miter",
            "clk2fflogic",
            "opt",
            f"sat -verify -prove-asserts -set-init-zero -seq {depth}",
            "",
        ]
    )

    with tempfile.TemporaryDirectory(prefix="yosys_equiv_") as tempdir:
        script_file = Path(tempdir) / "equiv.ys"
        script_file.write_text(script, encoding="ascii")
        ok, output = run_command([yosys, "-s", str(script_file)], cwd=reference_file.parent, timeout=timeout)

    if ok and "SAT proof finished - no model found: SUCCESS!" in output:
        return True, f"Equivalent within {depth} cycles"

    if "SAT proof finished - model found: FAIL!" in output:
        key_lines = [
            line
            for line in output.splitlines()
            if "SAT proof finished - model found: FAIL!" in line
            or "Assert failed" in line
            or line.startswith("ERROR:")
        ]
        if not key_lines:
            key_lines = output.splitlines()[-8:]
        return False, f"Not equivalent within {depth} cycles\n" + "\n".join(key_lines)

    return False, "Yosys failed\n" + "\n".join(output.splitlines()[-8:])


def add_check_parser(subparsers: argparse._SubParsersAction[argparse.ArgumentParser]) -> None:
    parser = subparsers.add_parser(
        "check",
        description="Run formal equivalence checking for one reference Verilog against many candidates.",
    )
    parser.add_argument(
        "--reference",
        type=Path,
        default=REPO_ROOT / "Src" / "or1200_hp" / "des" / "verilog" / "or1200_alu",
        help="Reference Verilog file or a directory containing exactly one .v file.",
    )
    parser.add_argument(
        "--candidates",
        type=Path,
        default=REPO_ROOT / "Result",
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
    parser.add_argument("--backend", choices=("yosys", "jasper"), default="yosys")
    parser.add_argument("--model", default=None, help="Optional model name filter, for example claude.")
    parser.add_argument("--yosys", default="yosys")
    parser.add_argument("--jg", default="jg")
    parser.add_argument("--depth", type=int, default=8)
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument(
        "--expected-attempts",
        type=int,
        default=None,
        help=(
            "Optional fixed number of expected attempts. "
            "When omitted, candidate names are auto-discovered from the files on disk."
        ),
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=REPO_ROOT / "reports" / "formal_equivalence_or1200_alu_all_results.json",
    )
    parser.add_argument(
        "--csv-report",
        type=Path,
        default=REPO_ROOT / "reports" / "formal_equivalence_or1200_alu_all_results.csv",
    )
    parser.add_argument(
        "--interface-aliases",
        type=Path,
        default=REPO_ROOT / "tools" / "interface_aliases.json",
        help="JSON file containing explicit interface alias maps.",
    )
    parser.set_defaults(func=run_check_command)


def run_check_command(args: argparse.Namespace) -> int:
    try:
        yosys_path, tool_path = resolve_backend_tools(args.backend, args.yosys, args.jg)
    except FileNotFoundError as exc:
        print(str(exc), file=sys.stderr, flush=True)
        return 2

    def emit_live_log(message: str) -> None:
        print(message, flush=True)

    rc, _, logs = execute_check(
        reference=args.reference,
        candidates=args.candidates,
        module_dir=args.module_dir,
        support_root=args.support_root,
        include_dirs=list(args.include_dir),
        backend=args.backend,
        model=args.model,
        yosys_path=yosys_path,
        tool_path=tool_path,
        depth=args.depth,
        timeout=args.timeout,
        expected_attempts=args.expected_attempts,
        report=args.report,
        csv_report=args.csv_report,
        interface_aliases=args.interface_aliases,
        live_log=emit_live_log,
    )
    return rc


def add_summarize_parser(subparsers: argparse._SubParsersAction[argparse.ArgumentParser]) -> None:
    parser = subparsers.add_parser(
        "summarize",
        description="Flatten per-module formal equivalence JSON reports into detailed per-candidate reports.",
    )
    parser.add_argument(
        "--report-dir",
        type=Path,
        default=REPO_ROOT / "reports" / "formal_equivalence_suite",
    )
    parser.add_argument(
        "--detail-csv",
        type=Path,
        default=REPO_ROOT / "reports" / "formal_equivalence_suite_detailed.csv",
    )
    parser.add_argument(
        "--summary-json",
        type=Path,
        default=REPO_ROOT / "reports" / "formal_equivalence_suite_detailed_summary.json",
    )
    parser.add_argument(
        "--summary-md",
        type=Path,
        default=REPO_ROOT / "reports" / "formal_equivalence_suite_detailed_summary.md",
    )
    parser.set_defaults(func=run_summarize_command)


def run_summarize_command(args: argparse.Namespace) -> int:
    rc, _, logs = run_summarize_outputs(
        report_dir=args.report_dir,
        detail_csv=args.detail_csv,
        summary_json=args.summary_json,
        summary_md=args.summary_md,
    )
    if logs:
        stream = sys.stderr if rc != 0 else sys.stdout
        print("\n".join(logs), file=stream)
    return rc


def add_suite_parser(subparsers: argparse._SubParsersAction[argparse.ArgumentParser]) -> None:
    parser = subparsers.add_parser(
        "suite",
        description="Run the per-module formal equivalence checker across multiple modules.",
    )
    parser.add_argument(
        "--double-root",
        type=Path,
        default=REPO_ROOT / "Src" / "double_fpu" / "des" / "verilog",
    )
    parser.add_argument(
        "--double-pipeline-root",
        type=Path,
        default=REPO_ROOT / "Src" / "double_fpu" / "des" / "pipeline",
    )
    parser.add_argument(
        "--or1200-root",
        type=Path,
        default=REPO_ROOT / "Src" / "or1200_hp" / "des" / "verilog",
    )
    parser.add_argument(
        "--i2c-root",
        type=Path,
        default=REPO_ROOT / "Src" / "i2c" / "des" / "verilog",
    )
    parser.add_argument(
        "--mips-root",
        type=Path,
        default=REPO_ROOT / "Src" / "mips_16" / "des",
    )
    parser.add_argument(
        "--cordic-root",
        type=Path,
        default=REPO_ROOT / "Src" / "verilog_cordic_core" / "des",
    )
    parser.add_argument("--result-root", type=Path, default=REPO_ROOT / "Result")
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="Module directory to skip. Can be used multiple times.",
    )
    parser.add_argument("--backend", choices=("yosys", "jasper"), default="yosys")
    parser.add_argument("--model", default=None, help="Optional model name filter, for example claude.")
    parser.add_argument("--yosys", default="yosys")
    parser.add_argument("--jg", default="jg")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--depth", type=int, default=8)
    parser.add_argument(
        "--expected-attempts",
        type=int,
        default=None,
        help=(
            "Optional fixed number of expected attempts per module. "
            "When omitted, candidate names are auto-discovered from the files on disk."
        ),
    )
    parser.add_argument("--jobs", type=int, default=None)
    parser.add_argument(
        "--report-dir",
        type=Path,
        default=REPO_ROOT / "reports" / "formal_equivalence_suite",
    )
    parser.add_argument(
        "--summary-json",
        type=Path,
        default=REPO_ROOT / "reports" / "formal_equivalence_suite_summary.json",
    )
    parser.add_argument(
        "--summary-csv",
        type=Path,
        default=REPO_ROOT / "reports" / "formal_equivalence_suite_summary.csv",
    )
    parser.add_argument(
        "--interface-aliases",
        type=Path,
        default=REPO_ROOT / "tools" / "interface_aliases.json",
    )
    parser.set_defaults(func=run_suite_command)


def run_suite_command(args: argparse.Namespace) -> int:
    try:
        yosys_path, tool_path = resolve_backend_tools(args.backend, args.yosys, args.jg)
    except FileNotFoundError as exc:
        print(str(exc), file=sys.stderr, flush=True)
        return 2

    jobs = args.jobs if args.jobs is not None else (1 if args.backend == "jasper" else 4)
    excludes = set(args.exclude)
    plan = build_suite_plan(args, excludes)

    module_report_dir = args.report_dir.resolve()
    module_report_dir.mkdir(parents=True, exist_ok=True)

    module_summaries: list[dict[str, object]] = []
    flat_rows: list[dict[str, object]] = []
    overall_formal = Counter()
    overall_interface = Counter()
    overall_reason_bucket = Counter()
    family_formal: dict[str, Counter[str]] = defaultdict(Counter)
    model_formal: dict[str, Counter[str]] = defaultdict(Counter)
    print_lock = threading.Lock()

    def emit_live_log_block(message: str) -> None:
        with print_lock:
            print(message, flush=True)

    exit_code = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as executor:
        future_map = {}
        for family, module_dir, reference_path in plan:
            future = executor.submit(
                execute_check,
                reference=reference_path,
                candidates=args.result_root.resolve(),
                module_dir=module_dir,
                support_root=None,
                include_dirs=[],
                backend=args.backend,
                model=args.model,
                yosys_path=yosys_path,
                tool_path=tool_path,
                depth=args.depth,
                timeout=args.timeout,
                expected_attempts=args.expected_attempts,
                report=module_report_dir / f"{module_dir}.json",
                csv_report=module_report_dir / f"{module_dir}.csv",
                interface_aliases=args.interface_aliases.resolve(),
                live_log_block=emit_live_log_block,
            )
            future_map[future] = (family, module_dir)

        for future in concurrent.futures.as_completed(future_map):
            family, module_dir = future_map[future]
            rc, report, logs = future.result()
            if rc not in {0, 1}:
                exit_code = rc

            module_summary = {
                "family": family,
                "module_dir": module_dir,
                "reference_file": report["reference_file"],
                "total_candidates": report["total_candidates"],
                "counts": report["counts"],
                "interface_counts": report["interface_counts"],
                "reason_bucket_counts": report.get("reason_bucket_counts", {}),
                "model_counts": report["model_counts"],
                "observed_candidates": report.get("observed_candidates", report["total_candidates"]),
                "candidate_expectation_mode": report.get("candidate_expectation_mode", "auto"),
                "expected_attempts": report.get("expected_attempts"),
                "missing_candidates": report.get("missing_candidates", 0),
                "missing_candidate_names": report.get("missing_candidate_names", []),
                "report_json": str((module_report_dir / f"{module_dir}.json").resolve()),
                "report_csv": str((module_report_dir / f"{module_dir}.csv").resolve()),
            }
            module_summaries.append(module_summary)

            flat_rows.append(
                {
                    "family": family,
                    "module_dir": module_dir,
                    "total_candidates": report["total_candidates"],
                    "equivalent": report["counts"].get("equivalent", 0),
                    "not_equivalent": report["counts"].get("not_equivalent", 0),
                    "skip": report["counts"].get("skip", 0),
                    "tool_limited": report["counts"].get("tool_limited", 0),
                    "compatible": report["interface_counts"].get("compatible", 0),
                    "incompatible": report["interface_counts"].get("incompatible", 0),
                    "missing_candidates": report.get("missing_candidates", 0),
                }
            )

            for result in report["results"]:
                overall_formal[result["formal_status"]] += 1
                overall_interface[result["interface_status"]] += 1
                overall_reason_bucket[result.get("reason_bucket", "license_or_tool_error")] += 1
                family_formal[family][result["formal_status"]] += 1
                model_formal[result["model"]][result["formal_status"]] += 1

    observed_candidates = sum(
        int(module_summary.get("observed_candidates", module_summary["total_candidates"]))
        for module_summary in module_summaries
    )
    missing_candidates = sum(
        int(module_summary.get("missing_candidates", 0))
        for module_summary in module_summaries
    )
    missing_candidate_names = [
        {
            "module_dir": module_summary["module_dir"],
            "candidate_name": candidate_name,
        }
        for module_summary in sorted(module_summaries, key=lambda item: item["module_dir"])
        for candidate_name in module_summary.get("missing_candidate_names", [])
    ]

    summary = {
        "backend": args.backend,
        "model_filter": args.model,
        "double_root": str(args.double_root.resolve()),
        "double_pipeline_root": str(args.double_pipeline_root.resolve()),
        "or1200_root": str(args.or1200_root.resolve()),
        "i2c_root": str(args.i2c_root.resolve()),
        "mips_root": str(args.mips_root.resolve()),
        "cordic_root": str(args.cordic_root.resolve()),
        "result_root": str(args.result_root.resolve()),
        "excluded_modules": sorted(excludes),
        "depth": args.depth,
        "timeout": args.timeout,
        "jobs": jobs,
        "module_count": len(plan),
        "observed_candidates": observed_candidates,
        "missing_candidates": missing_candidates,
        "missing_candidate_names": missing_candidate_names,
        "module_summaries": module_summaries,
        "overall_formal_counts": dict(sorted(overall_formal.items())),
        "overall_interface_counts": dict(sorted(overall_interface.items())),
        "overall_reason_bucket_counts": dict(sorted(overall_reason_bucket.items())),
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
    write_suite_csv(args.summary_csv.resolve(), flat_rows)
    print(f"Suite summary written to {args.summary_json.resolve()}", flush=True)
    print(f"Suite CSV written to {args.summary_csv.resolve()}", flush=True)

    detail_csv = args.summary_csv.resolve().with_name("formal_equivalence_suite_detailed.csv")
    detail_json = args.summary_json.resolve().with_name("formal_equivalence_suite_detailed_summary.json")
    detail_rc, _, detail_logs = run_summarize_outputs(
        report_dir=module_report_dir,
        detail_csv=detail_csv,
        summary_json=detail_json,
        summary_md=detail_json.with_suffix(".md"),
    )
    if detail_logs:
        stream = sys.stderr if detail_rc != 0 else sys.stdout
        print("\n".join(detail_logs), file=stream, flush=True)
    if detail_rc != 0 and exit_code in {0, 1}:
        exit_code = detail_rc

    if exit_code not in {0, 1}:
        return exit_code
    return 0 if overall_formal.get("not_equivalent", 0) == 0 and overall_formal.get("skip", 0) == 0 and overall_formal.get("tool_limited", 0) == 0 else 1


def add_verify_parser(subparsers: argparse._SubParsersAction[argparse.ArgumentParser]) -> None:
    parser = subparsers.add_parser(
        "verify",
        description="Check compile success and formal equivalence for <name>.v and <name>_t*.v.",
    )
    parser.add_argument(
        "directory",
        nargs="?",
        default=REPO_ROOT / "test" / "verilog" / "fpu_add",
        type=Path,
    )
    parser.add_argument("--depth", type=int, default=12)
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--iverilog", default="iverilog")
    parser.add_argument("--yosys", default="yosys")
    parser.set_defaults(func=run_verify_command)


def run_verify_command(args: argparse.Namespace) -> int:
    iverilog = shutil.which(args.iverilog)
    yosys = shutil.which(args.yosys)
    if iverilog is None:
        print(f"Tool not found: {args.iverilog}")
        return 2
    if yosys is None:
        print(f"Tool not found: {args.yosys}")
        return 2

    directory = args.directory.resolve()
    reference_files = sorted(
        file for file in directory.glob("*.v") if TARGET_RE.match(file.stem) is None
    )
    if not reference_files:
        print(f"No reference Verilog files found in {directory}")
        return 2

    all_passed = True
    for reference_file in reference_files:
        candidate_files = sorted(
            directory.glob(f"{reference_file.stem}_t*.v"),
            key=lambda file: int(TARGET_RE.match(file.stem).group("index")),
        )
        if not candidate_files:
            continue

        ref_ok, ref_msg = compile_success(reference_file, iverilog, args.timeout)
        for candidate_file in candidate_files:
            cand_ok, cand_msg = compile_success(candidate_file, iverilog, args.timeout)
            compile_ok = ref_ok and cand_ok
            func_ok = False
            func_msg = "SKIP"

            if not cand_ok or not ref_ok:
                all_passed = False
                func_msg = "SKIP"
            else:
                eq_ok, eq_msg = legacy_equivalence_check(
                    reference_file,
                    candidate_file,
                    yosys,
                    args.depth,
                    args.timeout,
                )
                func_ok = eq_ok
                func_msg = eq_msg.splitlines()[0]
                if not eq_ok:
                    all_passed = False

            reason = func_msg if func_msg != "SKIP" else "compile failed, skip equivalence"
            print(
                f"sample {reference_file.stem}  "
                f"candidate {candidate_file.name}  "
                f"compile: {'PASS' if compile_ok else 'FAIL'}  "
                f"equivalence: {'PASS' if func_ok else ('SKIP' if func_msg == 'SKIP' else 'FAIL')}  "
                f"{reason}"
            )
            if not ref_ok and ref_msg:
                pass
            if not cand_ok and cand_msg:
                pass

    return 0 if all_passed else 1


def _selftest_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.strip() + "\n", encoding="utf-8")


class FormalEquivalenceSelfTests(unittest.TestCase):
    maxDiff = None

    @classmethod
    def setUpClass(cls) -> None:
        if shutil.which("yosys") is None:
            raise unittest.SkipTest("yosys is required for formal equivalence selftests")

    def run_checker(
        self,
        *,
        reference: Path,
        candidates_root: Path,
        module_dir: str,
        support_root: Path | None = None,
        model: str | None = None,
        alias_file: Path | None = None,
        timeout: int | None = None,
        expected_attempts: int | None = None,
    ) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
        with tempfile.TemporaryDirectory(prefix="checker_report_") as tempdir_name:
            tempdir = Path(tempdir_name)
            report_path = tempdir / "report.json"
            csv_path = tempdir / "report.csv"
            cmd = [
                sys.executable,
                str(SCRIPT_PATH),
                "check",
                "--reference",
                str(reference),
                "--candidates",
                str(candidates_root),
                "--module-dir",
                module_dir,
                "--report",
                str(report_path),
                "--csv-report",
                str(csv_path),
            ]
            if expected_attempts is not None:
                cmd.extend(["--expected-attempts", str(expected_attempts)])
            if support_root is not None:
                cmd.extend(["--support-root", str(support_root)])
            if model is not None:
                cmd.extend(["--model", model])
            if alias_file is not None:
                cmd.extend(["--interface-aliases", str(alias_file)])
            if timeout is not None:
                cmd.extend(["--timeout", str(timeout)])

            completed = subprocess.run(
                cmd,
                cwd=REPO_ROOT,
                text=True,
                capture_output=True,
                check=False,
            )
            if not report_path.exists():
                self.fail(
                    "checker did not produce a report\n"
                    f"stdout:\n{completed.stdout}\n"
                    f"stderr:\n{completed.stderr}"
                )
            return completed, json.loads(report_path.read_text(encoding="utf-8"))

    def run_compile_suite(
        self,
        *,
        result_root: Path,
        report_dir: Path,
        scope: str = "both",
        model: str | None = None,
        jobs: int = 1,
    ) -> subprocess.CompletedProcess[str]:
        cmd = [
            sys.executable,
            str(SCRIPT_PATH),
            "compile-suite",
            "--result-root",
            str(result_root),
            "--report-dir",
            str(report_dir),
            "--scope",
            scope,
            "--jobs",
            str(jobs),
        ]
        if model is not None:
            cmd.extend(["--model", model])
        return subprocess.run(
            cmd,
            cwd=REPO_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_resolve_compile_expected_top_for_mips_prefix(self) -> None:
        reference = REPO_ROOT / "Src" / "mips_16" / "des" / "EX_stage" / "EX_stage.v"
        expected_top, top_error = resolve_compile_expected_top("mips_EX_stage", reference)
        self.assertEqual(expected_top, "EX_stage")
        self.assertIsNone(top_error)

    def test_resolve_compile_expected_top_for_fpu_double_alias(self) -> None:
        reference = REPO_ROOT / "Src" / "double_fpu" / "des" / "verilog" / "fpu_double" / "fpu_double.v"
        expected_top, top_error = resolve_compile_expected_top("fpu_double", reference)
        self.assertEqual(expected_top, "fpu")
        self.assertIsNone(top_error)

    def test_resolve_compile_expected_top_for_multi_module_cordic(self) -> None:
        reference = REPO_ROOT / "Src" / "verilog_cordic_core" / "des" / "cordic" / "cordic.v"
        expected_top, top_error = resolve_compile_expected_top("cordic", reference)
        self.assertEqual(expected_top, "cordic")
        self.assertIsNone(top_error)

    def test_extract_tolerant_module_names_accepts_duplicate_instruction_mem(self) -> None:
        reference = REPO_ROOT / "Src" / "mips_16" / "des" / "instruction_mem" / "instruction_mem.v"
        names = extract_tolerant_module_names(reference)
        unique_names = extract_unique_tolerant_module_names(reference)
        self.assertEqual(names.count("instruction_mem"), 2)
        self.assertEqual(unique_names, ("instruction_mem",))

    def test_require_resolved_top_accepts_duplicate_instruction_mem(self) -> None:
        reference = REPO_ROOT / "Src" / "mips_16" / "des" / "instruction_mem" / "instruction_mem.v"
        self.assertEqual(
            require_resolved_top("mips_instruction_mem", reference, role="reference"),
            "instruction_mem",
        )

    def test_require_resolved_top_selects_named_cordic_module(self) -> None:
        reference = REPO_ROOT / "Src" / "verilog_cordic_core" / "des" / "cordic" / "cordic.v"
        self.assertEqual(
            require_resolved_top("cordic", reference, role="reference"),
            "cordic",
        )

    def test_build_cordic_candidate_source_injects_missing_default_defines(self) -> None:
        with tempfile.TemporaryDirectory(prefix="cordic_candidate_source_") as tempdir_name:
            candidate = Path(tempdir_name) / "cordic_t0.v"
            _selftest_write_text(
                candidate,
                """
                module cordic;
                endmodule
                """,
            )
            source = build_cordic_candidate_source(candidate)
            self.assertIn("`define XY_BITS 16", source)
            self.assertIn("`define CORDIC_1 17'd19896", source)
            self.assertIn("module cordic;", source)

    def test_rewrite_signed_shifter_module_text_replaces_dynamic_loop(self) -> None:
        rewritten, changed = rewrite_signed_shifter_module_text(
            """
            module signed_shifter (
              input wire [`ITERATION_BITS-1:0] i,
              input wire signed [`XY_BITS:0] D,
              output reg signed [`XY_BITS:0] Q );
              integer j;
              always @ * begin
                Q = D;
                for (j = 0; j < i; j = j + 1) begin
                  Q = {D[`XY_BITS], Q[`XY_BITS:1]};
                end
              end
            endmodule
            """
        )
        self.assertTrue(changed)
        self.assertIn("Q = $signed(D) >>> i;", rewritten)
        self.assertNotIn("for (j = 0; j < i; j = j + 1)", rewritten)

    def test_prepare_formal_friendly_candidate_file_rewrites_rotator_candidate(self) -> None:
        with tempfile.TemporaryDirectory(prefix="cordic_formal_candidate_") as tempdir_name:
            tempdir = Path(tempdir_name)
            candidate = tempdir / "rotator_t0.v"
            _selftest_write_text(
                candidate,
                """
                module signed_shifter (
                  input wire [`ITERATION_BITS-1:0] i,
                  input wire signed [`XY_BITS:0] D,
                  output reg signed [`XY_BITS:0] Q );
                  integer j;
                  always @ * begin
                    Q = D;
                    for (j = 0; j < i; j = j + 1) begin
                      Q = {D[`XY_BITS], Q[`XY_BITS:1]};
                    end
                  end
                endmodule
                module rotator;
                endmodule
                """,
            )
            rewritten, cleanup_root = prepare_formal_friendly_candidate_file("rotator", candidate)
            try:
                text = rewritten.read_text(encoding="utf-8")
                self.assertIn("Q = $signed(D) >>> i;", text)
                self.assertNotIn("j < i", text)
            finally:
                if cleanup_root is not None:
                    shutil.rmtree(cleanup_root, ignore_errors=True)

    def test_extract_cordic_testbench_failure_lines_detects_error_output(self) -> None:
        lines = extract_cordic_testbench_failure_lines(
            "Angle: 1 sin = 0.1 cos = 0.9        errors   123   456\n"
            "Angle: 2 sin = 0.2 cos = 0.8\n"
            "angle 0.1 computed 0.2  error 0.1\n"
        )
        self.assertEqual(
            lines,
            [
                "Angle: 1 sin = 0.1 cos = 0.9        errors   123   456",
                "angle 0.1 computed 0.2  error 0.1",
            ],
        )

    def test_filter_compile_support_files_skips_overlapping_modules(self) -> None:
        with tempfile.TemporaryDirectory(prefix="compile_support_filter_") as tempdir_name:
            tempdir = Path(tempdir_name)
            candidate_file = tempdir / "candidate.v"
            overlapping_support = tempdir / "overlap.v"
            helper_support = tempdir / "helper.v"
            _selftest_write_text(
                candidate_file,
                """
                module target;
                endmodule
                """,
            )
            _selftest_write_text(
                overlapping_support,
                """
                module target;
                endmodule
                module helper_a;
                endmodule
                """,
            )
            _selftest_write_text(
                helper_support,
                """
                module helper_b;
                endmodule
                """,
            )

            filtered = filter_compile_support_files(
                candidate_file,
                (overlapping_support, helper_support),
            )
            self.assertEqual(filtered, [helper_support])

    def test_compile_macro_defines_for_scope_injects_missing_cordic_defaults(self) -> None:
        with tempfile.TemporaryDirectory(prefix="compile_macro_defs_") as tempdir_name:
            tempdir = Path(tempdir_name)
            candidate_file = tempdir / "rotator_t0.v"
            _selftest_write_text(
                candidate_file,
                """
                module rotator (
                    input wire signed [`XY_BITS:0] x_i,
                    output wire signed [`XY_BITS:0] x_o
                );
                    assign x_o = x_i;
                endmodule
                """,
            )
            context = CompileModuleContext(
                family="verilog_cordic_core",
                module_dir="rotator",
                family_root=tempdir,
                reference_file=tempdir / "rotator.v",
                expected_top="rotator",
                top_error=None,
                support_context=None,
                prefix_files=tuple(),
                support_files=tuple(),
                search_roots=(tempdir,),
            )
            macro_defines = compile_macro_defines_for_scope(context, candidate_file, "with_support")
            self.assertIn(("XY_BITS", "16"), macro_defines)
            self.assertIn(("ROTATE", ""), macro_defines)

    def test_build_compile_error_excerpt_prefers_error_lines(self) -> None:
        output = "\n".join(
            [
                "foo.v:1: warning: macro XY_BITS undefined",
                "foo.v:2: warning: macro THETA_BITS undefined",
                "foo.v:9: syntax error",
                "foo.v:1: Errors in port declarations.",
            ]
        )
        self.assertEqual(
            build_compile_error_excerpt(output, ok=False),
            "foo.v:9: syntax error | foo.v:1: Errors in port declarations.",
        )

    def test_compile_suite_smoke_writes_three_csvs(self) -> None:
        with tempfile.TemporaryDirectory(prefix="compile_suite_smoke_") as tempdir_name:
            tempdir = Path(tempdir_name)
            result_root = tempdir / "results"
            candidate_file = result_root / "toy" / "mips_EX_stage" / "mips_EX_stage_t1.v"
            report_dir = tempdir / "reports"
            _selftest_write_text(
                candidate_file,
                """
                module EX_stage;
                endmodule
                """,
            )

            completed = self.run_compile_suite(
                result_root=result_root,
                report_dir=report_dir,
                jobs=1,
            )
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

            detail_path = report_dir / "compile_detail.csv"
            summary_by_module_path = report_dir / "compile_summary_by_model_module.csv"
            summary_by_model_path = report_dir / "compile_summary_by_model.csv"
            self.assertTrue(detail_path.exists())
            self.assertTrue(summary_by_module_path.exists())
            self.assertTrue(summary_by_model_path.exists())

            with detail_path.open(encoding="utf-8", newline="") as handle:
                detail_rows = list(csv.DictReader(handle))
            with summary_by_module_path.open(encoding="utf-8", newline="") as handle:
                module_rows = list(csv.DictReader(handle))
            with summary_by_model_path.open(encoding="utf-8", newline="") as handle:
                model_rows = list(csv.DictReader(handle))

            self.assertEqual(len(detail_rows), 2)
            self.assertEqual(len(module_rows), 1)
            self.assertEqual(len(model_rows), 1)
            self.assertEqual({row["scope"] for row in detail_rows}, {"standalone", "with_support"})
            self.assertTrue(all(row["status"] == "pass" for row in detail_rows))
            self.assertEqual(module_rows[0]["family"], "mips_16")
            self.assertEqual(module_rows[0]["model"], "toy")
            self.assertEqual(module_rows[0]["module_dir"], "mips_EX_stage")
            self.assertEqual(module_rows[0]["observed_candidates"], "1")
            self.assertEqual(module_rows[0]["standalone_pass"], "1")
            self.assertEqual(module_rows[0]["with_support_pass"], "1")
            self.assertIn("overall totals:", completed.stdout)
            self.assertIn("per-model totals:", completed.stdout)
            self.assertIn("missing modules:", completed.stdout)

    def test_build_include_dirs_prioritizes_support_workspace(self) -> None:
        reference = REPO_ROOT / "Src" / "or1200_hp" / "des" / "verilog" / "or1200_dc_ram"
        reference_file = discover_reference_file(reference)
        support_context = prepare_support_context(
            "or1200_dc_ram",
            reference_file.parent.parent.resolve(),
            reference_file,
        )
        try:
            candidate_file = (
                REPO_ROOT
                / "Result"
                / "claude"
                / "or1200_dc_ram"
                / "or1200_dc_ram_t5.v"
            ).resolve()
            gate_files = [
                *support_context.prefix_files,
                candidate_file,
                *support_context.support_files,
            ]
            include_dirs = build_include_dirs(
                files=gate_files,
                search_roots=dedupe_paths([REPO_ROOT, support_context.effective_support_root]),
                extra_include_dirs=[],
                support_context=support_context,
            )
            repo_support_dir = (REPO_ROOT / "Src" / "or1200_hp" / "des" / "verilog").resolve()
            self.assertEqual(include_dirs[0], support_context.effective_support_root)
            self.assertLess(
                include_dirs.index(support_context.effective_support_root),
                include_dirs.index(repo_support_dir),
            )
        finally:
            if support_context.cleanup_root is not None:
                shutil.rmtree(support_context.cleanup_root, ignore_errors=True)

    def test_prepare_support_context_injects_mips_prefix_shims(self) -> None:
        reference = REPO_ROOT / "Src" / "mips_16" / "des" / "IF_stage" / "IF_stage.v"
        support_context = prepare_support_context(
            "mips_IF_stage",
            reference.parent.parent.resolve(),
            reference,
        )
        try:
            self.assertEqual(len(support_context.prefix_files), 1)
            prefix_file = support_context.prefix_files[0]
            self.assertEqual(prefix_file.name, "mips_16_defs.v")
            for shim_name in MIPS_PREFIX_SHIM_NAMES:
                self.assertTrue(
                    (support_context.effective_support_root / shim_name).exists(),
                    msg=f"Missing shim {shim_name}",
                )
        finally:
            if support_context.cleanup_root is not None:
                shutil.rmtree(support_context.cleanup_root, ignore_errors=True)

    def test_mips_prefix_injection_allows_missing_defs_include_candidate(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mips_prefix_injection_") as tempdir_name:
            tempdir = Path(tempdir_name)
            reference_file = tempdir / "refs" / "IF_stage" / "IF_stage.v"
            defs_file = tempdir / "refs" / "mips_16_defs.v"
            candidate_file = tempdir / "results" / "toy" / "mips_IF_stage" / "mips_IF_stage_t1.v"
            instruction_mem_file = tempdir / "refs" / "instruction_mem" / "instruction_mem.v"

            _selftest_write_text(
                defs_file,
                """
                `define PC_WIDTH 8
                """,
            )
            _selftest_write_text(
                reference_file,
                """
                `include "mips_16_defs.v"
                module IF_stage(
                    input clk,
                    input rst,
                    input instruction_fetch_en,
                    input [5:0] branch_offset_imm,
                    input branch_taken,
                    output reg [`PC_WIDTH-1:0] pc,
                    output [15:0] instruction
                );
                    instruction_mem imem(.clk(clk), .pc(pc), .instruction(instruction));
                    always @(posedge clk or posedge rst) begin
                        if (rst) pc <= 0;
                        else if (instruction_fetch_en) pc <= pc + 1'b1;
                    end
                endmodule
                """,
            )
            _selftest_write_text(
                instruction_mem_file,
                """
                `include "mips_16_defs.v"
                module instruction_mem(
                    input clk,
                    input [`PC_WIDTH-1:0] pc,
                    output [15:0] instruction
                );
                    assign instruction = 16'h0000;
                endmodule
                """,
            )
            _selftest_write_text(
                candidate_file,
                """
                module IF_stage(
                    input clk,
                    input rst,
                    input instruction_fetch_en,
                    input [5:0] branch_offset_imm,
                    input branch_taken,
                    output reg [`PC_WIDTH-1:0] pc,
                    output [15:0] instruction
                );
                    instruction_mem imem(.clk(clk), .pc(pc), .instruction(instruction));
                    always @(posedge clk or posedge rst) begin
                        if (rst) pc <= 0;
                        else if (instruction_fetch_en) pc <= pc + 1'b1;
                    end
                endmodule
                """,
            )

            completed, payload = self.run_checker(
                reference=reference_file,
                candidates_root=tempdir / "results",
                module_dir="mips_IF_stage",
                support_root=tempdir / "refs",
                model="toy",
            )
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            result = payload["results"][0]
            self.assertEqual(result["candidate_precheck"], "pass")
            self.assertEqual(result["formal_status"], "equivalent")

    def test_i2c_prefix_injection_allows_missing_defs_include_candidate(self) -> None:
        with tempfile.TemporaryDirectory(prefix="i2c_prefix_injection_") as tempdir_name:
            tempdir = Path(tempdir_name)
            support_root = tempdir / "refs"
            reference_file = support_root / "i2c_master_top" / "i2c_master_top.v"
            defs_file = support_root / "i2c_master_defines.v"
            timescale_file = support_root / "timescale.v"
            bit_ctrl_file = support_root / "i2c_master_bit_ctrl" / "i2c_master_bit_ctrl.v"
            byte_ctrl_file = support_root / "i2c_master_byte_ctrl" / "i2c_master_byte_ctrl.v"
            candidate_file = tempdir / "results" / "toy" / "i2c_master_top" / "i2c_master_top_t1.v"

            _selftest_write_text(timescale_file, "`timescale 1ns/1ps\n")
            _selftest_write_text(defs_file, "`define I2C_DEF 1\n")
            _selftest_write_text(
                bit_ctrl_file,
                """
                module i2c_master_bit_ctrl(
                    input clk,
                    output done
                );
                    assign done = clk;
                endmodule
                """,
            )
            _selftest_write_text(
                byte_ctrl_file,
                """
                module i2c_master_byte_ctrl(
                    input clk,
                    output done
                );
                    i2c_master_bit_ctrl u_bit(.clk(clk), .done(done));
                endmodule
                """,
            )
            _selftest_write_text(
                reference_file,
                """
                `include "timescale.v"
                `include "i2c_master_defines.v"
                module i2c_master_top(
                    input clk,
                    output done
                );
                    i2c_master_byte_ctrl u_byte(.clk(clk), .done(done));
                endmodule
                """,
            )
            _selftest_write_text(
                candidate_file,
                """
                module i2c_master_top(
                    input clk,
                    output done
                );
                    i2c_master_byte_ctrl u_byte(.clk(clk), .done(done));
                endmodule
                """,
            )

            completed, payload = self.run_checker(
                reference=reference_file,
                candidates_root=tempdir / "results",
                module_dir="i2c_master_top",
                support_root=support_root,
                model="toy",
            )
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            result = payload["results"][0]
            self.assertEqual(result["candidate_precheck"], "pass")
            self.assertEqual(result["formal_status"], "equivalent")

    def test_build_interface_normalization_script_uses_lib_support_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="iface_script_") as tempdir_name:
            tempdir = Path(tempdir_name)
            top_file = tempdir / "top.v"
            lib_file = tempdir / "lib.v"
            include_dir = tempdir / "include"
            json_path = tempdir / "design.json"
            script = build_interface_normalization_script(
                files=[top_file],
                include_dirs=[include_dir],
                top="top",
                json_path=json_path,
                library_files=[lib_file],
            )

            lines = script.splitlines()
            self.assertGreaterEqual(len(lines), 4)
            self.assertIn("read_verilog -sv ", lines[0])
            self.assertIn("read_verilog -sv -lib ", lines[1])
            self.assertNotIn("proc; memory; opt", script)
            self.assertIn(f"write_json {json_path.as_posix()}", script)

    def test_width_normalization_accepts_equivalent_width_expressions(self) -> None:
        with tempfile.TemporaryDirectory(prefix="width_norm_") as tempdir_name:
            tempdir = Path(tempdir_name)
            reference_file = tempdir / "refs" / "width_norm" / "width_norm.v"
            candidate_file = tempdir / "results" / "toy" / "width_norm" / "width_norm_t1.v"
            _selftest_write_text(
                reference_file.with_name("defs.vh"),
                """
                `define DATA_WIDTH 32
                """,
            )
            _selftest_write_text(
                reference_file,
                """
                `include "defs.vh"
                module width_norm #(parameter width = `DATA_WIDTH)(
                    input [width-1:0] a,
                    output [width-1:0] y
                );
                    assign y = a;
                endmodule
                """,
            )
            _selftest_write_text(
                candidate_file,
                """
                module width_norm(
                    input [31:0] a,
                    output [31:0] y
                );
                    assign y = a;
                endmodule
                """,
            )

            completed, payload = self.run_checker(
                reference=reference_file,
                candidates_root=tempdir / "results",
                module_dir="width_norm",
                support_root=tempdir / "refs",
                model="toy",
            )
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            result = payload["results"][0]
            self.assertEqual(result["interface_status"], "compatible")
            self.assertEqual(result["formal_status"], "equivalent")
            self.assertEqual(result["interface_reason_kind"], "width_equivalent")

    def test_port_order_only_no_longer_blocks_formal(self) -> None:
        with tempfile.TemporaryDirectory(prefix="order_norm_") as tempdir_name:
            tempdir = Path(tempdir_name)
            reference_file = tempdir / "refs" / "order_norm" / "order_norm.v"
            candidate_file = tempdir / "results" / "toy" / "order_norm" / "order_norm_t1.v"
            _selftest_write_text(
                reference_file,
                """
                module order_norm(
                    input a,
                    input b,
                    output y
                );
                    assign y = a ^ b;
                endmodule
                """,
            )
            _selftest_write_text(
                candidate_file,
                """
                module order_norm(
                    input b,
                    input a,
                    output y
                );
                    assign y = a ^ b;
                endmodule
                """,
            )

            completed, payload = self.run_checker(
                reference=reference_file,
                candidates_root=tempdir / "results",
                module_dir="order_norm",
                support_root=tempdir / "refs",
                model="toy",
            )
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            result = payload["results"][0]
            self.assertEqual(result["interface_status"], "compatible")
            self.assertEqual(result["formal_status"], "equivalent")
            self.assertEqual(result["interface_reason_kind"], "port_order_only")

    def test_explicit_alias_can_enter_formal(self) -> None:
        with tempfile.TemporaryDirectory(prefix="alias_norm_") as tempdir_name:
            tempdir = Path(tempdir_name)
            reference_file = tempdir / "refs" / "alias_norm" / "alias_norm.v"
            candidate_file = tempdir / "results" / "toy" / "alias_norm" / "alias_norm_t1.v"
            alias_file = tempdir / "aliases.json"
            _selftest_write_text(
                reference_file,
                """
                module alias_norm(
                    input [7:0] a,
                    output [7:0] out
                );
                    assign out = a;
                endmodule
                """,
            )
            _selftest_write_text(
                candidate_file,
                """
                module alias_norm(
                    input [7:0] a,
                    output [7:0] result
                );
                    assign result = a;
                endmodule
                """,
            )
            alias_file.write_text(
                json.dumps(
                    {
                        "global": {},
                        "modules": {"alias_norm": {"out": "result"}},
                    },
                    indent=2,
                ),
                encoding="utf-8",
            )

            completed, payload = self.run_checker(
                reference=reference_file,
                candidates_root=tempdir / "results",
                module_dir="alias_norm",
                support_root=tempdir / "refs",
                model="toy",
                alias_file=alias_file,
            )
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            result = payload["results"][0]
            self.assertEqual(result["interface_status"], "compatible")
            self.assertEqual(result["formal_status"], "equivalent")
            self.assertEqual(result["interface_reason_kind"], "alias_applied")
            self.assertEqual(
                result["interface_aliases_applied"],
                [{"reference_port": "out", "candidate_port": "result"}],
            )

    def test_alias_conflict_stays_interface_mismatch(self) -> None:
        with tempfile.TemporaryDirectory(prefix="alias_conflict_") as tempdir_name:
            tempdir = Path(tempdir_name)
            reference_file = tempdir / "refs" / "alias_conflict" / "alias_conflict.v"
            candidate_file = (
                tempdir / "results" / "toy" / "alias_conflict" / "alias_conflict_t1.v"
            )
            alias_file = tempdir / "aliases.json"
            _selftest_write_text(
                reference_file,
                """
                module alias_conflict(
                    input a,
                    output out0,
                    output out1
                );
                    assign out0 = a;
                    assign out1 = a;
                endmodule
                """,
            )
            _selftest_write_text(
                candidate_file,
                """
                module alias_conflict(
                    input a,
                    output result
                );
                    assign result = a;
                endmodule
                """,
            )
            alias_file.write_text(
                json.dumps(
                    {
                        "global": {},
                        "modules": {
                            "alias_conflict": {
                                "out0": "result",
                                "out1": "result",
                            }
                        },
                    },
                    indent=2,
                ),
                encoding="utf-8",
            )

            completed, payload = self.run_checker(
                reference=reference_file,
                candidates_root=tempdir / "results",
                module_dir="alias_conflict",
                support_root=tempdir / "refs",
                model="toy",
                alias_file=alias_file,
            )
            self.assertNotEqual(completed.returncode, 0)
            result = payload["results"][0]
            self.assertEqual(result["interface_status"], "incompatible")
            self.assertEqual(result["formal_status"], "skip")
            self.assertEqual(result["reason_bucket"], "interface_mismatch")
            self.assertEqual(result["interface_reason_kind"], "alias_conflict")

    def test_real_smoke_fpu_add_t4_reports_not_equivalent(self) -> None:
        with tempfile.TemporaryDirectory(prefix="real_fpu_add_") as tempdir_name:
            tempdir = Path(tempdir_name)
            candidate_target = tempdir / "results" / "codex" / "fpu_add" / "fpu_add_t4.v"
            candidate_target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(
                REPO_ROOT / "Result" / "codex" / "fpu_add" / "fpu_add_t4.v",
                candidate_target,
            )

            completed, payload = self.run_checker(
                reference=REPO_ROOT / "Src" / "double_fpu" / "des" / "verilog" / "fpu_add",
                candidates_root=tempdir / "results",
                module_dir="fpu_add",
                model="codex",
            )
            self.assertNotEqual(completed.returncode, 0)
            result = payload["results"][0]
            self.assertEqual(result["interface_status"], "compatible")
            self.assertEqual(result["formal_status"], "not_equivalent")
            self.assertEqual(result["reason_bucket"], "not_equivalent")

    def test_real_smoke_or1200_alu_t1_no_longer_skips_on_width_text(self) -> None:
        with tempfile.TemporaryDirectory(prefix="real_or1200_alu_") as tempdir_name:
            tempdir = Path(tempdir_name)
            candidate_target = (
                tempdir / "results" / "codex" / "or1200_alu" / "or1200_alu_t1.v"
            )
            candidate_target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(
                REPO_ROOT / "Result" / "codex" / "or1200_alu" / "or1200_alu_t1.v",
                candidate_target,
            )

            completed, payload = self.run_checker(
                reference=REPO_ROOT / "Src" / "or1200_hp" / "des" / "verilog" / "or1200_alu",
                candidates_root=tempdir / "results",
                module_dir="or1200_alu",
                model="codex",
            )
            self.assertNotEqual(completed.returncode, 0)
            result = payload["results"][0]
            self.assertEqual(result["interface_status"], "compatible")
            self.assertNotEqual(result["formal_status"], "skip")
            self.assertEqual(result["interface_reason_kind"], "width_equivalent")

    def test_real_smoke_or1200_cfgr_t1_matches_exact_interface(self) -> None:
        with tempfile.TemporaryDirectory(prefix="real_or1200_cfgr_") as tempdir_name:
            tempdir = Path(tempdir_name)
            candidate_target = tempdir / "results" / "claude" / "or1200_cfgr" / "or1200_cfgr_t1.v"
            candidate_target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(
                REPO_ROOT / "Result" / "claude" / "or1200_cfgr" / "or1200_cfgr_t1.v",
                candidate_target,
            )

            completed, payload = self.run_checker(
                reference=REPO_ROOT / "Src" / "or1200_hp" / "des" / "verilog" / "or1200_cfgr",
                candidates_root=tempdir / "results",
                module_dir="or1200_cfgr",
                model="claude",
            )
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            result = payload["results"][0]
            self.assertEqual(result["interface_status"], "compatible")
            self.assertEqual(result["formal_status"], "equivalent")
            self.assertEqual(result["interface_reason_kind"], "exact_match")
            self.assertEqual(result["interface_aliases_applied"], [])

    def test_real_smoke_or1200_dc_ram_t1_reaches_equivalent_with_proof_abstraction(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory(prefix="real_or1200_dc_ram_t1_") as tempdir_name:
            tempdir = Path(tempdir_name)
            candidate_target = (
                tempdir / "results" / "claude" / "or1200_dc_ram" / "or1200_dc_ram_t1.v"
            )
            candidate_target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(
                REPO_ROOT / "Result" / "claude" / "or1200_dc_ram" / "or1200_dc_ram_t1.v",
                candidate_target,
            )

            completed, payload = self.run_checker(
                reference=REPO_ROOT / "Src" / "or1200_hp" / "des" / "verilog" / "or1200_dc_ram",
                candidates_root=tempdir / "results",
                module_dir="or1200_dc_ram",
                model="claude",
                timeout=20,
            )
            result = payload["results"][0]
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            self.assertEqual(result["reference_precheck"], "pass")
            self.assertEqual(result["candidate_precheck"], "pass")
            self.assertEqual(result["interface_status"], "compatible")
            self.assertEqual(result["formal_status"], "equivalent")
            self.assertEqual(result["reason_bucket"], "equivalent")

    def test_real_smoke_or1200_dc_ram_t3_reaches_equivalent_with_proof_abstraction(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory(prefix="real_or1200_dc_ram_t3_") as tempdir_name:
            tempdir = Path(tempdir_name)
            candidate_target = (
                tempdir / "results" / "deepseek" / "or1200_dc_ram" / "or1200_dc_ram_t3.v"
            )
            candidate_target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(
                REPO_ROOT / "Result" / "deepseek" / "or1200_dc_ram" / "or1200_dc_ram_t3.v",
                candidate_target,
            )

            completed, payload = self.run_checker(
                reference=REPO_ROOT / "Src" / "or1200_hp" / "des" / "verilog" / "or1200_dc_ram",
                candidates_root=tempdir / "results",
                module_dir="or1200_dc_ram",
                model="deepseek",
                timeout=20,
            )
            result = payload["results"][0]
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            self.assertEqual(result["reference_precheck"], "pass")
            self.assertEqual(result["candidate_precheck"], "pass")
            self.assertEqual(result["interface_status"], "compatible")
            self.assertEqual(result["formal_status"], "equivalent")
            self.assertEqual(result["reason_bucket"], "equivalent")

    def test_summarize_generates_detail_outputs(self) -> None:
        with tempfile.TemporaryDirectory(prefix="formal_summary_") as tempdir_name:
            tempdir = Path(tempdir_name)
            report_dir = tempdir / "reports"
            detail_csv = tempdir / "detail.csv"
            summary_json = tempdir / "detail_summary.json"
            summary_md = tempdir / "detail_summary.md"
            report_dir.mkdir(parents=True, exist_ok=True)
            (report_dir / "toy_mod.json").write_text(
                json.dumps(
                    {
                        "backend": "yosys",
                        "module_dir": "toy_mod",
                        "model_filter": "toy",
                        "candidate_expectation_mode": "fixed_attempts",
                        "expected_attempts": 2,
                        "results": [
                            {
                                "model": "toy",
                                "candidate_file": "/tmp/toy_mod_t1.v",
                                "reference_file": "/tmp/toy_mod.v",
                                "reference_top": "toy_mod",
                                "candidate_top": "toy_mod",
                                "reference_precheck": "pass",
                                "candidate_precheck": "pass",
                                "interface_status": "compatible",
                                "formal_status": "equivalent",
                                "proof_type": "strict_comb",
                                "reason_bucket": "equivalent",
                                "reason": "Strict combinational proof passed",
                                "interface_reason_kind": "exact_match",
                                "interface_reason": "normalized interface matches exactly",
                                "interface_aliases_applied": [],
                                "counterexample_summary": "",
                            }
                        ],
                        "missing_candidate_names": ["toy_mod_t2.v"],
                    },
                    indent=2,
                ),
                encoding="utf-8",
            )

            completed = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "summarize",
                    "--report-dir",
                    str(report_dir),
                    "--detail-csv",
                    str(detail_csv),
                    "--summary-json",
                    str(summary_json),
                    "--summary-md",
                    str(summary_md),
                ],
                cwd=REPO_ROOT,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            self.assertTrue(detail_csv.exists())
            self.assertTrue(summary_json.exists())
            self.assertTrue(summary_md.exists())

            summary = json.loads(summary_json.read_text(encoding="utf-8"))
            self.assertEqual(summary["observed_candidates"], 1)
            self.assertEqual(summary["missing_candidates"], 1)
            self.assertEqual(summary["overall_formal_counts"]["equivalent"], 1)

    def test_summarize_ignores_legacy_missing_candidates_without_expectation_mode(self) -> None:
        with tempfile.TemporaryDirectory(prefix="formal_summary_legacy_") as tempdir_name:
            tempdir = Path(tempdir_name)
            report_dir = tempdir / "reports"
            detail_csv = tempdir / "detail.csv"
            summary_json = tempdir / "detail_summary.json"
            summary_md = tempdir / "detail_summary.md"
            report_dir.mkdir(parents=True, exist_ok=True)
            (report_dir / "toy_mod.json").write_text(
                json.dumps(
                    {
                        "backend": "yosys",
                        "module_dir": "toy_mod",
                        "model_filter": "toy",
                        "results": [
                            {
                                "model": "toy",
                                "candidate_file": "/tmp/toy_mod_t1.v",
                                "reference_file": "/tmp/toy_mod.v",
                                "reference_top": "toy_mod",
                                "candidate_top": "toy_mod",
                                "reference_precheck": "pass",
                                "candidate_precheck": "pass",
                                "interface_status": "compatible",
                                "formal_status": "equivalent",
                                "proof_type": "strict_comb",
                                "reason_bucket": "equivalent",
                                "reason": "Strict combinational proof passed",
                                "interface_reason_kind": "exact_match",
                                "interface_reason": "normalized interface matches exactly",
                                "interface_aliases_applied": [],
                                "counterexample_summary": "",
                            }
                        ],
                        "missing_candidate_names": ["toy_mod_t0.v", "toy_mod_t6.v", "toy_mod_t7.v"],
                    },
                    indent=2,
                ),
                encoding="utf-8",
            )

            completed = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "summarize",
                    "--report-dir",
                    str(report_dir),
                    "--detail-csv",
                    str(detail_csv),
                    "--summary-json",
                    str(summary_json),
                    "--summary-md",
                    str(summary_md),
                ],
                cwd=REPO_ROOT,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            summary = json.loads(summary_json.read_text(encoding="utf-8"))
            self.assertEqual(summary["missing_candidates"], 0)
            self.assertEqual(summary["missing_candidate_rows"], [])
            self.assertNotIn("## Missing Candidates", summary_md.read_text(encoding="utf-8"))

    def test_expected_candidate_names_start_from_one(self) -> None:
        self.assertEqual(
            expected_candidate_names("toy_mod", 3),
            ["toy_mod_t1.v", "toy_mod_t2.v", "toy_mod_t3.v"],
        )

    def test_checker_auto_discovers_candidate_names(self) -> None:
        with tempfile.TemporaryDirectory(prefix="formal_checker_auto_") as tempdir_name:
            tempdir = Path(tempdir_name)
            reference = tempdir / "toy_mod" / "toy_mod.v"
            candidate = tempdir / "results" / "toy" / "toy_mod" / "toy_mod_t1.v"
            _selftest_write_text(
                reference,
                """
                module toy_mod(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )
            _selftest_write_text(
                candidate,
                """
                module toy_mod(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )

            completed, payload = self.run_checker(
                reference=reference.parent,
                candidates_root=tempdir / "results",
                module_dir="toy_mod",
                model="toy",
                timeout=20,
            )

            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            self.assertEqual(payload["candidate_expectation_mode"], "auto")
            self.assertEqual(payload["observed_candidate_names"], ["toy_mod_t1.v"])
            self.assertEqual(payload["expected_candidate_names"], ["toy_mod_t1.v"])
            self.assertEqual(payload["missing_candidate_names"], [])
            self.assertEqual(payload["missing_candidates"], 0)

    def test_checker_fixed_expected_attempts_are_one_based(self) -> None:
        with tempfile.TemporaryDirectory(prefix="formal_checker_fixed_") as tempdir_name:
            tempdir = Path(tempdir_name)
            reference = tempdir / "toy_mod" / "toy_mod.v"
            candidate = tempdir / "results" / "toy" / "toy_mod" / "toy_mod_t1.v"
            _selftest_write_text(
                reference,
                """
                module toy_mod(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )
            _selftest_write_text(
                candidate,
                """
                module toy_mod(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )

            completed, payload = self.run_checker(
                reference=reference.parent,
                candidates_root=tempdir / "results",
                module_dir="toy_mod",
                model="toy",
                timeout=20,
                expected_attempts=3,
            )

            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            self.assertEqual(payload["candidate_expectation_mode"], "fixed_attempts")
            self.assertEqual(
                payload["expected_candidate_names"],
                ["toy_mod_t1.v", "toy_mod_t2.v", "toy_mod_t3.v"],
            )
            self.assertEqual(payload["missing_candidate_names"], ["toy_mod_t2.v", "toy_mod_t3.v"])
            self.assertEqual(payload["missing_candidates"], 2)

    def test_suite_smoke_generates_reports_without_other_python_scripts(self) -> None:
        with tempfile.TemporaryDirectory(prefix="formal_suite_") as tempdir_name:
            tempdir = Path(tempdir_name)
            double_root = tempdir / "double"
            double_pipeline_root = tempdir / "double_pipeline"
            or1200_root = tempdir / "or1200"
            i2c_root = tempdir / "i2c"
            mips_root = tempdir / "mips"
            cordic_root = tempdir / "cordic"
            result_root = tempdir / "results"
            reference_file = double_root / "width_norm" / "width_norm.v"
            candidate_file = result_root / "toy" / "width_norm" / "width_norm_t0.v"
            report_dir = tempdir / "suite_reports"
            summary_json = tempdir / "suite_summary.json"
            summary_csv = tempdir / "suite_summary.csv"

            _selftest_write_text(
                reference_file,
                """
                module width_norm(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )
            _selftest_write_text(
                candidate_file,
                """
                module width_norm(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )
            or1200_root.mkdir(parents=True, exist_ok=True)
            double_pipeline_root.mkdir(parents=True, exist_ok=True)
            i2c_root.mkdir(parents=True, exist_ok=True)
            mips_root.mkdir(parents=True, exist_ok=True)
            cordic_root.mkdir(parents=True, exist_ok=True)

            completed = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "suite",
                    "--double-root",
                    str(double_root),
                    "--double-pipeline-root",
                    str(double_pipeline_root),
                    "--or1200-root",
                    str(or1200_root),
                    "--i2c-root",
                    str(i2c_root),
                    "--mips-root",
                    str(mips_root),
                    "--cordic-root",
                    str(cordic_root),
                    "--result-root",
                    str(result_root),
                    "--model",
                    "toy",
                    "--jobs",
                    "1",
                    "--report-dir",
                    str(report_dir),
                    "--summary-json",
                    str(summary_json),
                    "--summary-csv",
                    str(summary_csv),
                ],
                cwd=REPO_ROOT,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            self.assertTrue((report_dir / "width_norm.json").exists())
            self.assertTrue((report_dir / "width_norm.csv").exists())
            self.assertTrue(summary_json.exists())
            self.assertTrue(summary_csv.exists())
            self.assertTrue(
                (tempdir / "formal_equivalence_suite_detailed.csv").exists()
                or summary_csv.with_name("formal_equivalence_suite_detailed.csv").exists()
            )
            self.assertTrue(
                summary_json.with_name("formal_equivalence_suite_detailed_summary.json").exists()
            )
            self.assertTrue(
                summary_json.with_name("formal_equivalence_suite_detailed_summary.md").exists()
            )

            suite_summary = json.loads(summary_json.read_text(encoding="utf-8"))
            self.assertEqual(suite_summary["module_count"], 1)
            self.assertEqual(suite_summary["missing_candidates"], 0)
            self.assertEqual(suite_summary["overall_formal_counts"]["equivalent"], 1)

    def test_suite_includes_i2c_mips_cordic_and_pipeline_modules(self) -> None:
        with tempfile.TemporaryDirectory(prefix="formal_suite_families_") as tempdir_name:
            tempdir = Path(tempdir_name)
            double_root = tempdir / "double"
            double_pipeline_root = tempdir / "double_pipeline"
            or1200_root = tempdir / "or1200"
            i2c_root = tempdir / "i2c"
            mips_root = tempdir / "mips"
            cordic_root = tempdir / "cordic"
            result_root = tempdir / "results"
            report_dir = tempdir / "suite_reports"
            summary_json = tempdir / "suite_summary.json"
            summary_csv = tempdir / "suite_summary.csv"

            _selftest_write_text(
                double_pipeline_root / "fpu_mul_pipeline" / "fpu_mul_pipeline.v",
                """
                module fpu_mul(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )
            _selftest_write_text(
                result_root / "toy" / "fpu_mul_pipeline" / "fpu_mul_pipeline_t0.v",
                """
                module fpu_mul(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )
            _selftest_write_text(
                i2c_root / "i2c_master_top" / "i2c_master_top.v",
                """
                module i2c_master_top(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )
            _selftest_write_text(
                result_root / "toy" / "i2c_master_top" / "i2c_master_top_t0.v",
                """
                module i2c_master_top(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )
            _selftest_write_text(
                mips_root / "EX_stage" / "EX_stage.v",
                """
                module EX_stage(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )
            _selftest_write_text(
                result_root / "toy" / "mips_EX_stage" / "mips_EX_stage_t0.v",
                """
                module EX_stage(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )
            _selftest_write_text(
                cordic_root / "cordic" / "cordic.v",
                """
                module cordic(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )
            _selftest_write_text(
                result_root / "toy" / "cordic" / "cordic_t0.v",
                """
                module cordic(
                    input a,
                    output y
                );
                    assign y = a;
                endmodule
                """,
            )

            double_root.mkdir(parents=True, exist_ok=True)
            or1200_root.mkdir(parents=True, exist_ok=True)

            completed = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "suite",
                    "--double-root",
                    str(double_root),
                    "--double-pipeline-root",
                    str(double_pipeline_root),
                    "--or1200-root",
                    str(or1200_root),
                    "--i2c-root",
                    str(i2c_root),
                    "--mips-root",
                    str(mips_root),
                    "--cordic-root",
                    str(cordic_root),
                    "--result-root",
                    str(result_root),
                    "--model",
                    "toy",
                    "--jobs",
                    "1",
                    "--report-dir",
                    str(report_dir),
                    "--summary-json",
                    str(summary_json),
                    "--summary-csv",
                    str(summary_csv),
                ],
                cwd=REPO_ROOT,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertIn(completed.returncode, {0, 1}, completed.stdout + completed.stderr)
            for filename in ["fpu_mul_pipeline.json", "i2c_master_top.json", "mips_EX_stage.json", "cordic.json"]:
                self.assertTrue((report_dir / filename).exists(), filename)

            suite_summary = json.loads(summary_json.read_text(encoding="utf-8"))
            self.assertEqual(suite_summary["module_count"], 4)
            self.assertEqual(suite_summary["observed_candidates"], 4)
            self.assertEqual(suite_summary["overall_formal_counts"]["equivalent"], 3)
            cordic_report = json.loads((report_dir / "cordic.json").read_text(encoding="utf-8"))
            self.assertEqual(
                cordic_report["reference_file"],
                str(CORDIC_TESTBENCH_PATH.resolve()),
            )
            self.assertEqual(cordic_report["simulation_testbench"], str(CORDIC_TESTBENCH_PATH.resolve()))


def add_selftest_parser(subparsers: argparse._SubParsersAction[argparse.ArgumentParser]) -> None:
    parser = subparsers.add_parser(
        "selftest",
        description="Run the formal equivalence script's embedded unittest suite.",
    )
    parser.set_defaults(func=run_selftest_command)


def run_selftest_command(args: argparse.Namespace) -> int:
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(FormalEquivalenceSelfTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    return 0 if result.wasSuccessful() else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Unified formal equivalence toolkit.")
    subparsers = parser.add_subparsers(dest="command", required=True)
    add_compile_suite_parser(subparsers)
    add_check_parser(subparsers)
    add_suite_parser(subparsers)
    add_summarize_parser(subparsers)
    add_verify_parser(subparsers)
    add_selftest_parser(subparsers)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
