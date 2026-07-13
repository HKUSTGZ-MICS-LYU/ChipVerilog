#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SRC_ROOT_DEFAULT="${SCRIPT_DIR}/Description"
TMP_ROOT_DEFAULT="${SCRIPT_DIR}/.codex_batch_work"
LOG_ROOT_DEFAULT="${SCRIPT_DIR}/.codex_batch_logs"
OUT_ROOT_DEFAULT="${SCRIPT_DIR}/Result/codex"
CODEX_BIN_DEFAULT="${CODEX_BIN:-codex}"
SYSTEM_PROMPT_DEFAULT="Please act as a professional verilog designer."
MODEL_DEFAULT="gpt-5.4"
EFFORT_DEFAULT="high"
SUFFIX_DEFAULT="t1"

usage() {
  cat <<'USAGE'
Usage:
  ./run_codex_batch_txt.sh [options]

Generate one Verilog file for each .txt file directly under Description.
Each .txt file is processed in a fresh Codex invocation with an isolated
workspace. The full text of each .txt file is embedded directly into the
Codex prompt.

Options:
  --src-root PATH         Directory containing per-module .txt files
  --tmp-root PATH         Temporary root for isolated Codex workspaces
  --log-root PATH         Root directory for per-module logs
  --out-root PATH         Root directory for generated Verilog output folders
  --module NAME           Process only one txt file, matched by filename without .txt
  --model MODEL           Codex model to use (default: gpt-5.4)
  --effort LEVEL          Codex reasoning effort (low|medium|high|xhigh, default: high)
  --suffix NAME           Output suffix before .v (default: t1)
  --codex-bin PATH        Codex CLI binary or command name
  --terminal-bin PATH     Terminal emulator command to use
  --no-terminal           Run in the current terminal instead of separate terminals (default)
  --terminal              Use separate GUI terminal windows if available
  --sequential            Wait for each module to finish before launching the next (default)
  --parallel              Launch all module terminals immediately; not recommended on HPC
  --sleep SECONDS         Sleep between modules in sequential mode to reduce rate-limit risk
  --keep-terminal-open    Keep each terminal open after the module finishes
  --force                 Regenerate outputs even if the target file already exists
  --fail-fast             Stop immediately on the first module failure
  --dry-run               Show planned work without calling Codex
  -h, --help              Show this help

Environment:
  CODEX_BIN              Default Codex CLI binary if --codex-bin is omitted
  SYSTEM_PROMPT          Override the default system prompt text
  TERMINAL_BIN           Default terminal emulator if --terminal-bin is omitted

Notes:
  - Run `codex login` before using this script.
  - Input layout should be:
      Description/a.txt
      Description/b.txt
      Description/c.txt
  - Output files are written into separate folders under OUT_ROOT as:
      Result/codex/a/a_t1.v
      Result/codex/b/b_t1.v
      Result/codex/c/c_t1.v
  - Each txt file is embedded directly into the prompt passed to Codex.
  - The script explicitly forces `gpt-5.4` with reasoning effort `high`
    unless you override them with --model or --effort.
  - By default, if the target output file already exists under OUT_ROOT, that
    module is skipped instead of being regenerated.
  - By default, the batch continues even if one module fails. The script
    reports all failures at the end and exits non-zero if any module failed.

Examples:
  ./run_codex_batch_txt.sh
  ./run_codex_batch_txt.sh --module fpu_add_description
  ./run_codex_batch_txt.sh --out-root Result/codex
  ./run_codex_batch_txt.sh --force
  ./run_codex_batch_txt.sh --fail-fast
  ./run_codex_batch_txt.sh --out-root Result/codex --suffix t14
USAGE
}

SRC_ROOT="${SRC_ROOT_DEFAULT}"
TMP_ROOT="${TMP_ROOT_DEFAULT}"
LOG_ROOT="${LOG_ROOT_DEFAULT}"
OUT_ROOT="${OUT_ROOT_DEFAULT}"
MODULE_FILTER=""
MODEL="${MODEL_DEFAULT}"
EFFORT="${EFFORT_DEFAULT}"
OUTPUT_SUFFIX="${SUFFIX_DEFAULT}"
CODEX_BIN="${CODEX_BIN_DEFAULT}"
TERMINAL_BIN="${TERMINAL_BIN:-}"
SYSTEM_PROMPT="${SYSTEM_PROMPT:-${SYSTEM_PROMPT_DEFAULT}}"
DRY_RUN=0
FAIL_FAST=0
FORCE_REGENERATE=0
USE_TERMINAL=0
SEQUENTIAL=1
SLEEP_SECONDS=0
KEEP_TERMINAL_OPEN=0
INTERNAL_RUN=0
INTERNAL_TX_FILE=""
INTERNAL_MODULE_NAME=""

