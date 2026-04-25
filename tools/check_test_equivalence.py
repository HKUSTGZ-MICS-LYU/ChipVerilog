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
import time
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


FINAL_PASS_STATUSES = {"pass_strict", "pass_bounded"}
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


@dataclass(frozen=True)
class ModuleInfo:
    name: str
    ports: tuple[str, ...]
    has_edge_triggered_logic: bool
    dependencies: tuple[str, ...]


@dataclass(frozen=True)
class Sample:
    family: str
    module_dir: str
    candidate_file: Path
    variant: str
    reference_file: Path
    reference_top: str
    candidate_top: str
    candidate_has_rst: bool


@dataclass
class SampleResult:
    family: str
    module_dir: str
    candidate_file: str
    variant: str
    reference_file: str
    reference_top: str
    candidate_top: str
    proof_type: str
    precheck_status: str
    equivalence_status: str
    reason: str
    used_temp_ref_repair: bool
    used_temp_primitive_models: bool
    elapsed_sec: float


def strip_comments(text: str) -> str:
    text = BLOCK_COMMENT_RE.sub("", text)
    return LINE_COMMENT_RE.sub("", text)


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


def infer_variant(path: Path) -> str:
    name = path.name.lower()
    if "generated_from_original" in name:
        return "from_original"
    if "generated_from_revised" in name:
        return "from_revised"
    return "generated"


def discover_samples(
    test_root: Path, double_ref_root: Path, or1200_ref_root: Path
) -> list[Sample]:
    samples: list[Sample] = []
    for candidate in sorted(test_root.rglob("*.v")):
        rel = candidate.relative_to(test_root)
        if len(rel.parts) < 3:
            continue

        family = rel.parts[0]
        module_dir = rel.parts[1]
        if family == "fpu":
            reference_file = double_ref_root / f"{module_dir}.v"
        elif family == "or1200":
            reference_file = or1200_ref_root / f"{module_dir}.v"
        else:
            continue

        if not reference_file.exists():
            raise FileNotFoundError(f"Missing reference file for {candidate}: {reference_file}")

        candidate_info = extract_module_info(candidate)
        reference_info = extract_module_info(reference_file)
        samples.append(
            Sample(
                family=family,
                module_dir=module_dir,
                candidate_file=candidate,
                variant=infer_variant(candidate),
                reference_file=reference_file,
                reference_top=reference_info.name,
                candidate_top=candidate_info.name,
                candidate_has_rst="rst" in candidate_info.ports,
            )
        )

    return samples


def ys_quote(value: str | Path) -> str:
    text = str(value).replace("\\", "/")
    return '"' + text.replace('"', '\\"') + '"'


def format_read_verilog(files: list[Path], include_dirs: list[Path]) -> str:
    includes = " ".join(f"-I{Path(path).as_posix()}" for path in include_dirs)
    file_args = " ".join(ys_quote(path) for path in files)
    return f"read_verilog -sv {includes} {file_args}".strip()


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


def run_yosys_script(yosys: str, script: str, timeout: int) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="yosys_batch_equiv_") as tempdir:
        script_path = Path(tempdir) / "run.ys"
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
            return False, f"Timeout after {timeout}s"

    output = clean_output((result.stdout or "") + (result.stderr or ""))
    return result.returncode == 0, output


def build_precheck_script(files: list[Path], include_dirs: list[Path], top: str) -> str:
    return "\n".join(
        [
            format_read_verilog(files, include_dirs),
            f"hierarchy -check -top {top}",
            "",
        ]
    )


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

    gate_lines = [
        format_read_verilog(gate_files, gate_includes),
        f"hierarchy -check -top {candidate_top}",
    ]
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
    if old_ctrl not in ctrl_text:
        raise ValueError("Failed to patch or1200_ctrl.v")
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
    if old_genpc not in genpc_text:
        raise ValueError("Failed to patch or1200_genpc.v")
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
    if old_mult_line not in mult_mac_text or old_mult_end not in mult_mac_text:
        raise ValueError("Failed to patch or1200_mult_mac.v")
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
    if old_sprs not in sprs_text:
        raise ValueError("Failed to patch or1200_sprs.v")
    sprs.write_text(sprs_text.replace(old_sprs, new_sprs, 1), encoding="utf-8")

    defines = temp_ref_root / "or1200_defines.v"
    defines_text = defines.read_text(encoding="utf-8")
    defines_text, count_virtex = re.subn(
        r"(?m)^\s*`define OR1200_RAM_MODELS_VIRTEX\s*$",
        "//`define OR1200_RAM_MODELS_VIRTEX",
        defines_text,
        count=1,
    )
    defines_text, count_rfram = re.subn(
        r"(?m)^\s*//`define OR1200_RFRAM_GENERIC\s*$",
        "`define OR1200_RFRAM_GENERIC",
        defines_text,
        count=1,
    )
    if count_virtex != 1 or count_rfram != 1:
        raise ValueError("Failed to patch or1200_defines.v")
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
                    "{write_active}", write_active
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


