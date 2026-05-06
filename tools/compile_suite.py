#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import shutil
import sys
import tempfile
import unittest
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

import formal_equivalence as fe


RTL_PHASE_CHOICES = ("rtl", "result", "both")
CORDIC_MODULES = frozenset({"cordic", "rotator", "signed_shifter"})
DOUBLE_FPU_VERILOG_MODULES = (
    "fpu_add",
    "fpu_div",
    "fpu_double",
    "fpu_exceptions",
    "fpu_mul",
    "fpu_round",
    "fpu_sub",
)
DOUBLE_FPU_PIPELINE_MODULES = {
    "fpu_addsub_pipeline": "fpu_addsub.v",
    "fpu_mul_pipeline": "fpu_mul.v",
}
I2C_MODULES = (
    "i2c_master_bit_ctrl",
    "i2c_master_byte_ctrl",
    "i2c_master_top",
)
MIPS_MODULES = (
    "EX_stage",
    "ID_stage",
    "IF_stage",
    "MEM_stage",
    "WB_stage",
    "alu",
    "data_mem",
    "hazard_detection_unit",
    "instruction_mem",
    "mips_16_core_top",
    "register_file",
)
WARNING_LIMIT = 8


@dataclass(frozen=True)
class RtlTarget:
    family: str
    module_id: str
    reference_file: Path


@dataclass(frozen=True)
class CompileBundle:
    family: str
    module_id: str
    report_reference_file: Path
    compile_reference_file: Path
    expected_top: str | None
    top_error: str | None
    prefix_files: tuple[Path, ...]
    support_files: tuple[Path, ...]
    search_roots: tuple[Path, ...]
    support_context: fe.SupportDesignContext | None


@dataclass(frozen=True)
class RtlCompileTask:
    target: RtlTarget
    bundle: CompileBundle | None
    bundle_error: str | None


@dataclass(frozen=True)
class ResultCompileTask:
    model: str
    module_dir: str
    candidate_file: Path
    bundle: CompileBundle | None
    bundle_error: str | None


@dataclass(frozen=True)
class CompileExecution:
    status: str
    exit_code: int
    warning_count: int
    warning_excerpt: str
    error_excerpt: str


@dataclass(frozen=True)
class RtlReferenceDetailRow:
    family: str
    module_id: str
    reference_file: str
    expected_top: str
    status: str
    exit_code: int
    warning_count: int
    warning_excerpt: str
    error_excerpt: str


@dataclass(frozen=True)
class RtlReferenceSummaryRow:
    family: str
    module_id: str
    status: str
    warning_count: int


@dataclass(frozen=True)
class ResultDetailRow:
    model: str
    family: str
    module_dir: str
    candidate_file: str
    attempt: int | None
    reference_file: str
    expected_top: str
    status: str
    exit_code: int
    warning_count: int
    warning_excerpt: str
    error_excerpt: str


@dataclass(frozen=True)
class ResultSummaryByModelModuleRow:
    family: str
    model: str
    module_dir: str
    observed_candidates: int
    pass_count: int
    fail_count: int
    warning_pass_count: int


@dataclass(frozen=True)
class ResultSummaryByModelRow:
    model: str
    observed_module_count: int
    observed_candidates: int
    pass_count: int
    fail_count: int
    warning_pass_count: int


def require_file(path: Path) -> Path:
    if not path.exists():
        raise FileNotFoundError(f"Required file not found: {path}")
    return path.resolve()


def summarize_lines(lines: list[str], *, limit: int = WARNING_LIMIT) -> str:
    if not lines:
        return ""
    return " | ".join(line.strip() for line in lines[:limit])


def extract_warning_lines(output: str) -> list[str]:
    return [line.strip() for line in output.splitlines() if "warning:" in line.lower()]


def discover_double_fpu_design_files(src_root: Path) -> list[Path]:
    rtl_root = src_root / "double_fpu" / "rtl"
    verilog_root = rtl_root / "verilog"
    pipeline_root = rtl_root / "pipeline"
    if not rtl_root.exists():
        return []
    design_files = [
        require_file(verilog_root / f"{module_id}.v")
        for module_id in DOUBLE_FPU_VERILOG_MODULES
    ]
    design_files.extend(
        require_file(pipeline_root / filename)
        for filename in DOUBLE_FPU_PIPELINE_MODULES.values()
    )
    return design_files


def discover_i2c_design_files(src_root: Path) -> list[Path]:
    verilog_root = src_root / "i2c" / "rtl" / "verilog"
    if not verilog_root.exists():
        return []
    return [require_file(verilog_root / f"{module_id}.v") for module_id in I2C_MODULES]