quote_args() {
  local out=""
  local arg
  for arg in "$@"; do
    printf -v arg '%q' "$arg"
    out+=" ${arg}"
  done
  printf '%s' "${out# }"
}

find_terminal() {
  if [[ -n "${TERMINAL_BIN}" ]]; then
    printf '%s\n' "${TERMINAL_BIN}"
    return 0
  fi

  local candidate
  for candidate in \
    gnome-terminal \
    konsole \
    xfce4-terminal \
    mate-terminal \
    xterm \
    kitty \
    alacritty \
    wezterm \
    x-terminal-emulator; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

terminal_exec() {
  local terminal=$1
  local title=$2
  shift 2
  local command_line
  command_line=$(quote_args "$@")

  case "$(basename -- "${terminal}")" in
    gnome-terminal)
      "${terminal}" --title="${title}" -- bash -lc "${command_line}" &
      ;;
    konsole)
      "${terminal}" --new-tab --title "${title}" -e bash -lc "${command_line}" &
      ;;
    xfce4-terminal|mate-terminal)
      # -x passes the remaining arguments as the command; avoids nested-quote breakage.
      "${terminal}" --title="${title}" -x bash -lc "${command_line}" &
      ;;
    xterm)
      "${terminal}" -T "${title}" -e bash -lc "${command_line}" &
      ;;
    kitty)
      "${terminal}" --title "${title}" bash -lc "${command_line}" &
      ;;
    alacritty)
      "${terminal}" --title "${title}" -e bash -lc "${command_line}" &
      ;;
    wezterm)
      "${terminal}" start --cwd "${SCRIPT_DIR}" -- bash -lc "${command_line}" &
      ;;
    x-terminal-emulator)
      "${terminal}" -T "${title}" -e bash -lc "${command_line}" &
      ;;
    *)
      "${terminal}" -e bash -lc "${command_line}" &
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src-root)
      SRC_ROOT="$2"
      shift 2
      ;;
    --tmp-root)
      TMP_ROOT="$2"
      shift 2
      ;;
    --log-root)
      LOG_ROOT="$2"
      shift 2
      ;;
    --out-root)
      OUT_ROOT="$2"
      shift 2
      ;;
    --module)
      MODULE_FILTER="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    --effort|--reasoning-effort)
      EFFORT="$2"
      shift 2
      ;;
    --suffix)
      OUTPUT_SUFFIX="$2"
      shift 2
      ;;
    --codex-bin)
      CODEX_BIN="$2"
      shift 2
      ;;
    --terminal-bin)
      TERMINAL_BIN="$2"
      shift 2
      ;;
    --no-terminal)
      USE_TERMINAL=0
      shift
      ;;
    --terminal)
      USE_TERMINAL=1
      shift
      ;;
    --sleep)
      SLEEP_SECONDS="$2"
      shift 2
      ;;
    --sequential)
      SEQUENTIAL=1
      shift
      ;;
    --parallel)
      SEQUENTIAL=0
      shift
      ;;
    --keep-terminal-open)
      KEEP_TERMINAL_OPEN=1
      shift
      ;;
    --force)
      FORCE_REGENERATE=1
      shift
      ;;
    --fail-fast)
      FAIL_FAST=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --internal-run-txt|--internal-run-module)
      INTERNAL_RUN=1
      INTERNAL_TX_FILE="$2"
      INTERNAL_MODULE_NAME="$3"
      shift 3
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! "${SLEEP_SECONDS}" =~ ^[0-9]+$ ]]; then
  echo "--sleep must be a non-negative integer number of seconds" >&2
  exit 1
fi

