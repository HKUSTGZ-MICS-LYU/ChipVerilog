#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


TARGET_RE = re.compile(r"^(?P<base>.+)_t(?P<index>\d+)$")


def run_command(cmd: list[str], cwd: Path, timeout: int) -> tuple[bool, str]:
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
        return False, f"Timeout after {timeout}s"

    output = (result.stdout or "") + (result.stderr or "")
    clean_lines = [
        line.rstrip()
        for line in output.splitlines()
        if line.strip() and "setlocale: LC_ALL" not in line
    ]
    clean_output = "\n".join(clean_lines) if clean_lines else "No output"
    return result.returncode == 0, clean_output


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


def equivalence_check(
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
        ok, output = run_command(
            [yosys, "-s", str(script_file)],
            cwd=reference_file.parent,
            timeout=timeout,
        )

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


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Check compile success and formal equivalence for <name>.v and <name>_t*.v."
    )
    parser.add_argument(
        "directory",
        nargs="?",
        default=Path(__file__).resolve().parent.parent / "test" / "verilog" / "fpu_add",
        type=Path,
    )
    parser.add_argument("--depth", type=int, default=12)
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--iverilog", default="iverilog")
    parser.add_argument("--yosys", default="yosys")
    args = parser.parse_args()

    iverilog = shutil.which(args.iverilog)
    yosys = shutil.which(args.yosys)
    if iverilog is None:
        print(f"Tool not found: {args.iverilog}")
        raise SystemExit(2)
    if yosys is None:
        print(f"Tool not found: {args.yosys}")
        raise SystemExit(2)

    directory = args.directory.resolve()
    reference_files = sorted(
        file for file in directory.glob("*.v") if TARGET_RE.match(file.stem) is None
    )
    if not reference_files:
        print(f"No reference Verilog files found in {directory}")
        raise SystemExit(2)

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
                eq_ok, eq_msg = equivalence_check(
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

    raise SystemExit(0 if all_passed else 1)