def discover_mips_design_files(src_root: Path) -> list[Path]:
    rtl_root = src_root / "mips_16" / "trunk" / "rtl"
    if not rtl_root.exists():
        return []
    return [require_file(rtl_root / f"{module_id}.v") for module_id in MIPS_MODULES]


def discover_or1200_design_files(src_root: Path) -> list[Path]:
    verilog_root = src_root / "or1200_hp" / "rtl" / "verilog"
    if not verilog_root.exists():
        return []
    return sorted(
        path.resolve()
        for path in verilog_root.glob("or1200_*.v")
        if path.name != "or1200_defines.v"
    )


def discover_cordic_design_files(src_root: Path) -> list[Path]:
    rtl_root = src_root / "verilog_cordic_core" / "rtl"
    if not rtl_root.exists():
        return []
    return [require_file(rtl_root / f"{module_id}.v") for module_id in sorted(CORDIC_MODULES)]


def discover_family_design_files(family: str, src_root: Path) -> list[Path]:
    if family == "double_fpu":
        return discover_double_fpu_design_files(src_root)
    if family == "i2c":
        return discover_i2c_design_files(src_root)
    if family == "mips_16":
        return discover_mips_design_files(src_root)
    if family == "or1200_hp":
        return discover_or1200_design_files(src_root)
    if family == "verilog_cordic_core":
        return discover_cordic_design_files(src_root)
    raise ValueError(f"Unsupported family: {family}")


def discover_rtl_targets(src_root: Path) -> list[RtlTarget]:
    targets: list[RtlTarget] = []

    for module_id in DOUBLE_FPU_VERILOG_MODULES:
        path = src_root / "double_fpu" / "rtl" / "verilog" / f"{module_id}.v"
        if path.exists():
            targets.append(RtlTarget("double_fpu", module_id, path.resolve()))
    for module_id, filename in DOUBLE_FPU_PIPELINE_MODULES.items():
        path = src_root / "double_fpu" / "rtl" / "pipeline" / filename
        if path.exists():
            targets.append(RtlTarget("double_fpu", module_id, path.resolve()))

    for module_id in I2C_MODULES:
        path = src_root / "i2c" / "rtl" / "verilog" / f"{module_id}.v"
        if path.exists():
            targets.append(RtlTarget("i2c", module_id, path.resolve()))

    for module_id in MIPS_MODULES:
        path = src_root / "mips_16" / "trunk" / "rtl" / f"{module_id}.v"
        if path.exists():
            targets.append(RtlTarget("mips_16", f"mips_{module_id}", path.resolve()))

    for path in discover_or1200_design_files(src_root):
        targets.append(RtlTarget("or1200_hp", path.stem, path.resolve()))

    for module_id in sorted(CORDIC_MODULES):
        path = src_root / "verilog_cordic_core" / "rtl" / f"{module_id}.v"
        if path.exists():
            targets.append(RtlTarget("verilog_cordic_core", module_id, path.resolve()))

    return sorted(targets, key=lambda item: (item.family, item.module_id))


def support_root_for_family(family: str, src_root: Path) -> Path:
    if family == "double_fpu":
        return (src_root / "double_fpu" / "rtl").resolve()
    if family == "i2c":
        return (src_root / "i2c" / "rtl").resolve()
    if family == "mips_16":
        return (src_root / "mips_16" / "trunk").resolve()
    if family == "or1200_hp":
        return (src_root / "or1200_hp" / "rtl").resolve()
    if family == "verilog_cordic_core":
        return (src_root / "verilog_cordic_core" / "rtl").resolve()
    raise ValueError(f"Unsupported family: {family}")


def prefix_files_for_family(family: str, src_root: Path) -> tuple[Path, ...]:
    if family == "i2c":
        root = src_root / "i2c" / "rtl" / "verilog"
        return tuple(
            require_file(root / filename)
            for filename in ("timescale.v", "i2c_master_defines.v")
            if (root / filename).exists()
        )
    if family == "mips_16":
        root = src_root / "mips_16" / "trunk" / "rtl"
        return tuple(
            require_file(root / filename)
            for filename in ("mips_16_defs.v",)
            if (root / filename).exists()
        )
    return tuple()


def guess_family(module_dir: str) -> str:
    if module_dir.startswith("or1200_"):
        return "or1200_hp"
    if module_dir.startswith("i2c_"):
        return "i2c"
    if module_dir.startswith("mips_"):
        return "mips_16"
    if module_dir in CORDIC_MODULES:
        return "verilog_cordic_core"
    if module_dir.startswith("fpu_"):
        return "double_fpu"
    return "unknown"