def prepare_or1200_workspace(or1200_ref_root: Path) -> tuple[Path, list[Path]]:
    tempdir = Path(tempfile.mkdtemp(prefix="or1200_equiv_ref_"))
    temp_ref_root = tempdir / "verilog"
    temp_ref_root.mkdir(parents=True, exist_ok=False)

    copied_files = []
    for src in sorted(or1200_ref_root.glob("*.v")):
        dest = temp_ref_root / src.name
        shutil.copy2(src, dest)
        if src.name != "or1200_defines.v":
            copied_files.append(dest)

    repair_or1200_reference_root(temp_ref_root)
    primitives = temp_ref_root / "or1200_temp_primitives.v"
    primitives.write_text(build_or1200_primitive_models(), encoding="ascii")
    copied_files.append(primitives)
    return temp_ref_root, copied_files


def build_design_inputs(
    sample: Sample,
    double_ref_root: Path,
    or1200_ref_root: Path,
) -> tuple[list[Path], list[Path], list[Path], list[Path], bool, bool, Path | None]:
    if sample.family == "fpu":
        all_ref_files = sorted(
            path
            for path in double_ref_root.glob("*.v")
            if path.name != "fpu_TB.v"
        )
        gold_files = all_ref_files
        gate_files = [sample.candidate_file] + [
            path for path in all_ref_files if path.name != sample.reference_file.name
        ]
        gold_includes = [double_ref_root]
        gate_includes = [sample.candidate_file.parent, double_ref_root]
        return gold_files, gold_includes, gate_files, gate_includes, False, False, None

    temp_ref_root, temp_files = prepare_or1200_workspace(or1200_ref_root)
    gold_files = sorted(temp_files)
    gate_files = [sample.candidate_file] + [
        path for path in sorted(temp_files) if path.name != sample.reference_file.name
    ]
    gold_includes = [temp_ref_root, or1200_ref_root.parent]
    gate_includes = [temp_ref_root, sample.candidate_file.parent, or1200_ref_root.parent]
    return gold_files, gold_includes, gate_files, gate_includes, True, True, temp_ref_root.parent


def precheck_design(
    yosys: str,
    files: list[Path],
    include_dirs: list[Path],
    top: str,
    timeout: int,
) -> tuple[bool, str]:
    ok, output = run_yosys_script(
        yosys, build_precheck_script(files, include_dirs, top), timeout
    )
    if ok:
        return True, "Precheck passed"
    return False, summarize_error(output)


def run_equivalence(
    yosys: str,
    gold_files: list[Path],
    gold_includes: list[Path],
    gate_files: list[Path],
    gate_includes: list[Path],
    reference_top: str,
    candidate_top: str,
    proof_type: str,
    seq_depth: int,
    has_rst: bool,
    timeout: int,
) -> tuple[str, str]:
    ok, output = run_yosys_script(
        yosys,
        build_proof_script(
            gold_files=gold_files,
            gold_includes=gold_includes,
            gate_files=gate_files,
            gate_includes=gate_includes,
            reference_top=reference_top,
            candidate_top=candidate_top,
            proof_type=proof_type,
            seq_depth=seq_depth,
            has_rst=has_rst,
        ),
        timeout,
    )

    if "SAT proof finished - no model found: SUCCESS!" in output:
        if proof_type == "strict_comb":
            return "pass_strict", "Strict combinational SAT proof passed"
        return "pass_bounded", f"Bounded sequential proof passed within {seq_depth} cycles"

    if "SAT proof finished - model found: FAIL!" in output:
        return "equiv_fail", summarize_error(output)

    if ok:
        return "tool_limited", summarize_error(output)

    if output.startswith("Timeout after "):
        return "tool_limited", output
    return "tool_limited", summarize_error(output)


