#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import traceback
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence
from urllib import error, request

SYSTEM_PROMPT = """You are an expert RTL designer.
Generate correct, complete Verilog from the provided specification.
Return only the final Verilog source code.
Do not include markdown fences, explanations, TODOs, or placeholders."""

CODE_BLOCK_RE = re.compile(r"```(?:verilog|systemverilog)?\s*(.*?)```", re.IGNORECASE | re.DOTALL)
VERILOG_START_RE = re.compile(r"^\s*(?:`timescale|`include|`define|module\b|/\*|//)", re.MULTILINE)

# Src leaf directories that were renamed after the Des/Result trees were built.
# Without this map a rerun would generate into Result/deepseek/fpu_double/, which
# the verifier cannot map into Des and silently skips.
RESULT_NAME_OVERRIDES = {"fpu_double": "fpu"}

# HTTP statuses that will not succeed on retry.
NON_RETRYABLE_HTTP = {400, 401, 403, 404, 422}


@dataclass(frozen=True)
class GenerationTask:
    description_file: Path
    module_name: str
    top_name: str
    output_dir: Path
    log_dir: Path
    attempt_indices: tuple[int, ...]


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(
        description="Generate Verilog candidates from Src/**/des/**/description.txt into Result/deepseek."
    )
    parser.add_argument("--src-root", type=Path, default=repo_root / "Src")
    parser.add_argument("--codex-root", type=Path, default=repo_root / "Result" / "codex")
    parser.add_argument("--output-root", type=Path, default=repo_root / "Result" / "deepseek")
    parser.add_argument("--log-root", type=Path, default=repo_root / "logs" / "deepseek")
    parser.add_argument("--base-url", default="https://api.deepseek.com")
    parser.add_argument("--model", default="deepseek-v4-pro")
    parser.add_argument(
        "--api-key",
        default=os.environ.get("DEEPSEEK_API_KEY"),
        help="Defaults to DEEPSEEK_API_KEY. (OPENAI_API_KEY is deliberately NOT used: "
        "sending another provider's credential to api.deepseek.com would disclose it.)",
    )
    parser.add_argument(
        "--thinking",
        choices=("enabled", "disabled"),
        default="disabled",
        help="DeepSeek thinking mode. Default disables reasoning output so final code is returned in message.content.",
    )
    parser.add_argument("--temperature", type=float, default=0.8)
    parser.add_argument("--max-tokens", type=int, default=16384)
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--retry-delay", type=float, default=3.0)
    parser.add_argument("--request-delay", type=float, default=0.0)
    parser.add_argument("--samples", type=int, default=1, help="Number of candidates to generate per module.")
    parser.add_argument(
        "--modules",
        nargs="*",
        help="Only generate the listed result module names, for example: cordic or1200_alu mips_alu",
    )
    parser.add_argument("--overwrite", action="store_true", help="Overwrite existing .v files.")
    parser.add_argument("--dry-run", action="store_true", help="Show planned outputs without calling the API.")
    args = parser.parse_args()
    if args.samples < 1:
        parser.error("--samples must be at least 1.")
    return args


def configure_stdio() -> None:
    for stream_name in ("stdout", "stderr"):
        stream = getattr(sys, stream_name, None)
        reconfigure = getattr(stream, "reconfigure", None)
        if callable(reconfigure):
            reconfigure(encoding="utf-8", errors="backslashreplace")


def sanitize_api_key(raw_key: str) -> str:
    key = raw_key.strip()
    quote_pairs = [
        ('"', '"'),
        ("'", "'"),
        ("“", "”"),
        ("‘", "’"),
    ]
    for left, right in quote_pairs:
        if key.startswith(left) and key.endswith(right) and len(key) >= 2:
            key = key[len(left) : len(key) - len(right)].strip()
            break
    return key


def validate_api_key(api_key: str) -> None:
    try:
        api_key.encode("ascii")
    except UnicodeEncodeError as exc:
        preview = repr(api_key[:16])
        raise SystemExit(
            "API key contains non-ASCII characters. "
            f"Sanitized prefix={preview}. "
            "Re-export DEEPSEEK_API_KEY without smart quotes, Chinese punctuation, or hidden Unicode characters."
        ) from exc


def detect_module_name(description_file: Path, src_root: Path, codex_root: Path) -> str:
    relative_parts = description_file.relative_to(src_root).parts
    leaf_name = RESULT_NAME_OVERRIDES.get(description_file.parent.name, description_file.parent.name)

    candidates = [leaf_name]
    if relative_parts and relative_parts[0] == "mips_16":
        candidates.insert(0, f"mips_{leaf_name}")

    for candidate in candidates:
        if (codex_root / candidate).is_dir():
            return candidate
    return candidates[0]


def detect_top_name(description_file: Path) -> str:
    """The module name the candidate must declare: the Des reference top, which is
    the leaf directory name (mips_16 result dirs add a mips_ prefix, but the RTL
    top keeps the bare name, e.g. Result mips_alu -> module alu)."""
    return RESULT_NAME_OVERRIDES.get(description_file.parent.name, description_file.parent.name)