def resolve_result_reference(module_dir: str, src_root: Path) -> tuple[str, Path]:
    family = guess_family(module_dir)
    if family == "or1200_hp":
        return family, require_file(src_root / "or1200_hp" / "rtl" / "verilog" / f"{module_dir}.v")
    if family == "i2c":
        return family, require_file(src_root / "i2c" / "rtl" / "verilog" / f"{module_dir}.v")
    if family == "mips_16":
        suffix = module_dir[len("mips_") :]
        return family, require_file(src_root / "mips_16" / "trunk" / "rtl" / f"{suffix}.v")
    if family == "verilog_cordic_core":
        return family, require_file(src_root / "verilog_cordic_core" / "rtl" / f"{module_dir}.v")
    if family == "double_fpu":
        if module_dir == "fpu_addsub_pipeline":
            return family, require_file(src_root / "double_fpu" / "rtl" / "pipeline" / "fpu_addsub.v")
        if module_dir == "fpu_mul_pipeline":
            return family, require_file(src_root / "double_fpu" / "rtl" / "pipeline" / "fpu_mul.v")
        return family, require_file(src_root / "double_fpu" / "rtl" / "verilog" / f"{module_dir}.v")
    raise FileNotFoundError(f"Unsupported Result module directory: {module_dir}")


def prepare_rtl_or1200_support_context(
    src_root: Path,
    reference_file: Path,
) -> fe.SupportDesignContext:
    support_root = support_root_for_family("or1200_hp", src_root)
    context = fe.prepare_or1200_support_workspace(support_root, reference_file)

    prefix_files = list(context.prefix_files)
    timescale = support_root / "timescale.v"
    if timescale.exists():
        copied_timescale = context.effective_support_root / timescale.name
        if not copied_timescale.exists():
            shutil.copy2(timescale, copied_timescale)
        prefix_files.insert(0, copied_timescale.resolve())

    return fe.SupportDesignContext(
        cleanup_root=context.cleanup_root,
        effective_support_root=context.effective_support_root,
        prefix_files=tuple(prefix_files),
        support_files=context.support_files,
        proof_support_files=context.proof_support_files,
        reference_file=context.reference_file,
    )


def compute_macro_defines(family: str, source_file: Path) -> tuple[tuple[str, str], ...]:
    if family != "verilog_cordic_core":
        return tuple()
    defined = fe.extract_defined_macros(source_file.read_text(encoding="utf-8", errors="ignore"))
    return tuple(
        (macro_name, macro_value)
        for macro_name, macro_value in fe.CORDIC_TESTBENCH_DEFAULT_DEFINES
        if macro_name not in defined
    )


def dedupe_support_files_by_module_name(support_files: list[Path]) -> list[Path]:
    selected: list[Path] = []
    seen_modules: set[str] = set()
    for support_file in support_files:
        module_names = set(fe.extract_unique_tolerant_module_names(support_file))
        if module_names and module_names.intersection(seen_modules):
            continue
        selected.append(support_file)
        seen_modules.update(module_names)
    return selected


def build_bundle(
    *,
    family: str,
    module_id: str,
    reference_file: Path,
    src_root: Path,
) -> CompileBundle:
    report_reference_file = reference_file.resolve()
    expected_top, top_error = fe.resolve_expected_top(module_id, report_reference_file)

    if family == "or1200_hp":
        support_context = prepare_rtl_or1200_support_context(src_root, report_reference_file)
        compile_reference_file = support_context.reference_file.resolve()
        prefix_files = tuple(path.resolve() for path in support_context.prefix_files)
        support_files = tuple(path.resolve() for path in support_context.support_files)
        search_roots = tuple(
            fe.dedupe_paths([fe.REPO_ROOT, support_context.effective_support_root])
        )
    else:
        support_context = None
        compile_reference_file = report_reference_file
        prefix_files = prefix_files_for_family(family, src_root)
        support_files = tuple(
            path.resolve()
            for path in discover_family_design_files(family, src_root)
            if path.resolve() != report_reference_file
        )
        search_roots = (support_root_for_family(family, src_root),)

    return CompileBundle(
        family=family,
        module_id=module_id,
        report_reference_file=report_reference_file,
        compile_reference_file=compile_reference_file,
        expected_top=expected_top,
        top_error=top_error,
        prefix_files=prefix_files,
        support_files=support_files,
        search_roots=search_roots,
        support_context=support_context,
    )


def build_rtl_tasks(src_root: Path) -> list[RtlCompileTask]:
    tasks: list[RtlCompileTask] = []
    for target in discover_rtl_targets(src_root):
        try:
            bundle = build_bundle(
                family=target.family,
                module_id=target.module_id,
                reference_file=target.reference_file,
                src_root=src_root,
            )
            tasks.append(RtlCompileTask(target=target, bundle=bundle, bundle_error=None))
        except Exception as exc:
            tasks.append(RtlCompileTask(target=target, bundle=None, bundle_error=str(exc)))
    return tasks