def check_sample(
    sample: Sample,
    yosys: str,
    double_ref_root: Path,
    or1200_ref_root: Path,
    seq_depth: int,
    timeout: int,
) -> SampleResult:
    started = time.perf_counter()
    temp_cleanup_root: Path | None = None
    used_temp_ref_repair = False
    used_temp_primitive_models = False

    try:
        (
            gold_files,
            gold_includes,
            gate_files,
            gate_includes,
            used_temp_ref_repair,
            used_temp_primitive_models,
            temp_cleanup_root,
        ) = build_design_inputs(sample, double_ref_root, or1200_ref_root)

        proof_type = detect_proof_type(gate_files, sample.candidate_top)
        if proof_type not in {"strict_comb", "bounded_seq"}:
            proof_type = "unknown"

        gold_ok, gold_msg = precheck_design(
            yosys=yosys,
            files=gold_files,
            include_dirs=gold_includes,
            top=sample.reference_top,
            timeout=timeout,
        )
        if not gold_ok:
            return SampleResult(
                family=sample.family,
                module_dir=sample.module_dir,
                candidate_file=str(sample.candidate_file),
                variant=sample.variant,
                reference_file=str(sample.reference_file),
                reference_top=sample.reference_top,
                candidate_top=sample.candidate_top,
                proof_type=proof_type,
                precheck_status="gold_fail",
                equivalence_status="precheck_fail",
                reason=f"Gold precheck failed: {gold_msg}",
                used_temp_ref_repair=used_temp_ref_repair,
                used_temp_primitive_models=used_temp_primitive_models,
                elapsed_sec=time.perf_counter() - started,
            )

        gate_ok, gate_msg = precheck_design(
            yosys=yosys,
            files=gate_files,
            include_dirs=gate_includes,
            top=sample.candidate_top,
            timeout=timeout,
        )
        if not gate_ok:
            return SampleResult(
                family=sample.family,
                module_dir=sample.module_dir,
                candidate_file=str(sample.candidate_file),
                variant=sample.variant,
                reference_file=str(sample.reference_file),
                reference_top=sample.reference_top,
                candidate_top=sample.candidate_top,
                proof_type=proof_type,
                precheck_status="gate_fail",
                equivalence_status="precheck_fail",
                reason=f"Gate precheck failed: {gate_msg}",
                used_temp_ref_repair=used_temp_ref_repair,
                used_temp_primitive_models=used_temp_primitive_models,
                elapsed_sec=time.perf_counter() - started,
            )

        if proof_type == "unknown":
            return SampleResult(
                family=sample.family,
                module_dir=sample.module_dir,
                candidate_file=str(sample.candidate_file),
                variant=sample.variant,
                reference_file=str(sample.reference_file),
                reference_top=sample.reference_top,
                candidate_top=sample.candidate_top,
                proof_type=proof_type,
                precheck_status="pass",
                equivalence_status="tool_limited",
                reason="Unable to classify module as combinational or sequential",
                used_temp_ref_repair=used_temp_ref_repair,
                used_temp_primitive_models=used_temp_primitive_models,
                elapsed_sec=time.perf_counter() - started,
            )

        equivalence_status, reason = run_equivalence(
            yosys=yosys,
            gold_files=gold_files,
            gold_includes=gold_includes,
            gate_files=gate_files,
            gate_includes=gate_includes,
            reference_top=sample.reference_top,
            candidate_top=sample.candidate_top,
            proof_type=proof_type,
            seq_depth=seq_depth,
            has_rst=sample.candidate_has_rst,
            timeout=timeout,
        )
        return SampleResult(
            family=sample.family,
            module_dir=sample.module_dir,
            candidate_file=str(sample.candidate_file),
            variant=sample.variant,
            reference_file=str(sample.reference_file),
            reference_top=sample.reference_top,
            candidate_top=sample.candidate_top,
            proof_type=proof_type,
            precheck_status="pass",
            equivalence_status=equivalence_status,
            reason=reason,
            used_temp_ref_repair=used_temp_ref_repair,
            used_temp_primitive_models=used_temp_primitive_models,
            elapsed_sec=time.perf_counter() - started,
        )
    finally:
        if temp_cleanup_root is not None:
            shutil.rmtree(temp_cleanup_root, ignore_errors=True)