def build_attempt_indices(samples: int) -> tuple[int, ...]:
    return tuple(range(1, samples + 1))


def discover_tasks(
    src_root: Path,
    codex_root: Path,
    output_root: Path,
    log_root: Path,
    samples: int,
    module_filter: set[str] | None,
) -> list[GenerationTask]:
    tasks: list[GenerationTask] = []
    for description_file in sorted(src_root.glob("**/des/**/description.txt")):
        module_name = detect_module_name(description_file, src_root, codex_root)
        if module_filter and module_name not in module_filter:
            continue
        attempt_indices = build_attempt_indices(samples)
        tasks.append(
            GenerationTask(
                description_file=description_file,
                module_name=module_name,
                top_name=detect_top_name(description_file),
                output_dir=output_root / module_name,
                log_dir=log_root / module_name,
                attempt_indices=attempt_indices,
            )
        )
    if module_filter:
        unknown = sorted(module_filter - {task.module_name for task in tasks})
        if unknown:
            raise SystemExit(
                f"--modules names not found in Src: {', '.join(unknown)} "
                "(valid names are result module names, e.g. cordic, or1200_alu, mips_alu)"
            )
    return tasks


def build_user_prompt(top_name: str, description: str) -> str:
    return f"""Generate a Verilog implementation for the module "{top_name}".

Requirements:
- Return only Verilog source code.
- Do not use markdown code fences.
- Do not include explanations before or after the code.
- Produce a complete implementation, not pseudocode.
- Use Verilog-2001 unless the specification clearly requires otherwise.

Specification:
{description.strip()}
"""


def extract_message_content(response_payload: dict) -> str:
    choices = response_payload.get("choices") or []
    if not choices:
        raise RuntimeError(f"API response does not contain choices: {response_payload}")

    choice = choices[0]
    message = choice.get("message") or {}
    content = message.get("content")
    if isinstance(content, str):
        if content:
            return content
        reasoning_content = message.get("reasoning_content")
        finish_reason = choice.get("finish_reason")
        if isinstance(reasoning_content, str) and reasoning_content:
            if finish_reason == "length":
                raise RuntimeError(
                    "DeepSeek returned empty message.content because thinking mode exhausted max_tokens "
                    f"(finish_reason=length, max completion budget consumed by reasoning_content). "
                    "Re-run with --thinking disabled, raise --max-tokens, or shorten the prompt."
                )
            raise RuntimeError(
                "DeepSeek returned reasoning_content but no final message.content. "
                "Re-run with --thinking disabled or inspect the saved response log."
            )
        raise RuntimeError(
            f"DeepSeek returned empty message.content (finish_reason={finish_reason!r}). "
            "Refusing to write an empty candidate file; inspect the saved response log."
        )
    if isinstance(content, list):
        fragments = []
        for part in content:
            if isinstance(part, dict) and isinstance(part.get("text"), str):
                fragments.append(part["text"])
        merged = "".join(fragments)
        if merged:
            return merged
    raise RuntimeError(f"Unable to extract message content from API response: {response_payload}")


def normalize_verilog(raw_text: str) -> str:
    text = raw_text.strip()
    fenced_blocks = CODE_BLOCK_RE.findall(text)
    if fenced_blocks:
        text = fenced_blocks[0].strip()
    elif text.startswith("```"):
        lines = text.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        text = "\n".join(lines).strip()

    match = VERILOG_START_RE.search(text)
    if match and match.start() > 0:
        text = text[match.start():].strip()

    return text + "\n"


class ApiRequestError(RuntimeError):
    pass


def build_request_payload(
    model: str,
    prompt: str,
    temperature: float,
    max_tokens: int,
    thinking: str,
) -> dict:
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ],
        "max_tokens": max_tokens,
        "thinking": {"type": thinking},
    }
    if thinking == "disabled":
        payload["temperature"] = temperature
    return payload