def discover_result_tasks(
    *,
    src_root: Path,
    result_root: Path,
    model_filter: str | None,
) -> list[ResultCompileTask]:
    models = fe.discover_compile_models(result_root, model_filter)
    bundle_cache: dict[str, CompileBundle] = {}
    bundle_errors: dict[str, str] = {}
    tasks: list[ResultCompileTask] = []

    for model in models:
        model_root = result_root / model
        for module_path in sorted(path for path in model_root.iterdir() if path.is_dir()):
            module_dir = module_path.name
            if module_dir not in bundle_cache and module_dir not in bundle_errors:
                try:
                    family, reference_file = resolve_result_reference(module_dir, src_root)
                    bundle_cache[module_dir] = build_bundle(
                        family=family,
                        module_id=module_dir,
                        reference_file=reference_file,
                        src_root=src_root,
                    )
                except Exception as exc:
                    bundle_errors[module_dir] = str(exc)

            bundle = bundle_cache.get(module_dir)
            bundle_error = bundle_errors.get(module_dir)
            for candidate_file in sorted(module_path.glob("*.v")):
                tasks.append(
                    ResultCompileTask(
                        model=model,
                        module_dir=module_dir,
                        candidate_file=candidate_file.resolve(),
                        bundle=bundle,
                        bundle_error=bundle_error,
                    )
                )

    return tasks


def cleanup_bundles(bundles: Iterable[CompileBundle]) -> None:
    seen_cleanup_roots: set[Path] = set()
    for bundle in bundles:
        support_context = bundle.support_context
        if support_context is None or support_context.cleanup_root is None:
            continue
        cleanup_root = support_context.cleanup_root.resolve()
        if cleanup_root in seen_cleanup_roots:
            continue
        seen_cleanup_roots.add(cleanup_root)
        shutil.rmtree(cleanup_root, ignore_errors=True)


def execute_compile(
    *,
    family: str,
    top: str,
    source_file: Path,
    prefix_files: tuple[Path, ...],
    support_files: tuple[Path, ...],
    search_roots: tuple[Path, ...],
    support_context: fe.SupportDesignContext | None,
    iverilog: str,
    timeout: int,
) -> CompileExecution:
    filtered_support = fe.filter_compile_support_files(source_file, support_files)
    filtered_support = dedupe_support_files_by_module_name(filtered_support)
    source_files = [*prefix_files, source_file, *filtered_support]
    include_dirs = fe.build_include_dirs(
        source_files,
        list(search_roots),
        [],
        support_context=support_context,
    )
    macro_defines = compute_macro_defines(family, source_file)
    ok, output, exit_code = fe.run_iverilog_compile(
        source_files=source_files,
        include_dirs=include_dirs,
        macro_defines=macro_defines,
        top=top,
        iverilog=iverilog,
        cwd=fe.REPO_ROOT,
        timeout=timeout,
    )
    warning_lines = extract_warning_lines(output)
    return CompileExecution(
        status="pass" if ok else "fail",
        exit_code=exit_code,
        warning_count=len(warning_lines),
        warning_excerpt=summarize_lines(warning_lines),
        error_excerpt=fe.build_compile_error_excerpt(output, ok=ok),
    )


def compile_rtl_task(task: RtlCompileTask, *, iverilog: str, timeout: int) -> RtlReferenceDetailRow:
    target = task.target
    reference_file = target.reference_file.resolve()
    if task.bundle is None:
        return RtlReferenceDetailRow(
            family=target.family,
            module_id=target.module_id,
            reference_file=str(reference_file),
            expected_top="ambiguous_top",
            status="fail",
            exit_code=-2,
            warning_count=0,
            warning_excerpt="",
            error_excerpt=task.bundle_error or "Failed to build compile bundle",
        )

    bundle = task.bundle
    if bundle.expected_top is None:
        return RtlReferenceDetailRow(
            family=bundle.family,
            module_id=bundle.module_id,
            reference_file=str(bundle.report_reference_file),
            expected_top="ambiguous_top",
            status="fail",
            exit_code=-2,
            warning_count=0,
            warning_excerpt="",
            error_excerpt=bundle.top_error or "Failed to resolve top module",
        )

    execution = execute_compile(
        family=bundle.family,
        top=bundle.expected_top,
        source_file=bundle.compile_reference_file,
        prefix_files=bundle.prefix_files,
        support_files=bundle.support_files,
        search_roots=bundle.search_roots,
        support_context=bundle.support_context,
        iverilog=iverilog,
        timeout=timeout,
    )
    return RtlReferenceDetailRow(
        family=bundle.family,
        module_id=bundle.module_id,
        reference_file=str(bundle.report_reference_file),
        expected_top=bundle.expected_top,
        status=execution.status,
        exit_code=execution.exit_code,
        warning_count=execution.warning_count,
        warning_excerpt=execution.warning_excerpt,
        error_excerpt=execution.error_excerpt,
    )


