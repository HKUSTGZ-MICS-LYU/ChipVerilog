#!/usr/bin/env python3
"""Refresh Internal reg/wire descriptions in des/**/description.txt files.

The script expands grouped reg/wire declarations into one line per signal and
replaces generic boilerplate with short, signal-specific descriptions derived
from:
  - the RTL declaration itself
  - nearby RTL comments
  - common naming patterns used by the bundled designs
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]


GENERIC_COMMENT_RE = re.compile(
    r"^(internal .*|module body|state machine variable|variable declarations|i/o|"
    r"clock and reset|external i/f.*|internal i/f.*|module name|"
    r"implementation options|functional overview|description)$",
    re.IGNORECASE,
)

FIELD_WORDS = {
    "dat": "data",
    "data": "data",
    "dataout": "result data",
    "adr": "address",
    "addr": "address",
    "cyc": "cycle request",
    "cycstb": "cycle/strobe request",
    "stb": "strobe request",
    "we": "write-enable",
    "sel": "byte-select",
    "cab": "burst-cycle indicator",
    "ack": "acknowledge",
    "err": "error",
    "tag": "tag",
    "ci": "cache-inhibit indication",
    "clk": "clock",
    "rst": "reset",
    "rty": "retry",
}

BOOL_HINTS = {
    "ack",
    "al",
    "busy",
    "carry",
    "ce",
    "chk",
    "done",
    "empty",
    "ena",
    "enable",
    "en",
    "err",
    "flag",
    "freeze",
    "full",
    "hold",
    "inf",
    "irq",
    "load",
    "miss",
    "ready",
    "req",
    "reset",
    "retry",
    "rty",
    "set",
    "stall",
    "stop",
    "sync",
    "taken",
    "uf",
    "valid",
    "wait",
    "we",
    "zero",
}

TOKEN_MAP = {
    "a": "A",
    "ack": "acknowledge",
    "add": "add",
    "addrofs": "address offset",
    "adr": "address",
    "addr": "address",
    "alu": "ALU",
    "b": "B",
    "bal": "branch-and-link",
    "biu": "bus interface unit",
    "binsn": "branch instruction",
    "bp": "breakpoint",
    "cab": "burst cycle",
    "carry": "carry",
    "cfgr": "configuration register",
    "chk": "check",
    "clk": "clock",
    "cnt": "count",
    "comp": "compare",
    "cond": "condition",
    "count": "count",
    "cpu": "CPU",
    "ci": "cache inhibit",
    "cs": "chip-select",
    "cy": "carry",
    "cyc": "cycle",
    "cycstb": "cycle/strobe",
    "d": "D",
    "dat": "data",
    "data": "data",
    "dataout": "result data",
    "dc": "data cache",
    "dcfsm": "data-cache FSM",
    "dctag": "data-cache tag RAM",
    "dcpu": "data-side CPU",
    "debug": "debug",
    "denorm": "denormal",
    "dis": "disable",
    "dividend": "dividend",
    "divisor": "divisor",
    "dmr": "debug mode register",
    "dmmu": "data MMU",
    "done": "done",
    "dout": "data output",
    "dslot": "delay slot",
    "du": "debug unit",
    "dvr": "debug value register",
    "dwb": "data Wishbone",
    "dwcr": "debug watchpoint control register",
    "e": "E",
    "eear": "exception address register",
    "en": "enable",
    "ena": "enable",
    "enable": "enable",
    "epcr": "exception PC register",
    "err": "error",
    "esr": "exception status register",
    "et0": "equals zero",
    "ex": "execute",
    "except": "exception",
    "expoffset": "exponent offset",
    "expon": "exponent",
    "exponent": "exponent",
    "fetch": "fetch",
    "flag": "flag",
    "forw": "forward",
    "fpuf": "pipeline valid",
    "freeze": "freeze",
    "fsm": "FSM",
    "genpc": "PC-generation",
    "hitmiss": "hit/miss",
    "hold": "hold",
    "i": "input",
    "ic": "instruction cache",
    "icfsm": "instruction-cache FSM",
    "ictag": "instruction-cache tag RAM",
    "icpu": "instruction-side CPU",
    "id": "decode",
    "idx": "index",
    "if": "instruction fetch",
    "imm": "immediate",
    "immu": "instruction MMU",
    "index": "index",
    "inf": "infinity",
    "init": "initialization",
    "insn": "instruction",
    "irq": "interrupt request",
    "is": "is",
    "itlb": "instruction TLB",
    "itlbmiss": "instruction-TLB miss",
    "iwb": "instruction Wishbone",
    "j": "J",
    "lr": "link register",
    "lsu": "load/store unit",
    "mac": "multiply-accumulate",
    "mantissa": "mantissa",
    "mbist": "MBIST",
    "mem": "memory",
    "memdata": "memory data",
    "mode": "mode",
    "ram": "RAM",
    "msb": "MSB",
    "mul": "multiply",
    "mux": "mux",
    "nan": "NaN",
    "nm": "normal",
    "nonzero": "nonzero",
    "norm": "normalized",
    "npc": "next PC",
    "o": "output",
    "of": "overflow",
    "offset": "offset",
    "opa": "operand A",
    "opb": "operand B",
    "op": "operation",
    "or1200": "OR1200",
    "out": "output",
    "pc": "program counter",
    "pcreg": "program counter register",
    "pic": "interrupt controller",
    "picmr": "PIC mask register",
    "picsr": "PIC status register",
    "pm": "power-management",
    "ppc": "previous PC",
    "ppn": "physical page number",
    "prefetch": "prefetch",
    "prodshift": "product-shift",
    "product": "product",
    "qmem": "QMEM",
    "quotient": "quotient",
    "r": "registered",
    "ready": "ready",
    "regdata": "register data",
    "remainder": "remainder",
    "reset": "reset",
    "rf": "register file",
    "rfwb": "register-file writeback",
    "rm": "rounding mode",
    "rotor": "rotator",
    "round": "round",
    "rst": "reset",
    "rty": "retry",
    "sav": "saved",
    "sb": "store buffer",
    "scl": "SCL",
    "sda": "SDA",
    "sel": "select",
    "seq": "sequential",
    "shift": "shift",
    "shifted": "shifted",
    "shrot": "shift/rotate",
    "sig": "signal",
    "si": "serial input",
    "sign": "sign",
    "so": "serial output",
    "simm": "sign-extended immediate",
    "spr": "SPR",
    "sprs": "SPR subsystem",
    "sr": "status register",
    "sta": "START",
    "state": "state",
    "stb": "strobe",
    "sticky": "sticky",
    "sto": "STOP",
    "stop": "stop",
    "sub": "subtract",
    "supv": "supervisor",
    "sync": "synchronization",
    "tag": "tag",
    "tagcomp": "tag-compare",
    "taken": "taken",
    "term": "term",
    "terms": "terms",
    "theta": "theta",
    "tlb": "TLB",
    "tbia": "trace-buffer instruction-address RAM",
    "tbim": "trace-buffer instruction-memory RAM",
    "to": "to",
    "top": "top-level",
    "trap": "trap",
    "ttcr": "tick-timer count register",
    "ttmr": "tick-timer mode register",
    "tt": "tick timer",
    "uf": "underflow",
    "uut": "unit under test",
    "uxe": "user-execute enable",
    "valid": "valid",
    "v": "valid",
    "vector": "vector",
    "vpn": "virtual page number",
    "wait": "wait",
    "wacc": "write-access",
    "wadr": "write address",
    "wb": "writeback",
    "wbforw": "writeback forwarding",
    "wbmux": "writeback mux",
    "we": "write-enable",
    "wr": "write",
    "x": "x",
    "y": "y",
    "sxe": "supervisor-execute enable",
    "z": "z",
    "zero": "zero",
}

MODULE_EXACT = {
    "cordic": {
        "iteration": "Current CORDIC iteration index.",
        "x": "Per-stage x datapath values across the CORDIC pipeline.",
        "y": "Per-stage y datapath values across the CORDIC pipeline.",
        "z": "Per-stage angle accumulator values across the CORDIC pipeline.",
        "v": "Per-stage valid bits that track the pipeline payload.",
    },
    "tb": {
        "x_i": "Stimulus x input driven into the CORDIC DUT.",
        "y_i": "Stimulus y input driven into the CORDIC DUT.",
        "theta_i": "Stimulus angle input driven into the CORDIC DUT.",
        "clock": "Testbench clock that drives the DUT.",
        "reset": "Testbench reset driven into the DUT.",
        "init": "Testbench load pulse for iterative CORDIC mode.",
        "ex": "Absolute x-error measured against the lookup table.",
        "ey": "Absolute y-error measured against the lookup table.",
        "x": "Lookup-table cosine/reference x values for each test angle.",
        "y": "Lookup-table sine/reference y values for each test angle.",
        "z": "Lookup-table angle values used for stimulus generation.",
        "x_o": "Observed DUT x output during simulation.",
        "y_o": "Observed DUT y output during simulation.",
        "theta_o": "Observed DUT angle output during simulation.",
    },
    "i2c_master_bit_ctrl": {
        "cSCL": "Captured SCL samples used by the input filter.",
        "cSDA": "Captured SDA samples used by the input filter.",
        "fSCL": "Filtered SCL sample history.",
        "fSDA": "Filtered SDA sample history.",
        "sSCL": "Filtered and synchronized SCL input.",
        "sSDA": "Filtered and synchronized SDA input.",
        "dSCL": "Delayed copy of the synchronized SCL input.",
        "dSDA": "Delayed copy of the synchronized SDA input.",
        "dscl_oen": "Delayed copy of `scl_oen` for stretch/sync checks.",
        "sda_chk": "Enables SDA arbitration checking during driven bits.",
        "clk_en": "Prescaler tick that advances the bit-level FSM.",
        "slave_wait": "Indicates that a slave is stretching SCL low.",
        "cnt": "Clock-divider counter for SCL timing generation.",
        "filter_cnt": "Counter that times the SCL/SDA glitch filter.",
        "c_state": "Current state of the bit-level command FSM.",
        "sta_condition": "Detected I2C START condition.",
        "sto_condition": "Detected I2C STOP condition.",
        "cmd_stop": "Decoded request for a STOP command.",
        "scl_sync": "Clock-synchronization pulse when SCL is held low externally.",
    },
    "i2c_master_top": {
        "wb_dat_o": "Wishbone read-data register returned to the host.",
        "wb_ack_o": "Wishbone acknowledge pulse back to the host.",
        "wb_inta_o": "Interrupt output presented on the Wishbone side.",
        "prer": "Clock-prescale register for the I2C bit timing.",
        "ctr": "Control register that enables the core and its interrupt.",
        "txr": "Transmit register that holds the outgoing byte.",
        "rxr": "Receive register that captures the incoming byte.",
        "cr": "Command register written by the host.",
        "sr": "Packed status-register value returned on reads.",
        "done": "Command-complete pulse used to clear command bits.",
        "core_en": "Core-enable bit from the control register.",
        "ien": "Interrupt-enable bit from the control register.",
        "irxack": "Receive-acknowledge status from the byte controller.",
        "rxack": "Latched receive-acknowledge status bit.",
        "tip": "Transfer-in-progress status bit.",
        "irq_flag": "Interrupt-pending status bit.",
        "i2c_busy": "Bus-busy indication from the bit controller.",
        "i2c_al": "Arbitration-lost indication from the bit controller.",
        "al": "Latched arbitration-lost status bit.",
        "rst_i": "Internally normalized reset signal.",
        "wb_wacc": "Wishbone write-access qualifier.",
        "sta": "Decoded START-command bit.",
        "sto": "Decoded STOP-command bit.",
        "rd": "Decoded READ-command bit.",
        "wr": "Decoded WRITE-command bit.",
        "ack": "Decoded ACK-command bit.",
        "iack": "Decoded interrupt-acknowledge bit.",
    },
    "i2c_master_byte_ctrl": {
        "cmd_ack": "Byte-command complete pulse to the host side.",
        "ack_out": "Captured ACK/NACK bit returned from the slave.",
        "core_cmd": "Command word sent into the bit controller.",
        "core_txd": "Transmit bit driven into the bit controller.",
        "core_ack": "Command-complete acknowledge from the bit controller.",
        "core_rxd": "Receive bit sampled from the bit controller.",
        "sr": "Byte-shift register for transmit and receive data.",
        "shift": "Pulse that shifts the byte register by one bit.",
        "ld": "Pulse that loads a new byte into the shift register.",
        "go": "Start condition for launching a byte-level transfer step.",
        "dcnt": "Bit counter for the current byte transfer.",
        "cnt_done": "Flag that the bit counter reached its terminal count.",
        "c_state": "Current state of the byte-level transfer FSM.",
    },
    "or1200_genpc": {
        "pcreg": "Registered program-counter value in word address form.",
        "pc": "Next fetch address selected by the PC-generation logic.",
        "taken": "Branch-taken result for the current control-flow operation.",
        "genpc_refetch_r": "One-cycle registered copy of `genpc_refetch`.",
    },
    "or1200_mult_mac": {
        "result": "Selected result from the multiply/divide/MAC datapath.",
        "mul_prod_r": "Registered multiplier/divider datapath result.",
        "mul_prod": "Combinational multiplier product.",
        "mac_op_r1": "Stage-1 pipeline copy of the MAC operation.",
        "mac_op_r2": "Stage-2 pipeline copy of the MAC operation.",
        "mac_op_r3": "Stage-3 pipeline copy of the MAC operation.",
        "mac_stall_r": "Registered MAC stall request.",
        "mac_r": "MAC accumulator value.",
        "x": "Operand A after divide-sign preprocessing.",
        "y": "Operand B after divide-sign preprocessing.",
        "spr_maclo_we": "SPR write-enable for the low 32 bits of `mac_r`.",
        "spr_machi_we": "SPR write-enable for the high 32 bits of `mac_r`.",
        "alu_op_div_divu": "Flag that the ALU op is DIV or DIVU.",
        "alu_op_div": "Flag that the ALU op is signed DIV.",
        "div_free": "Divider-idle flag.",
        "div_tmp": "Intermediate subtraction term for the divider loop.",
        "div_cntr": "Divider iteration counter.",
    },
    "or1200_freeze": {
        "multicycle_freeze": "Freeze asserted while a multicycle op is active.",
        "multicycle_cnt": "Countdown for the remaining multicycle stalls.",
        "flushpipe_r": "One-cycle registered copy of the pipeline flush request.",
    },
    "or1200_du": {
        "dbg_is_o": "Encoded external instruction-fetch status.",
        "dbg_ack_o": "Debug acknowledge output register.",
        "dsr": "Debug stop register.",
        "drr": "Debug reason register.",
        "tb_enw": "Trace-buffer write-enable.",
        "tb_wadr": "Trace-buffer write address.",
    },
    "or1200_mem2reg": {
        "aligned": "Aligned load-data word before byte extraction.",
    },
    "or1200_immu_top": {
        "itlb_spr_access": "SPR-access request targeting the instruction TLB.",
        "itlb_ppn": "Physical page number returned by the instruction TLB.",
        "itlb_hit": "Instruction-TLB hit flag.",
        "itlb_uxe": "Instruction-TLB user-execute permission bit.",
        "itlb_sxe": "Instruction-TLB supervisor-execute permission bit.",
        "itlb_dat_o": "Raw data word read from the instruction TLB.",
        "itlb_en": "Instruction-TLB enable flag.",
        "itlb_ci": "Instruction-TLB cache-inhibit attribute.",
        "itlb_done": "Instruction-TLB lookup-complete flag.",
        "fault": "Instruction address translation-fault flag.",
        "miss": "Instruction-TLB miss flag.",
        "page_cross": "Flag that the fetch crosses a page boundary.",
        "icpu_adr_o": "Translated instruction fetch address.",
        "icpu_vpn_r": "Registered virtual page number of the fetch address.",
        "itlb_en_r": "Registered copy of the instruction-TLB enable flag.",
        "dis_spr_access": "Flag that disables SPR access for this request.",
    },
    "or1200_ic_top": {
        "tag": "Cache-tag value read from the instruction-cache tag RAM.",
    },
    "or1200_dc_top": {
        "tag": "Cache-tag value read from the data-cache tag RAM.",
    },
    "or1200_pm": {
        "sdf": "Clock slow-down factor from the PM register.",
        "dme": "Doze-mode enable bit.",
        "sme": "Sleep-mode enable bit.",
        "dcge": "Dynamic clock-gating enable bit.",
        "pmr_sel": "Power-management register select.",
    },
    "fpu_exceptions": {
        "NaN_input": "Flag that at least one input operand is NaN.",
        "SNaN_input": "Flag that a signaling NaN is present at the input.",
        "a_NaN": "Canonical NaN-selection flag for the output path.",
        "div_by_0": "Flag that the divide operation has a zero divisor.",
        "div_0_by_0": "Flag that the divide operation is 0/0.",
    },
}


@dataclass
class SignalDecl:
    name: str
    decl_text: str
    kind: str
    packed: str
    unpacked: str
    assign: str | None
    inline_comment: str
    context_comment: str
    line_no: int


def clean_comment(text: str) -> str:
    text = text.strip()
    text = re.sub(r"^[/\*\s]+", "", text)
    text = re.sub(r"[/\*\s]+$", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def split_inline_comment(line: str) -> tuple[str, str]:
    if "//" not in line:
        return line, ""
    code, comment = line.split("//", 1)
    return code, clean_comment(comment)


def strip_block_comments(text: str) -> str:
    return re.sub(r"/\*.*?\*/", "", text, flags=re.S)


def extract_module_name(desc_text: str) -> str | None:
    match = re.search(r"Module\s+`([A-Za-z_][\w$]*)`", desc_text)
    if match:
        return match.group(1)
    match = re.search(r"Module name:\s*\n\s*(?:module\s+)?([A-Za-z_][\w$]*)", desc_text)
    if not match:
        return None
    module_name = match.group(1)
    if module_name.upper() == "N":
        return None
    if module_name.upper() == "N/A":
        return None
    return module_name


def extract_module_block(rtl_text: str, module_name: str) -> str:
    pattern = re.compile(
        rf"\bmodule\s+{re.escape(module_name)}\b.*?\bendmodule\b",
        re.S,
    )
    match = pattern.search(rtl_text)
    if not match:
        raise RuntimeError(f"unable to locate module {module_name}")
    return match.group(0)


def is_meaningful_comment(text: str) -> bool:
    if not text:
        return False
    if GENERIC_COMMENT_RE.match(text):
        return False
    if re.fullmatch(r"[-=_. ]+", text):
        return False
    return True


def split_top_level_commas(text: str) -> list[str]:
    parts: list[str] = []
    depth_paren = depth_brack = depth_brace = 0
    start = 0
    for idx, ch in enumerate(text):
        if ch == "(":
            depth_paren += 1
        elif ch == ")":
            depth_paren = max(depth_paren - 1, 0)
        elif ch == "[":
            depth_brack += 1
        elif ch == "]":
            depth_brack = max(depth_brack - 1, 0)
        elif ch == "{":
            depth_brace += 1
        elif ch == "}":
            depth_brace = max(depth_brace - 1, 0)
        elif ch == "," and depth_paren == depth_brack == depth_brace == 0:
            parts.append(text[start:idx].strip())
            start = idx + 1
    parts.append(text[start:].strip())
    return [part for part in parts if part]


def split_decl_prefix(statement: str) -> tuple[str, str, str]:
    statement = statement.strip().rstrip(";")
    kind_match = re.match(r"^(reg|wire)\b", statement)
    if not kind_match:
        raise ValueError(f"unsupported declaration: {statement}")
    kind = kind_match.group(1)
    rest = statement[kind_match.end():].strip()
    extras: list[str] = []
    if rest.startswith("signed "):
        extras.append("signed")
        rest = rest[7:].lstrip()
    while rest.startswith("["):
        depth = 0
        for idx, ch in enumerate(rest):
            if ch == "[":
                depth += 1
            elif ch == "]":
                depth -= 1
                if depth == 0:
                    extras.append(rest[: idx + 1])
                    rest = rest[idx + 1 :].lstrip()
                    break
        else:
            break
    packed = " ".join(extras).strip()
    prefix = kind + (f" {packed}" if packed else "")
    return kind, packed, rest


def parse_decl_item(item: str) -> tuple[str, str, str | None]:
    match = re.match(r"^([A-Za-z_][\w$]*)(.*)$", item.strip())
    if not match:
        raise ValueError(f"unable to parse declaration item: {item}")
    name = match.group(1)
    rest = match.group(2).strip()
    unpacked_parts: list[str] = []
    while rest.startswith("["):
        depth = 0
        for idx, ch in enumerate(rest):
            if ch == "[":
                depth += 1
            elif ch == "]":
                depth -= 1
                if depth == 0:
                    unpacked_parts.append(rest[: idx + 1].strip())
                    rest = rest[idx + 1 :].strip()
                    break
        else:
            break
    assign = None
    if rest.startswith("="):
        assign = rest[1:].strip()
    unpacked = " ".join(unpacked_parts).strip()
    return name, unpacked, assign


def parse_signal_decls(module_block: str) -> list[SignalDecl]:
    lines = strip_block_comments(module_block).splitlines()
    decls: list[SignalDecl] = []
    comment_buffer: list[str] = []
    stmt_lines: list[str] = []
    stmt_comments: list[str] = []
    collecting = False

    for line_no, line in enumerate(lines, 1):
        stripped = line.strip()
        if not collecting:
            if not stripped:
                continue
            if stripped.startswith("//"):
                comment = clean_comment(stripped[2:])
                if is_meaningful_comment(comment):
                    comment_buffer.append(comment)
                    comment_buffer = comment_buffer[-6:]
                continue
            code, inline_comment = split_inline_comment(line)
            if re.match(r"^\s*(reg|wire)\b", code):
                stmt_lines = [code]
                stmt_comments = comment_buffer[:]
                comment_buffer = []
                collecting = ";" not in code
                if not collecting:
                    stmt_text = " ".join(part.strip() for part in stmt_lines)
                    add_statement(
                        decls,
                        stmt_text,
                        stmt_comments,
                        inline_comment,
                        line_no,
                    )
                continue
            comment_buffer = []
            continue

        stmt_lines.append(split_inline_comment(line)[0])
        code, inline_comment = split_inline_comment(line)
        if ";" in code:
            stmt_text = " ".join(part.strip() for part in stmt_lines)
            add_statement(decls, stmt_text, stmt_comments, inline_comment, line_no)
            stmt_lines = []
            stmt_comments = []
            collecting = False

    return decls


def add_statement(
    decls: list[SignalDecl],
    stmt_text: str,
    comment_buffer: list[str],
    inline_comment: str,
    line_no: int,
) -> None:
    try:
        kind, packed, varlist = split_decl_prefix(stmt_text)
    except ValueError:
        return
    prefix = kind + (f" {packed}" if packed else "")
    context_comment = " ".join(comment_buffer[-3:]).strip()
    for item in split_top_level_commas(varlist):
        try:
            name, unpacked, assign = parse_decl_item(item)
        except ValueError:
            continue
        decl_text = prefix + " " + name
        if unpacked:
            decl_text += " " + unpacked
        if assign is not None:
            decl_text += " = " + assign
        decls.append(SignalDecl(
            name=name,
            decl_text=decl_text,
            kind=kind,
            packed=packed,
            unpacked=unpacked,
            assign=assign,
            inline_comment=inline_comment,
            context_comment=context_comment,
            line_no=line_no,
        ))


def tokenize(name: str) -> list[str]:
    name = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", name)
    name = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", name)
    name = re.sub(r"([A-Za-z])([0-9]+)", r"\1_\2", name)
    name = re.sub(r"([0-9]+)([A-Za-z])", r"\1_\2", name)
    parts: list[str] = []
    for piece in name.split("_"):
        piece = piece.strip()
        if not piece:
            continue
        parts.append(piece.lower())
    return parts


def title_case_phrase(text: str) -> str:
    if not text:
        return text
    return text[0].upper() + text[1:]


def section_bus_description(section: str, sig_name: str) -> str | None:
    if not section:
        return None
    section_lower = section.lower()
    match = re.search(r"\bto\b|\band\b", section_lower)
    if not match:
        return None
    parts = [part.strip() for part in re.split(r"\bto\b|\band\b", section, maxsplit=1)]
    if len(parts) != 2:
        return None
    endpoints = tuple(parts)
    tokens = tokenize(sig_name)
    if len(tokens) < 2:
        return None
    field = None
    endpoint = None
    if tokens[-1] in {part.lower().split()[0] for part in endpoints}:
        endpoint = tokens[-1]
        field = tokens[-2]
    elif tokens[-1] in FIELD_WORDS:
        field = tokens[-1]
    if field not in FIELD_WORDS:
        return None
    phrase = f"{endpoints[0]}-{endpoints[1]} {FIELD_WORDS[field]}"
    if endpoint:
        if endpoint == endpoints[0].lower().split()[0]:
            phrase += f" on the {endpoints[0]} side"
        elif endpoint == endpoints[1].lower().split()[0]:
            phrase += f" on the {endpoints[1]} side"
    return title_case_phrase(phrase) + "."


def phrase_from_inline_comment(sig_name: str, comment: str) -> str | None:
    if not comment:
        return None
    lower = comment.lower()
    if "capture scl and sda" in lower:
        return "Captured SCL samples used by the input filter." if "scl" in sig_name.lower() else "Captured SDA samples used by the input filter."
    if "filter inputs" in lower:
        return "Filtered SCL sample history." if "scl" in sig_name.lower() else "Filtered SDA sample history."
    if "filtered and synchronized" in lower:
        return "Filtered and synchronized SCL input." if "scl" in sig_name.lower() else "Filtered and synchronized SDA input."
    if "delayed versions" in lower:
        return "Delayed copy of the synchronized SCL input." if "scl" in sig_name.lower() else "Delayed copy of the synchronized SDA input."
    if "delayed scl_oen" in lower:
        return "Delayed copy of `scl_oen` for stretch/sync checks."
    if "check sda output" in lower:
        return "Enables SDA arbitration checking during driven bits."
    if "clock generation signals" in lower:
        return "Prescaler tick that advances the bit-level FSM."
    if "clock divider counter" in lower and "filter" not in lower:
        return "Clock-divider counter."
    if "clock divider for filter" in lower:
        return "Clock divider that times the input filter."
    if "enum_state" in lower:
        return None
    return None


def phrase_from_context_comment(sig_name: str, comment: str) -> str | None:
    if not comment:
        return None
    lower = comment.lower()
    name_lower = sig_name.lower()
    if "slave_wait is asserted" in lower:
        return "Indicates that a slave is stretching SCL low."
    if "clock synchronization" in lower:
        return "Clock-synchronization pulse when SCL is held low externally."
    if "dc to sb" in lower or "sb to biu" in lower or "ic to biu" in lower:
        return section_bus_description(comment, sig_name)
    if "cpu's spr access" in lower:
        return None
    if "address of insn to be fetched" in lower and name_lower == "pc":
        return "Next instruction-fetch address."
    return None


def describe_stage(base_desc: str, stage: str) -> str:
    stage_label = stage.upper() if stage.isalpha() else stage
    base_desc = base_desc.rstrip(".")
    if base_desc.lower().startswith("registered "):
        base_desc = base_desc[len("Registered ") :]
    if base_desc.lower().startswith("current "):
        base_desc = base_desc[8:]
    return f"Stage-{stage_label} pipeline copy of the {base_desc[0].lower() + base_desc[1:]}."


def normalize_subject(text: str) -> str:
    text = re.sub(r"\s+", " ", text)
    return text.strip(" .")


def subject_from_tokens(tokens: list[str]) -> str:
    words: list[str] = []
    for token in tokens:
        word = TOKEN_MAP.get(token, token)
        words.append(word)
    return normalize_subject(" ".join(words))


def subject_with_noun(subject: str, noun: str) -> str:
    subject = normalize_subject(subject)
    if subject.endswith(noun):
        return title_case_phrase(subject + ".")
    return title_case_phrase(subject + " " + noun + ".")


def infer_category(tokens: list[str], sig: SignalDecl) -> str:
    token_set = set(tokens)
    if any(token in {"state"} for token in token_set):
        return "state"
    if any(token in {"cnt", "count", "index", "idx", "iteration"} for token in token_set):
        return "counter"
    if any(token in {"addr", "adr", "pc", "pcreg", "epcr", "eear"} for token in token_set):
        return "address"
    if any(token in {"data", "dat", "insn", "operand", "mantissa", "exponent", "expon", "product", "quotient", "remainder", "dividend", "divisor"} for token in token_set):
        return "value"
    if any(token in {"sel", "op", "cmd", "mode", "mux", "cab", "stb", "cyc", "cycstb", "tag", "we"} for token in token_set):
        return "control"
    if any(token in BOOL_HINTS for token in token_set):
        return "flag"
    if not sig.packed and sig.assign is not None:
        return "flag"
    return "value"


def exact_description(module_name: str, sig_name: str) -> str | None:
    module_map = MODULE_EXACT.get(module_name, {})
    if sig_name in module_map:
        return module_map[sig_name]
    return None


def description_from_name(module_name: str, sig: SignalDecl) -> str:
    name = sig.name
    tokens = tokenize(name)
    stage = None

    exact = exact_description(module_name, name)
    if exact:
        return describe_stage(exact, stage) if stage else exact

    if name.endswith("_r") and len(tokens) >= 2:
        base = description_from_name(module_name, SignalDecl(
            name=name[:-2],
            decl_text=sig.decl_text,
            kind=sig.kind,
            packed=sig.packed,
            unpacked=sig.unpacked,
            assign=sig.assign,
            inline_comment=sig.inline_comment,
            context_comment=sig.context_comment,
            line_no=sig.line_no,
        )).rstrip(".")
        return f"One-cycle registered copy of the {base[0].lower() + base[1:]}."

    stage_match = re.match(r"^(.*)_(\d+)$", name)
    if stage_match:
        stage = stage_match.group(2)
        tokens = tokenize(stage_match.group(1))
    else:
        compact_stage = re.match(
            r"^(rm|sign|fpuf|exponent|mantissa_[ab]|product_[a-z]|count_ready)(\d+)$",
            name,
        )
        if compact_stage:
            stage = compact_stage.group(2)
            tokens = tokenize(compact_stage.group(1))

    if "_is_" in name:
        lhs, rhs = name.split("_is_", 1)
        left = subject_from_tokens(tokenize(lhs))
        right = subject_from_tokens(tokenize(rhs))
        return title_case_phrase(f"{left} is {right} flag.") if not stage else describe_stage(title_case_phrase(f"{left} is {right} flag."), stage)

    if "_gt_" in name:
        lhs, rhs = name.split("_gt_", 1)
        left = subject_from_tokens(tokenize(lhs))
        right = subject_from_tokens(tokenize(rhs))
        desc = title_case_phrase(f"{left} greater-than-{right} flag.")
        return describe_stage(desc, stage) if stage else desc

    if re.fullmatch(r"(if|id|ex|wb)_.+", name):
        stage_name, rest = name.split("_", 1)
        desc = title_case_phrase(f"{TOKEN_MAP[stage_name]}-stage {subject_from_tokens(tokenize(rest))}.") 
        return desc

    if re.fullmatch(r"rf_addr[abw]", name):
        port = name[-1].upper()
        if port == "W":
            return "Register-file write address."
        return f"Register-file read address for port {port}."

    if re.fullmatch(r"rf_data[abw]", name):
        port = name[-1].upper()
        if port == "W":
            return "Register-file write data."
        return f"Register-file read data from port {port}."

    if re.fullmatch(r"rf_rd[ab]|rf_r[db]?", name):
        return "Register-file read control."

    if name in {"sel_a", "sel_b"}:
        return f"Operand-{name[-1].upper()} mux select."

    if name in {"operand_a", "operand_b"}:
        return f"Selected operand {name[-1].upper()} value."

    if name in {"alu_op", "comp_op", "branch_op", "lsu_op", "rfwb_op", "shrot_op", "mac_op"}:
        return title_case_phrase(subject_from_tokens(tokens) + " select.")

    if name == "simm":
        return "Sign-extended immediate value."

    if name == "lr_sav":
        return "Saved link-register return address."

    if name in {"wb_forw", "flagforw", "cyforw"}:
        exacts = {
            "wb_forw": "Writeback-forwarding data.",
            "flagforw": "Forwarded condition-flag value.",
            "cyforw": "Forwarded carry-flag value.",
        }
        return exacts[name]

    debug_reg_match = re.fullmatch(r"(dmr|dcr|dvr|dwcr)(\d+)", name)
    if debug_reg_match:
        prefix, idx = debug_reg_match.groups()
        labels = {
            "dmr": "Debug mode register",
            "dcr": "Debug control register",
            "dvr": "Debug value register",
            "dwcr": "Debug watchpoint control register",
        }
        return f"{labels[prefix]} {idx}."

    pp_match = re.fullmatch(r"p(\d+)", name)
    if pp_match:
        return f"Partial-product pipeline register P{pp_match.group(1)}."

    lane_match = re.fullmatch(r"(memdata|regdata)_(hh|hl|lh|ll)", name)
    if lane_match:
        base, lane = lane_match.groups()
        lane_desc = {
            "hh": "[31:24] byte",
            "hl": "[23:16] byte",
            "lh": "[15:8] byte",
            "ll": "[7:0] byte",
        }[lane]
        label = "Memory-data" if base == "memdata" else "Register-data"
        return f"{label} {lane_desc}."

    sel_byte_match = re.fullmatch(r"sel_byte([0-3])", name)
    if sel_byte_match:
        return f"Byte-selector control for output lane {sel_byte_match.group(1)}."

    exact_global = {
        "dbg_is_o": "Encoded external instruction-fetch status.",
        "dbg_ack_o": "Debug acknowledge output register.",
        "dsr": "Debug stop register.",
        "drr": "Debug reason register.",
        "tb_enw": "Trace-buffer write-enable.",
        "tb_wadr": "Trace-buffer write address.",
        "match": "Timer-match flag.",
        "restart": "Counter-restart flag.",
        "stop": "Counter-stop flag.",
        "fault": "Translation-fault flag.",
        "miss": "TLB-miss flag.",
        "page_cross": "Page-crossing flag.",
        "tag_v": "Cache-tag valid bit.",
        "ic_inv": "Instruction-cache invalidate request.",
        "dc_inv": "Data-cache invalidate request.",
        "hitmiss_eval": "Hit/miss evaluation flag.",
        "en_wire": "RAM enable signal.",
        "we_wire": "RAM write-enable signal.",
        "addr_wire": "RAM address signal.",
        "datain_wire": "RAM write-data signal.",
    }
    if name in exact_global:
        return exact_global[name]

    if name in {"add", "subtract", "multiply", "divide"}:
        return f"Flag that the current operation is {name}."

    if name.endswith("_et_zero"):
        base = subject_from_tokens(tokenize(name[:-8]))
        return title_case_phrase(base + " equals-zero flag.")

    if name.endswith("_QNaN"):
        base = subject_from_tokens(tokenize(name[:-5]))
        return title_case_phrase(base + " quiet-NaN flag.")

    if name.endswith("_SNaN"):
        base = subject_from_tokens(tokenize(name[:-5]))
        return title_case_phrase(base + " signaling-NaN flag.")

    if name.endswith("_pos_inf"):
        base = subject_from_tokens(tokenize(name[:-8]))
        return title_case_phrase(base + " positive-infinity flag.")

    if name.endswith("_neg_inf"):
        base = subject_from_tokens(tokenize(name[:-8]))
        return title_case_phrase(base + " negative-infinity flag.")

    extra_exact = {
        "aborted": "Abort flag.",
        "alu_dataout": "ALU result data.",
        "lsu_dataout": "Load/store-unit result data.",
        "sprs_dataout": "SPR subsystem read data.",
        "wbforw_valid": "Writeback-forwarding valid flag.",
        "muxed_a": "Muxed operand-A value.",
        "muxed_b": "Muxed operand-B value.",
        "multicycle": "Multicycle-operation control.",
        "flushpipe": "Pipeline flush request.",
        "extend_flush": "Extended pipeline flush request.",
        "extend_flush_last": "Registered tail of the extended flush sequence.",
        "sig_syscall": "Decoded system-call flag.",
        "sig_trap": "Decoded trap flag.",
        "cust5_op": "Decoded custom-5 operation field.",
        "cust5_limm": "Decoded custom-5 immediate field.",
        "spr_addrimm": "Immediate SPR address field.",
        "to_sr": "Value written into the status register.",
        "rfe": "Exception-return operation flag.",
        "except_start": "Exception-start pulse.",
        "except_started": "Registered exception-start state.",
        "force_dslot_fetch": "Forced delay-slot fetch request.",
        "no_more_dslot": "Delay-slot suppression flag.",
        "id_macrc_op": "Decode-stage MAC read-control flag.",
        "ex_macrc_op": "Execute-stage MAC read-control flag.",
        "ex_void": "Execute-stage void/NOP flag.",
        "flag": "Condition flag.",
        "irq_flag": "Interrupt request flag.",
        "count_out": "Division-iteration countdown.",
        "count_ready": "Ready flag for the completion counter path.",
        "count_nonzero": "Flag that the division count is nonzero.",
        "count_nonzero_reg": "Registered copy of the count-nonzero flag.",
        "enable_reg": "Registered enable flag.",
        "product_shift": "Normalization shift flag for the product path.",
        "expon_a": "Operand-A exponent field.",
        "expon_b": "Operand-B exponent field.",
        "mac": "Multiply-accumulate result.",
    }
    base_name = "_".join(tokens)
    if base_name in extra_exact:
        desc = extra_exact[base_name]
        return describe_stage(desc, stage) if stage else desc
    if name in extra_exact:
        desc = extra_exact[name]
        return describe_stage(desc, stage) if stage else desc

    if re.fullmatch(r"enable_reg_[a-e]", name):
        return f"Phase-{name[-1].upper()} enable flag."

    if name.endswith("_we"):
        base = subject_from_tokens(tokenize(name[:-3]))
        return title_case_phrase(base + " write-enable.")

    if name.endswith("_sel"):
        base = subject_from_tokens(tokenize(name[:-4]))
        return title_case_phrase(base + " select.")

    if name.endswith("_ack"):
        base = subject_from_tokens(tokenize(name[:-4]))
        return title_case_phrase(base + " acknowledge.")

    if name.endswith("_err"):
        base = subject_from_tokens(tokenize(name[:-4]))
        return title_case_phrase(base + " error flag.")

    if name.endswith("_valid"):
        base = subject_from_tokens(tokenize(name[:-6]))
        return title_case_phrase(base + " valid flag.")

    if name.endswith("_ready"):
        base = subject_from_tokens(tokenize(name[:-6]))
        return title_case_phrase(base + " ready flag.")

    if name.endswith("_stall"):
        base = subject_from_tokens(tokenize(name[:-6]))
        return title_case_phrase(base + " stall flag.")

    if name.endswith("_freeze"):
        base = subject_from_tokens(tokenize(name[:-7]))
        return title_case_phrase(base + " freeze control.")

    if name.endswith("_out"):
        base = subject_from_tokens(tokenize(name[:-4]))
        desc = title_case_phrase(base + " output register.")
        return describe_stage(desc, stage) if stage else desc

    if name.endswith("_reg"):
        base = subject_from_tokens(tokenize(name[:-4]))
        desc = title_case_phrase("Registered " + base + ".")
        return describe_stage(desc, stage) if stage else desc

    if name.endswith("_shifted"):
        base = subject_from_tokens(tokenize(name[:-8]))
        desc = title_case_phrase("Shifted " + base + ".")
        return describe_stage(desc, stage) if stage else desc

    if name.endswith("_shift"):
        base = subject_from_tokens(tokenize(name[:-6]))
        desc = title_case_phrase(base + " shift control.")
        return describe_stage(desc, stage) if stage else desc

    if name.endswith("_term") or name.endswith("_terms"):
        base = subject_from_tokens(tokenize(re.sub(r"_terms?$", "", name)))
        desc = title_case_phrase(base + " term.")
        return describe_stage(desc, stage) if stage else desc

    if name.endswith("_index"):
        base = subject_from_tokens(tokenize(name[:-6]))
        return title_case_phrase(base + " index.")

    if name.endswith("_msb"):
        base = subject_from_tokens(tokenize(name[:-4]))
        return title_case_phrase("MSB of the " + base + ".")

    if name.endswith("_lsb"):
        base = subject_from_tokens(tokenize(name[:-4]))
        return title_case_phrase("LSB of the " + base + ".")

    if name.endswith("_ct"):
        base = subject_from_tokens(tokenize(name[:-3]))
        return title_case_phrase(base + " counter.")

    if name.startswith("rm"):
        desc = "Rounding mode."
        return describe_stage(desc, stage) if stage else desc

    if name.startswith("sign"):
        desc = "Result sign bit."
        return describe_stage(desc, stage) if stage else desc

    category = infer_category(tokens, sig)
    subject = subject_from_tokens(tokens)
    if category == "state":
        desc = subject_with_noun(subject, "state")
    elif category == "counter":
        desc = subject_with_noun(subject, "counter")
    elif category == "address":
        desc = title_case_phrase(subject + ".")
    elif category == "control":
        desc = title_case_phrase(subject + ".")
    elif category == "flag":
        desc = subject_with_noun(subject, "flag")
    else:
        desc = title_case_phrase(subject + ".")

    if stage:
        return describe_stage(desc, stage)
    return desc


def final_description(module_name: str, sig: SignalDecl) -> str:
    for candidate in (
        phrase_from_inline_comment(sig.name, sig.inline_comment),
        phrase_from_context_comment(sig.name, sig.context_comment),
        section_bus_description(sig.context_comment, sig.name),
    ):
        if candidate:
            return candidate
    return description_from_name(module_name, sig)


def find_rtl_file(desc_path: Path) -> Path:
    rtl_files = sorted(
        p for p in desc_path.parent.iterdir() if p.suffix in {".v", ".sv"}
    )
    if len(rtl_files) != 1:
        raise RuntimeError(f"expected one RTL file next to {desc_path}, found {len(rtl_files)}")
    return rtl_files[0]


def extract_internal_section(desc_text: str) -> tuple[int, int]:
    marker = "Internal reg/wire signals:"
    start = desc_text.find(marker)
    if start < 0:
        raise RuntimeError("missing internal section")
    section_start = start + len(marker)
    tail = desc_text[section_start:]
    match = re.search(r"\n\s*\n", tail)
    if match:
        return section_start, section_start + match.start()
    return section_start, len(desc_text)


def rewrite_description(desc_path: Path) -> bool:
    text = desc_path.read_text()
    module_name = extract_module_name(text)
    if not module_name or "Internal reg/wire signals:" not in text:
        return False

    section_start, section_end = extract_internal_section(text)
    rtl_path = find_rtl_file(desc_path)
    module_block = extract_module_block(rtl_path.read_text(errors="ignore"), module_name)
    signal_decls = parse_signal_decls(module_block)

    existing_section = text[section_start:section_end]
    existing_lines = [line for line in existing_section.splitlines() if line.strip()]
    if not existing_lines:
        return False
    if existing_lines[0].strip().startswith("none:"):
        return False

    new_lines: list[str] = []
    for signal in signal_decls:
        desc = final_description(module_name, signal)
        new_lines.append(f"    {signal.decl_text}: {desc}")

    new_section = "\n" + "\n".join(new_lines)
    new_text = text[:section_start] + new_section + text[section_end:]
    if new_text == text:
        return False
    desc_path.write_text(new_text)
    return True


def main() -> int:
    changed = 0
    errors: list[str] = []
    for desc_path in sorted(ROOT.glob("**/des/**/description.txt")):
        try:
            if rewrite_description(desc_path):
                changed += 1
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{desc_path}: {exc}")

    print(f"updated {changed} description file(s)")
    if errors:
        print("errors:")
        for err in errors:
            print(f"  - {err}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