def call_deepseek_api(
    api_key: str,
    base_url: str,
    payload: dict,
    timeout: int,
    retries: int,
    retry_delay: float,
) -> dict:
    url = base_url.rstrip("/") + "/chat/completions"
    body = json.dumps(payload).encode("utf-8")

    last_error: Exception | None = None
    for attempt in range(1, retries + 1):
        req = request.Request(
            url,
            data=body,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with request.urlopen(req, timeout=timeout) as response:
                response_payload = json.loads(response.read().decode("utf-8"))
            return response_payload
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            last_error = ApiRequestError(f"HTTP {exc.code}: {detail}")
            if exc.code in NON_RETRYABLE_HTTP:
                raise last_error from exc
        except Exception as exc:  # noqa: BLE001
            last_error = ApiRequestError(str(exc))

        if attempt < retries:
            time.sleep(retry_delay * attempt)

    assert last_error is not None
    raise last_error


def ensure_api_key(args: argparse.Namespace) -> None:
    if args.dry_run:
        return
    if args.api_key:
        args.api_key = sanitize_api_key(args.api_key)
        validate_api_key(args.api_key)
        return
    raise SystemExit("Missing API key. Set DEEPSEEK_API_KEY or pass --api-key.")


def should_skip(output_file: Path, overwrite: bool) -> bool:
    return output_file.exists() and output_file.stat().st_size > 0 and not overwrite


def write_json_file(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def write_text_file(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def generate_one_file(task: GenerationTask, output_file: Path, args: argparse.Namespace) -> None:
    description = task.description_file.read_text(encoding="utf-8")
    prompt = build_user_prompt(task.top_name, description)
    request_payload = build_request_payload(
        model=args.model,
        prompt=prompt,
        temperature=args.temperature,
        max_tokens=args.max_tokens,
        thinking=args.thinking,
    )
    log_stem = output_file.stem
    request_log = task.log_dir / f"{log_stem}_request.json"
    response_log = task.log_dir / f"{log_stem}_response.json"
    raw_content_log = task.log_dir / f"{log_stem}_raw_content.txt"
    raw_reasoning_log = task.log_dir / f"{log_stem}_reasoning_content.txt"
    normalized_log = task.log_dir / f"{log_stem}_normalized.v"
    error_log = task.log_dir / f"{log_stem}_error.txt"

    task.log_dir.mkdir(parents=True, exist_ok=True)
    write_json_file(
        request_log,
        {
            "description_file": str(task.description_file),
            "output_file": str(output_file),
            "api_url": args.base_url.rstrip("/") + "/chat/completions",
            "request": request_payload,
        },
    )
    try:
        response_payload = call_deepseek_api(
            api_key=args.api_key,
            base_url=args.base_url,
            payload=request_payload,
            timeout=args.timeout,
            retries=args.retries,
            retry_delay=args.retry_delay,
        )
    except Exception as exc:
        write_text_file(error_log, "".join(traceback.format_exception(exc)))
        raise

    if error_log.exists():
        error_log.unlink()

    write_json_file(response_log, response_payload)
    choices = response_payload.get("choices") or []
    message = (choices[0].get("message") or {}) if choices else {}
    reasoning_content = message.get("reasoning_content")
    if isinstance(reasoning_content, str) and reasoning_content:
        write_text_file(
            raw_reasoning_log,
            reasoning_content if reasoning_content.endswith("\n") else reasoning_content + "\n",
        )
    raw_text = extract_message_content(response_payload)
    write_text_file(raw_content_log, raw_text if raw_text.endswith("\n") else raw_text + "\n")

    normalized_text = normalize_verilog(raw_text)
    if not normalized_text.strip():
        raise RuntimeError(
            "normalized candidate is empty after fence stripping; refusing to write "
            f"an empty {output_file.name} (see {raw_content_log})"
        )
    write_text_file(normalized_log, normalized_text)
    output_file.write_text(normalized_text, encoding="utf-8")


def print_plan(tasks: Sequence[GenerationTask], output_root: Path, log_root: Path) -> None:
    file_total = sum(len(task.attempt_indices) for task in tasks)
    print(f"Discovered {len(tasks)} modules and {file_total} target files under {output_root}.")
    print(f"Logs will be stored under {log_root}.")
    for task in tasks:
        attempts = ", ".join(f"t{index}" for index in task.attempt_indices)
        print(f"  {task.module_name}: {task.description_file} -> {task.output_dir} ({attempts})")


def main() -> int:
    configure_stdio()
    args = parse_args()
    ensure_api_key(args)

    module_filter = set(args.modules) if args.modules else None
    tasks = discover_tasks(
        src_root=args.src_root,
        codex_root=args.codex_root,
        output_root=args.output_root,
        log_root=args.log_root,
        samples=args.samples,
        module_filter=module_filter,
    )

    if not tasks:
        print("No matching description.txt files found.", file=sys.stderr)
        return 1

    if args.dry_run:
        print_plan(tasks, args.output_root, args.log_root)
        return 0

    failures: list[tuple[Path, str]] = []
    generated = 0
    skipped = 0

    for task in tasks:
        task.output_dir.mkdir(parents=True, exist_ok=True)
        for attempt_index in task.attempt_indices:
            output_file = task.output_dir / f"{task.module_name}_t{attempt_index}.v"
            if should_skip(output_file, args.overwrite):
                skipped += 1
                print(f"[skip] {output_file}")
                continue

            print(f"[gen] {task.module_name}_t{attempt_index}.v <- {task.description_file}")
            try:
                generate_one_file(task, output_file, args)
                generated += 1
            except Exception as exc:  # noqa: BLE001
                failures.append((output_file, str(exc)))
                print(f"[error] {output_file}: {exc}", file=sys.stderr)

            if args.request_delay > 0:
                time.sleep(args.request_delay)

    print(f"Finished. generated={generated} skipped={skipped} failed={len(failures)}")
    if failures:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