def compile_result_task(
    task: ResultCompileTask,
    *,
    iverilog: str,
    timeout: int,
) -> ResultDetailRow:
    candidate_file = task.candidate_file.resolve()
    if task.bundle is None:
        return ResultDetailRow(
            model=task.model,
            family=guess_family(task.module_dir),
            module_dir=task.module_dir,
            candidate_file=str(candidate_file),
            attempt=fe.parse_attempt(candidate_file.name),
            reference_file="",
            expected_top="ambiguous_top",
            status="fail",
            exit_code=-2,
            warning_count=0,
            warning_excerpt="",
            error_excerpt=task.bundle_error or "Failed to build compile bundle",
        )

    bundle = task.bundle
    if bundle.expected_top is None:
        return ResultDetailRow(
            model=task.model,
            family=bundle.family,
            module_dir=task.module_dir,
            candidate_file=str(candidate_file),
            attempt=fe.parse_attempt(candidate_file.name),
            reference_file=str(bundle.report_reference_file),
            expected_top="ambiguous_top",
            status="fail",
            exit_code=-2,
            warning_count=0,
            warning_excerpt="",
            error_excerpt=bundle.top_error or "Failed to resolve top module",
        )

    execution = execute_compile(
        family=bundle.family,
        top=bundle.expected_top,
        source_file=candidate_file,
        prefix_files=bundle.prefix_files,
        support_files=bundle.support_files,
        search_roots=bundle.search_roots,
        support_context=bundle.support_context,
        iverilog=iverilog,
        timeout=timeout,
    )
    return ResultDetailRow(
        model=task.model,
        family=bundle.family,
        module_dir=task.module_dir,
        candidate_file=str(candidate_file),
        attempt=fe.parse_attempt(candidate_file.name),
        reference_file=str(bundle.report_reference_file),
        expected_top=bundle.expected_top,
        status=execution.status,
        exit_code=execution.exit_code,
        warning_count=execution.warning_count,
        warning_excerpt=execution.warning_excerpt,
        error_excerpt=execution.error_excerpt,
    )


def run_parallel(items: list, worker, *, jobs: int) -> list:
    if not items:
        return []
    max_workers = max(1, jobs)
    if max_workers == 1:
        return [worker(item) for item in items]
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        return list(executor.map(worker, items))