if [[ -z "${OUTPUT_SUFFIX}" || ! "${OUTPUT_SUFFIX}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "--suffix must match [A-Za-z0-9._-]+" >&2
  exit 1
fi

if [[ -n "${EFFORT}" && ! "${EFFORT}" =~ ^(low|medium|high|xhigh)$ ]]; then
  echo "--effort must be one of: low, medium, high, xhigh" >&2
  exit 1
fi

if [[ ! -d "${SRC_ROOT}" ]]; then
  echo "Source root does not exist: ${SRC_ROOT}" >&2
  exit 1
fi

if [[ "${CODEX_BIN}" == */* ]]; then
  if [[ ! -x "${CODEX_BIN}" ]]; then
    echo "Codex CLI is not executable: ${CODEX_BIN}" >&2
    exit 1
  fi
elif ! command -v "${CODEX_BIN}" >/dev/null 2>&1; then
  echo "Codex CLI not found in PATH: ${CODEX_BIN}" >&2
  exit 1
fi

mkdir -p "${TMP_ROOT}" "${LOG_ROOT}" "${OUT_ROOT}"

normalize_module_name() {
  local raw_name=$1
  if [[ "${raw_name}" == *_description ]]; then
    printf '%s\n' "${raw_name%_description}"
    return 0
  fi
  printf '%s\n' "${raw_name}"
}

safe_module_name() {
  local module_name=$1
  printf '%s' "${module_name}" | tr '/[:space:]' '___'
}

module_output_name() {
  local module_name=$1
  printf '%s\n' "${module_name}_${OUTPUT_SUFFIX}.v"
}

module_output_dir() {
  local module_name=$1
  local safe_name
  safe_name=$(safe_module_name "${module_name}")
  printf '%s\n' "${OUT_ROOT}/${safe_name}"
}

module_output_path() {
  local module_name=$1
  local output_dir
  local output_name
  output_dir=$(module_output_dir "${module_name}")
  output_name=$(module_output_name "${module_name}")
  printf '%s\n' "${output_dir}/${output_name}"
}

module_status_path() {
  local module_name=$1
  local safe_name
  safe_name=$(safe_module_name "${module_name}")
  printf '%s\n' "${LOG_ROOT}/${safe_name}_${OUTPUT_SUFFIX}.status"
}

run_module() {
  local txt_file=$1
  local module_name=$2
  local workspace
  local output_name
  local output_path
  local output_dir
  local description_content
  local prompt
  local log_path
  local response_path
  local raw_log_path
  local safe_module_name
  local -a codex_args

  safe_module_name=$(safe_module_name "${module_name}")
  output_name=$(module_output_name "${module_name}")
  output_dir=$(module_output_dir "${module_name}")
  output_path=$(module_output_path "${module_name}")
  workspace=$(mktemp -d "${TMP_ROOT}/${safe_module_name}_XXXXXX")
  log_path="${LOG_ROOT}/${safe_module_name}.log"
  response_path="${workspace}/codex_last_message.txt"
  raw_log_path="${LOG_ROOT}/${safe_module_name}.codex_raw.log"
  description_content=$(<"${txt_file}")

  prompt=$(cat <<PROMPT_EOF
${SYSTEM_PROMPT}

This task is fully independent from every other module.
You are running in a separate terminal/session and an isolated workspace for module ${module_name}.

Task: generate one synthesizable Verilog implementation and write it to:
./${output_name}

Use only this embedded specification. Do not inspect or use any other files.

Requirements:
- Plain Verilog only.
- Synthesizable RTL.
- No Markdown.
- No TODOs or placeholders.
- If no module name is specified, use ${module_name}.
- Keep the implementation simple and direct.
- Create only ./${output_name}.
- Do not perform extra exploration; write the RTL directly.

Specification:
${description_content}

Final response:
- Only report whether ./${output_name} was written successfully.
PROMPT_EOF
)

  if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "[dry-run] ${module_name}"
    echo "  description: ${txt_file}"
    echo "  output folder: ${output_dir}"
    echo "  output: ${output_path}"
    echo "  workspace: ${workspace}"
    echo "  model: ${MODEL}"
    echo "  effort: ${EFFORT}"
    echo "  prompt contains $(printf '%s' "${description_content}" | wc -c | tr -d ' ') bytes from ${txt_file}"
    rm -rf "${workspace}"
    return 0
  fi

  {
    echo "processing ${module_name}"
    echo "description: ${txt_file}"
    echo "output folder: ${output_dir}"
    echo "output: ${output_path}"
    echo "workspace: ${workspace}"
    echo "log: ${log_path}"
    echo "raw codex log: ${raw_log_path}"
    echo "model: ${MODEL}"
    echo "effort: ${EFFORT}"
    echo "suffix: ${OUTPUT_SUFFIX}"
    echo
  } | tee "${log_path}"

  codex_args=(
    exec
    --skip-git-repo-check
    --sandbox workspace-write
    --color never
    --output-last-message "${response_path}"
    --ephemeral
    -m "${MODEL}"
    -c "model_reasoning_effort=\"${EFFORT}\""
    -c 'approval_policy="never"'
    -
  )

  if ! (
    cd "${workspace}"
    printf '%s' "${prompt}" | "${CODEX_BIN}" "${codex_args[@]}" > "${raw_log_path}" 2>&1
  ); then
    echo "Codex failed for module ${module_name}. Workspace kept at ${workspace}" | tee -a "${log_path}" >&2
    if [[ -f "${response_path}" ]]; then
      echo "Last Codex message:" | tee -a "${log_path}" >&2
      sed -n '1,120p' "${response_path}" | tee -a "${log_path}" >&2
    fi
    echo "Raw Codex log: ${raw_log_path}" | tee -a "${log_path}" >&2
    return 1
  fi

  if [[ ! -f "${workspace}/${output_name}" ]]; then
    echo "Expected output file was not created: ${workspace}/${output_name}" | tee -a "${log_path}" >&2
    if [[ -f "${response_path}" ]]; then
      echo "Last Codex message:" | tee -a "${log_path}" >&2
      sed -n '1,120p' "${response_path}" | tee -a "${log_path}" >&2
    fi
    echo "Raw Codex log: ${raw_log_path}" | tee -a "${log_path}" >&2
    echo "Workspace kept at ${workspace}" | tee -a "${log_path}" >&2
    return 1
  fi

  if [[ -f "${response_path}" ]]; then
    sed -n '1,20p' "${response_path}" | tee -a "${log_path}"
  fi

  mkdir -p "${output_dir}"
  cat "${workspace}/${output_name}" > "${output_path}"
  rm -rf "${workspace}"
  echo "wrote ${output_path}" | tee -a "${log_path}"
}

if [[ ${INTERNAL_RUN} -eq 1 ]]; then
  # `if` guards run_module against set -e so a failure still reaches the status
  # write and the keep-open prompt (previously the terminal closed instantly on
  # failure, exactly when you wanted to read the error).
  if run_module "${INTERNAL_TX_FILE}" "${INTERNAL_MODULE_NAME}"; then
    status=0
  else
    status=$?
  fi
  # GUI terminal clients detach from the emulator process, so the parent cannot
  # observe our exit code; publish it through a status file instead.
  printf '%s\n' "${status}" > "$(module_status_path "${INTERNAL_MODULE_NAME}")"
  if [[ ${KEEP_TERMINAL_OPEN} -eq 1 ]]; then
    echo
    read -r -p "Module finished with status ${status}. Press Enter to close this terminal..." _unused || true
  fi
  exit "${status}"
fi

module_count=0
attempted_count=0
success_count=0
failure_count=0
skipped_count=0
failed_modules=()
skipped_modules=()
bg_pids=()
bg_modules=()

if [[ ${USE_TERMINAL} -eq 1 ]]; then
  TERMINAL_BIN_RESOLVED=$(find_terminal) || {
    echo "No supported terminal emulator found. Use --terminal-bin PATH or --no-terminal." >&2
    exit 1
  }
fi

while IFS= read -r -d '' txt_file; do
  txt_base=$(basename "${txt_file}")
  raw_module_name="${txt_base%.txt}"
  module_name=$(normalize_module_name "${raw_module_name}")
  output_path=$(module_output_path "${module_name}")

  if [[ -n "${MODULE_FILTER}" ]]; then
    normalized_filter=$(normalize_module_name "${MODULE_FILTER}")
    if [[ "${module_name}" != "${normalized_filter}" && "${raw_module_name}" != "${MODULE_FILTER}" ]]; then
      continue
    fi
  fi

  module_count=$((module_count + 1))

  if [[ ${FORCE_REGENERATE} -eq 0 && -f "${output_path}" ]]; then
    skipped_count=$((skipped_count + 1))
    skipped_modules+=("${module_name}")
    echo "skip ${module_name}: existing output ${output_path}"
    continue
  fi

  attempted_count=$((attempted_count + 1))

  if [[ ${USE_TERMINAL} -eq 1 ]]; then
    echo "launch terminal for ${module_name}"
    self_args=(
      "$0"
      --internal-run-txt "${txt_file}" "${module_name}"
      --src-root "${SRC_ROOT}"
      --tmp-root "${TMP_ROOT}"
      --log-root "${LOG_ROOT}"
      --out-root "${OUT_ROOT}"
      --model "${MODEL}"
      --effort "${EFFORT}"
      --suffix "${OUTPUT_SUFFIX}"
      --codex-bin "${CODEX_BIN}"
      --sleep "${SLEEP_SECONDS}"
    )
    if [[ ${DRY_RUN} -eq 1 ]]; then
      self_args+=(--dry-run)
    fi
    if [[ ${KEEP_TERMINAL_OPEN} -eq 1 ]]; then
      self_args+=(--keep-terminal-open)
    fi

    status_path=$(module_status_path "${module_name}")
    rm -f "${status_path}"

    terminal_exec \
      "${TERMINAL_BIN_RESOLVED}" \
      "codex-${module_name}" \
      "${self_args[@]}"

    if [[ ${SEQUENTIAL} -eq 1 ]]; then
      # GUI terminal clients detach immediately, so `wait` would return at once
      # (and a bare `wait` always succeeds). The internal run publishes its exit
      # code through the status file; poll for it to actually serialize modules.
      until [[ -f "${status_path}" ]]; do
        sleep 2
      done
      module_status=$(<"${status_path}")
      if [[ "${module_status}" == "0" ]]; then
        success_count=$((success_count + 1))
      else
        failure_count=$((failure_count + 1))
        failed_modules+=("${module_name}")
        echo "module failed: ${module_name} (status ${module_status})" >&2
        if [[ ${FAIL_FAST} -eq 1 ]]; then
          break
        fi
      fi
      if [[ ${SLEEP_SECONDS} -gt 0 ]]; then
        sleep "${SLEEP_SECONDS}"
      fi
    fi
  else
    if [[ ${SEQUENTIAL} -eq 0 ]]; then
      run_module "${txt_file}" "${module_name}" &
      bg_pids+=($!)
      bg_modules+=("${module_name}")
    else
      if run_module "${txt_file}" "${module_name}"; then
        success_count=$((success_count + 1))
      else
        failure_count=$((failure_count + 1))
        failed_modules+=("${module_name}")
        echo "module failed: ${module_name}" >&2
        if [[ ${FAIL_FAST} -eq 1 ]]; then
          break
        fi
      fi
      if [[ ${SLEEP_SECONDS} -gt 0 ]]; then
        sleep "${SLEEP_SECONDS}"
      fi
    fi
  fi
done < <(find "${SRC_ROOT}" -mindepth 1 -maxdepth 1 -type f -name '*.txt' -print0 | sort -z)

if [[ ${module_count} -eq 0 ]]; then
  echo "No matching .txt files found under ${SRC_ROOT}" >&2
  exit 1
fi

if [[ ${USE_TERMINAL} -eq 0 && ${SEQUENTIAL} -eq 0 && ${#bg_pids[@]} -gt 0 ]]; then
  for i in "${!bg_pids[@]}"; do
    if wait "${bg_pids[$i]}"; then
      success_count=$((success_count + 1))
    else
      failure_count=$((failure_count + 1))
      failed_modules+=("${bg_modules[$i]}")
      echo "module failed: ${bg_modules[$i]}" >&2
    fi
  done
fi

if [[ ${USE_TERMINAL} -eq 1 && ${SEQUENTIAL} -eq 0 ]]; then
  echo "Launched ${module_count} txt/module terminal(s); results NOT aggregated." \
       "Check ${LOG_ROOT}/*.status for per-module exit codes. Logs: ${LOG_ROOT}"
else
  echo "Processed ${module_count} txt/module(s): attempted=${attempted_count}, skipped=${skipped_count}, success=${success_count}, failed=${failure_count}. Logs: ${LOG_ROOT}"
fi

if [[ ${failure_count} -gt 0 ]]; then
  printf 'Failed modules: %s\n' "${failed_modules[@]}" >&2
  exit 1
fi