def write_results_csv(path: Path, results: list[SampleResult]) -> None:
    fieldnames = [
        "family",
        "module_dir",
        "candidate_file",
        "variant",
        "reference_file",
        "reference_top",
        "candidate_top",
        "proof_type",
        "precheck_status",
        "equivalence_status",
        "reason",
        "used_temp_ref_repair",
        "used_temp_primitive_models",
        "elapsed_sec",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for result in results:
            row = asdict(result)
            row["elapsed_sec"] = f"{result.elapsed_sec:.3f}"
            writer.writerow(row)


def nested_counts(
    results: list[SampleResult],
    primary: str,
    secondary: str,
) -> dict[str, dict[str, int]]:
    counts: dict[str, Counter[str]] = defaultdict(Counter)
    for result in results:
        counts[getattr(result, primary)][getattr(result, secondary)] += 1
    return {
        key: dict(sorted(counter.items()))
        for key, counter in sorted(counts.items(), key=lambda item: item[0])
    }


def build_summary(
    args: argparse.Namespace, results: list[SampleResult]
) -> dict[str, object]:
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "arguments": {
            "test_root": str(args.test_root),
            "double_ref_root": str(args.double_ref_root),
            "or1200_ref_root": str(args.or1200_ref_root),
            "report_dir": str(args.report_dir),
            "seq_depth": args.seq_depth,
            "timeout": args.timeout,
        },
        "totals": {
            "samples": len(results),
            "families": dict(sorted(Counter(r.family for r in results).items())),
            "variants": dict(sorted(Counter(r.variant for r in results).items())),
            "proof_types": dict(sorted(Counter(r.proof_type for r in results).items())),
            "equivalence_status": dict(
                sorted(Counter(r.equivalence_status for r in results).items())
            ),
        },
        "family_by_status": nested_counts(results, "family", "equivalence_status"),
        "variant_by_status": nested_counts(results, "variant", "equivalence_status"),
        "proof_type_by_status": nested_counts(results, "proof_type", "equivalence_status"),
        "precheck_by_status": nested_counts(results, "precheck_status", "equivalence_status"),
    }


def print_result_line(result: SampleResult) -> None:
    print(
        f"[{result.equivalence_status}] "
        f"{result.family}/{result.module_dir} "
        f"{Path(result.candidate_file).name} "
        f"proof={result.proof_type} "
        f"precheck={result.precheck_status} "
        f"reason={result.reason}",
        flush=True,
    )


def print_summary(summary: dict[str, object], csv_path: Path, json_path: Path) -> None:
    totals = summary["totals"]
    print("", flush=True)
    print("Summary", flush=True)
    print(f"  samples: {totals['samples']}", flush=True)
    print(f"  families: {totals['families']}", flush=True)
    print(f"  variants: {totals['variants']}", flush=True)
    print(f"  proof_types: {totals['proof_types']}", flush=True)
    print(f"  equivalence_status: {totals['equivalence_status']}", flush=True)
    print(f"  csv: {csv_path}", flush=True)
    print(f"  json: {json_path}", flush=True)


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(
        description="Batch equivalence checking for generated test Verilog files."
    )
    parser.add_argument("--test-root", type=Path, default=repo_root / "test")
    parser.add_argument(
        "--double-ref-root",
        type=Path,
        default=repo_root / "Src" / "double_fpu" / "rtl" / "verilog",
    )
    parser.add_argument(
        "--or1200-ref-root",
        type=Path,
        default=repo_root / "Src" / "or1200_hp" / "rtl" / "verilog",
    )
    parser.add_argument("--report-dir", type=Path, default=repo_root / "reports")
    parser.add_argument("--seq-depth", type=int, default=80)
    parser.add_argument("--timeout", type=int, default=300)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    yosys = shutil.which("yosys")
    if yosys is None:
        print("Tool not found: yosys", file=sys.stderr)
        return 2

    samples = discover_samples(
        test_root=args.test_root.resolve(),
        double_ref_root=args.double_ref_root.resolve(),
        or1200_ref_root=args.or1200_ref_root.resolve(),
    )
    print(
        "Discovered "
        f"{len(samples)} samples under {args.test_root.resolve()} "
        f"(timeout={args.timeout}s, seq_depth={args.seq_depth})",
        flush=True,
    )

    results: list[SampleResult] = []
    for index, sample in enumerate(samples, start=1):
        print(
            f"Checking {index}/{len(samples)}: "
            f"{sample.family}/{sample.module_dir} {sample.candidate_file.name}",
            flush=True,
        )
        result = check_sample(
            sample=sample,
            yosys=yosys,
            double_ref_root=args.double_ref_root.resolve(),
            or1200_ref_root=args.or1200_ref_root.resolve(),
            seq_depth=args.seq_depth,
            timeout=args.timeout,
        )
        results.append(result)
        print_result_line(result)

    args.report_dir.mkdir(parents=True, exist_ok=True)
    csv_path = args.report_dir / "equivalence_results.csv"
    json_path = args.report_dir / "equivalence_summary.json"
    write_results_csv(csv_path, results)
    summary = build_summary(args, results)
    json_path.write_text(json.dumps(summary, indent=2, sort_keys=True), encoding="utf-8")
    print_summary(summary, csv_path, json_path)
    return 0 if all(result.equivalence_status in FINAL_PASS_STATUSES for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