def write_csv(path: Path, rows: list[object], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(asdict(row))


def build_rtl_summary_rows(rows: list[RtlReferenceDetailRow]) -> list[RtlReferenceSummaryRow]:
    return [
        RtlReferenceSummaryRow(
            family=row.family,
            module_id=row.module_id,
            status=row.status,
            warning_count=row.warning_count,
        )
        for row in rows
    ]


def build_result_summary_rows(
    rows: list[ResultDetailRow],
) -> tuple[list[ResultSummaryByModelModuleRow], list[ResultSummaryByModelRow]]:
    by_model_module: dict[tuple[str, str], list[ResultDetailRow]] = defaultdict(list)
    for row in rows:
        by_model_module[(row.model, row.module_dir)].append(row)

    module_rows: list[ResultSummaryByModelModuleRow] = []
    for model, module_dir in sorted(by_model_module):
        group = by_model_module[(model, module_dir)]
        family = group[0].family
        pass_count = sum(1 for row in group if row.status == "pass")
        fail_count = sum(1 for row in group if row.status == "fail")
        warning_pass_count = sum(
            1 for row in group if row.status == "pass" and row.warning_count > 0
        )
        module_rows.append(
            ResultSummaryByModelModuleRow(
                family=family,
                model=model,
                module_dir=module_dir,
                observed_candidates=len(group),
                pass_count=pass_count,
                fail_count=fail_count,
                warning_pass_count=warning_pass_count,
            )
        )

    by_model: dict[str, list[ResultSummaryByModelModuleRow]] = defaultdict(list)
    for row in module_rows:
        by_model[row.model].append(row)

    model_rows: list[ResultSummaryByModelRow] = []
    for model in sorted(by_model):
        group = by_model[model]
        model_rows.append(
            ResultSummaryByModelRow(
                model=model,
                observed_module_count=len(group),
                observed_candidates=sum(row.observed_candidates for row in group),
                pass_count=sum(row.pass_count for row in group),
                fail_count=sum(row.fail_count for row in group),
                warning_pass_count=sum(row.warning_pass_count for row in group),
            )
        )

    return module_rows, model_rows


def print_rtl_summary(rows: list[RtlReferenceDetailRow]) -> None:
    total = len(rows)
    pass_count = sum(1 for row in rows if row.status == "pass")
    fail_count = total - pass_count
    warning_pass_count = sum(
        1 for row in rows if row.status == "pass" and row.warning_count > 0
    )
    print(f"RTL reference compile: total={total} pass={pass_count} fail={fail_count} warning_pass={warning_pass_count}")
    failing_modules = [row.module_id for row in rows if row.status == "fail"]
    if failing_modules:
        print("RTL failing modules: " + ", ".join(failing_modules))


def print_result_summary(rows: list[ResultDetailRow]) -> None:
    total = len(rows)
    pass_count = sum(1 for row in rows if row.status == "pass")
    fail_count = total - pass_count
    warning_pass_count = sum(
        1 for row in rows if row.status == "pass" and row.warning_count > 0
    )
    print(f"Result compile: total={total} pass={pass_count} fail={fail_count} warning_pass={warning_pass_count}")

    _, model_rows = build_result_summary_rows(rows)
    for row in model_rows:
        print(
            f"  {row.model}: modules={row.observed_module_count} "
            f"candidates={row.observed_candidates} pass={row.pass_count} "
            f"fail={row.fail_count} warning_pass={row.warning_pass_count}"
        )


def rtl_report_paths(report_dir: Path) -> tuple[Path, Path]:
    return (
        report_dir / "rtl_reference_detail.csv",
        report_dir / "rtl_reference_summary.csv",
    )


def result_report_paths(report_dir: Path) -> tuple[Path, Path, Path]:
    return (
        report_dir / "result_detail.csv",
        report_dir / "result_summary_by_model_module.csv",
        report_dir / "result_summary_by_model.csv",
    )


def run_rtl_phase(
    *,
    src_root: Path,
    report_dir: Path,
    iverilog: str,
    timeout: int,
    jobs: int,
) -> tuple[list[RtlReferenceDetailRow], int]:
    tasks = build_rtl_tasks(src_root)
    bundles = [task.bundle for task in tasks if task.bundle is not None]
    try:
        rows = run_parallel(
            tasks,
            lambda task: compile_rtl_task(task, iverilog=iverilog, timeout=timeout),
            jobs=jobs,
        )
    finally:
        cleanup_bundles(bundles)

    detail_rows = sorted(rows, key=lambda row: (row.family, row.module_id))
    summary_rows = build_rtl_summary_rows(detail_rows)
    detail_path, summary_path = rtl_report_paths(report_dir)
    write_csv(detail_path, detail_rows, list(RtlReferenceDetailRow.__annotations__.keys()))
    write_csv(summary_path, summary_rows, list(RtlReferenceSummaryRow.__annotations__.keys()))
    print_rtl_summary(detail_rows)

    exit_code = 0 if all(row.status == "pass" for row in detail_rows) else 1
    return detail_rows, exit_code


def run_result_phase(
    *,
    src_root: Path,
    result_root: Path,
    report_dir: Path,
    model_filter: str | None,
    iverilog: str,
    timeout: int,
    jobs: int,
) -> tuple[list[ResultDetailRow], int]:
    tasks = discover_result_tasks(src_root=src_root, result_root=result_root, model_filter=model_filter)
    bundles = []
    seen_modules: set[str] = set()
    for task in tasks:
        if task.bundle is None or task.module_dir in seen_modules:
            continue
        seen_modules.add(task.module_dir)
        bundles.append(task.bundle)

    try:
        rows = run_parallel(
            tasks,
            lambda task: compile_result_task(task, iverilog=iverilog, timeout=timeout),
            jobs=jobs,
        )
    finally:
        cleanup_bundles(bundles)

    detail_rows = sorted(
        rows,
        key=lambda row: (row.model, row.module_dir, row.attempt or 0, row.candidate_file),
    )
    summary_by_model_module, summary_by_model = build_result_summary_rows(detail_rows)
    detail_path, module_summary_path, model_summary_path = result_report_paths(report_dir)
    write_csv(detail_path, detail_rows, list(ResultDetailRow.__annotations__.keys()))
    write_csv(
        module_summary_path,
        summary_by_model_module,
        list(ResultSummaryByModelModuleRow.__annotations__.keys()),
    )
    write_csv(
        model_summary_path,
        summary_by_model,
        list(ResultSummaryByModelRow.__annotations__.keys()),
    )
    print_result_summary(detail_rows)

    exit_code = 0 if all(row.status == "pass" for row in detail_rows) else 1
    return detail_rows, exit_code


def run_pipeline(args: argparse.Namespace) -> int:
    src_root = args.src_root.resolve()
    report_dir = args.report_dir.resolve()
    result_root = args.result_root.resolve()
    report_dir.mkdir(parents=True, exist_ok=True)

    if shutil.which(args.iverilog) is None:
        print(f"iverilog executable not found: {args.iverilog}", file=sys.stderr)
        return 2

    if args.phase == "rtl":
        _, exit_code = run_rtl_phase(
            src_root=src_root,
            report_dir=report_dir,
            iverilog=args.iverilog,
            timeout=args.timeout,
            jobs=args.jobs,
        )
        return exit_code

    if args.phase == "result":
        _, exit_code = run_result_phase(
            src_root=src_root,
            result_root=result_root,
            report_dir=report_dir,
            model_filter=args.model,
            iverilog=args.iverilog,
            timeout=args.timeout,
            jobs=args.jobs,
        )
        return exit_code

    _, rtl_exit_code = run_rtl_phase(
        src_root=src_root,
        report_dir=report_dir,
        iverilog=args.iverilog,
        timeout=args.timeout,
        jobs=args.jobs,
    )
    if rtl_exit_code != 0:
        print("Skipping Result phase because RTL reference compile failed.", file=sys.stderr)
        return 1

    _, result_exit_code = run_result_phase(
        src_root=src_root,
        result_root=result_root,
        report_dir=report_dir,
        model_filter=args.model,
        iverilog=args.iverilog,
        timeout=args.timeout,
        jobs=args.jobs,
    )
    return result_exit_code


class CompileSuiteTests(unittest.TestCase):
    def write_file(self, path: Path, text: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def test_discover_double_fpu_design_files_excludes_tb(self) -> None:
        with tempfile.TemporaryDirectory(prefix="compile_suite_double_fpu_") as tempdir:
            src_root = Path(tempdir)
            verilog_root = src_root / "double_fpu" / "rtl" / "verilog"
            pipeline_root = src_root / "double_fpu" / "rtl" / "pipeline"
            for module_id in DOUBLE_FPU_VERILOG_MODULES:
                self.write_file(verilog_root / f"{module_id}.v", f"module {module_id}; endmodule\n")
            for filename in DOUBLE_FPU_PIPELINE_MODULES.values():
                module_name = Path(filename).stem
                self.write_file(pipeline_root / filename, f"module {module_name}; endmodule\n")
            self.write_file(verilog_root / "fpu_TB.v", "module fpu_TB; endmodule\n")
            self.write_file(pipeline_root / "fpu_addsub_TB.v", "module fpu_addsub_TB; endmodule\n")
            self.write_file(pipeline_root / "fpu_mul_TB.v", "module fpu_mul_TB; endmodule\n")

            discovered = discover_family_design_files("double_fpu", src_root)
            names = {path.name for path in discovered}
            self.assertIn("fpu_add.v", names)
            self.assertIn("fpu_mul.v", names)
            self.assertIn("fpu_addsub.v", names)
            self.assertNotIn("fpu_TB.v", names)
            self.assertNotIn("fpu_addsub_TB.v", names)
            self.assertNotIn("fpu_mul_TB.v", names)

    def test_resolve_expected_top_aliases(self) -> None:
        with tempfile.TemporaryDirectory(prefix="compile_suite_top_alias_") as tempdir:
            root = Path(tempdir)
            fpu_double = root / "fpu_double.v"
            fpu_pipeline = root / "fpu_addsub.v"
            mips = root / "EX_stage.v"
            cordic = root / "cordic.v"
            self.write_file(fpu_double, "module fpu; endmodule\n")
            self.write_file(fpu_pipeline, "module fpu_addsub; endmodule\n")
            self.write_file(mips, "module EX_stage; endmodule\n")
            self.write_file(
                cordic,
                "module signed_shifter; endmodule\nmodule rotator; endmodule\nmodule cordic; endmodule\n",
            )
            self.assertEqual(fe.resolve_expected_top("fpu_double", fpu_double), ("fpu", None))
            self.assertEqual(
                fe.resolve_expected_top("fpu_addsub_pipeline", fpu_pipeline),
                ("fpu_addsub", None),
            )
            self.assertEqual(fe.resolve_expected_top("mips_EX_stage", mips), ("EX_stage", None))
            self.assertEqual(fe.resolve_expected_top("cordic", cordic), ("cordic", None))

    def test_compute_cordic_macro_defines_injects_missing_macros(self) -> None:
        with tempfile.TemporaryDirectory(prefix="compile_suite_cordic_macro_") as tempdir:
            candidate = Path(tempdir) / "rotator_t4.v"
            self.write_file(
                candidate,
                "module rotator(input signed [`XY_BITS:0] x_i, output signed [`XY_BITS:0] x_o); endmodule\n",
            )
            macro_names = {name for name, _ in compute_macro_defines("verilog_cordic_core", candidate)}
            self.assertIn("XY_BITS", macro_names)
            self.assertIn("THETA_BITS", macro_names)
            self.assertIn("ITERATION_BITS", macro_names)

    def test_error_excerpt_prefers_errors_over_warnings(self) -> None:
        output = "\n".join(
            [
                "foo.v:1: warning: macro XY_BITS undefined",
                "foo.v:2: warning: macro THETA_BITS undefined",
                "foo.v:9: syntax error",
                "foo.v:1: Errors in port declarations",
            ]
        )
        excerpt = fe.build_compile_error_excerpt(output, ok=False)
        self.assertIn("syntax error", excerpt)
        self.assertIn("Errors in port declarations", excerpt)
        self.assertNotIn("warning: macro XY_BITS undefined", excerpt)

    def test_dedupe_support_files_by_module_name_skips_duplicate_support(self) -> None:
        with tempfile.TemporaryDirectory(prefix="compile_suite_support_dedupe_") as tempdir:
            root = Path(tempdir)
            keep = root / "keep.v"
            drop = root / "drop.v"
            other = root / "other.v"
            self.write_file(keep, "module fpu_mul; endmodule\n")
            self.write_file(drop, "module fpu_mul; endmodule\n")
            self.write_file(other, "module helper; endmodule\n")
            deduped = dedupe_support_files_by_module_name([keep, drop, other])
            self.assertEqual(deduped, [keep, other])

    def test_smoke_both_phases_write_reports(self) -> None:
        with tempfile.TemporaryDirectory(prefix="compile_suite_smoke_") as tempdir:
            root = Path(tempdir)
            src_root = root / "Src"
            result_root = root / "Result"
            report_dir = root / "reports"
            i2c_root = src_root / "i2c" / "rtl" / "verilog"

            self.write_file(i2c_root / "timescale.v", "`timescale 1ns/1ps\n")
            self.write_file(i2c_root / "i2c_master_defines.v", "`define I2C_DEF 1\n")
            self.write_file(i2c_root / "i2c_master_bit_ctrl.v", "module i2c_master_bit_ctrl; endmodule\n")
            self.write_file(
                i2c_root / "i2c_master_byte_ctrl.v",
                "module i2c_master_byte_ctrl; i2c_master_bit_ctrl u_bit(); endmodule\n",
            )
            self.write_file(
                i2c_root / "i2c_master_top.v",
                "module i2c_master_top; i2c_master_byte_ctrl u_byte(); endmodule\n",
            )
            self.write_file(
                result_root / "model_a" / "i2c_master_top" / "i2c_master_top_t1.v",
                "module i2c_master_top; i2c_master_byte_ctrl u_byte(); endmodule\n",
            )

            rtl_rows, rtl_exit_code = run_rtl_phase(
                src_root=src_root,
                report_dir=report_dir,
                iverilog="iverilog",
                timeout=30,
                jobs=1,
            )
            self.assertEqual(rtl_exit_code, 0)
            self.assertEqual(len(rtl_rows), 3)

            result_rows, result_exit_code = run_result_phase(
                src_root=src_root,
                result_root=result_root,
                report_dir=report_dir,
                model_filter=None,
                iverilog="iverilog",
                timeout=30,
                jobs=1,
            )
            self.assertEqual(result_exit_code, 0)
            self.assertEqual(len(result_rows), 1)

            expected_reports = [
                report_dir / "rtl_reference_detail.csv",
                report_dir / "rtl_reference_summary.csv",
                report_dir / "result_detail.csv",
                report_dir / "result_summary_by_model_module.csv",
                report_dir / "result_summary_by_model.csv",
            ]
            for report in expected_reports:
                self.assertTrue(report.exists(), msg=f"Missing report {report}")


def run_selftest() -> int:
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(CompileSuiteTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    return 0 if result.wasSuccessful() else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="RTL-first iverilog compile suite")
    parser.add_argument("command", nargs="?", choices=("run", "selftest"), default="run")
    parser.add_argument("--phase", choices=RTL_PHASE_CHOICES, default="both")
    parser.add_argument("--src-root", type=Path, default=fe.REPO_ROOT / "Src")
    parser.add_argument("--result-root", type=Path, default=fe.REPO_ROOT / "Result")
    parser.add_argument("--report-dir", type=Path, default=fe.REPO_ROOT / "reports" / "compile_suite")
    parser.add_argument("--model")
    parser.add_argument("--iverilog", default="iverilog")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--jobs", type=int, default=4)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command == "selftest":
        return run_selftest()
    return run_pipeline(args)


if __name__ == "__main__":
    raise SystemExit(main())
