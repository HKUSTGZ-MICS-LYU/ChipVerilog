#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SRC_ROOT_DEFAULT="${SCRIPT_DIR}/Description"
TMP_ROOT_DEFAULT="${SCRIPT_DIR}/.copilot_batch_work"
LOG_ROOT_DEFAULT="${SCRIPT_DIR}/.copilot_batch_logs"
OUT_ROOT_DEFAULT="${SCRIPT_DIR}/Generated_Verilog"
COPILOT_BIN_DEFAULT="${COPILOT_BIN:-copilot}"
SYSTEM_PROMPT_DEFAULT="Please act as a professional verilog designer."

usage() {
  cat <<'USAGE'
Usage:
  ./run_copilot_batch_txt_serial_outfolders.sh [options]

Generate one Verilog file for each .txt file directly under Description.
Each .txt file is processed in a fresh Copilot invocation with an isolated
workspace. The full text of each .txt file is embedded directly into the
Copilot prompt.

Options:
  --src-root PATH         Directory containing per-module .txt files
  --tmp-root PATH         Temporary root for isolated Copilot workspaces
  --log-root PATH         Root directory for per-module logs
  --out-root PATH         Root directory for generated Verilog output folders
  --module NAME           Process only one txt file, matched by filename without .txt
  --model MODEL           Pass --model MODEL to copilot
  --effort LEVEL          Pass --effort LEVEL to copilot (low|medium|high|xhigh)
  --copilot-bin PATH      Copilot CLI binary or command name
  --terminal-bin PATH     Terminal emulator command to use
  --no-terminal           Run in the current terminal instead of separate terminals (default)
  --terminal              Use separate GUI terminal windows if available
  --sequential            Wait for each module to finish before launching the next (default)
  --parallel              Launch all module terminals immediately; not recommended on HPC
  --sleep SECONDS         Sleep between modules in sequential mode to reduce rate-limit risk
  --keep-terminal-open    Keep each terminal open after the module finishes
  --dry-run               Show planned work without calling Copilot
  --silent                Pass --silent to Copilot
  -h, --help              Show this help

Environment:
  COPILOT_BIN             Default Copilot CLI binary if --copilot-bin is omitted
  SYSTEM_PROMPT           Override the default system prompt text
  TERMINAL_BIN            Default terminal emulator if --terminal-bin is omitted

Notes:
  - Run `copilot login` before using this script.
  - Input layout should be:
      Description/a.txt
      Description/b.txt
      Description/c.txt
  - Output files are written into separate folders under OUT_ROOT as:
      Generated_Verilog/a/a_t1.v
      Generated_Verilog/b/b_t1.v
      Generated_Verilog/c/c_t1.v
  - Each txt file is embedded directly into the prompt passed to Copilot.

Examples:
  ./run_copilot_batch_txt_serial_outfolders.sh --src-root /hpc/home/connect.ytan910/code/LLM/ChipVerilogSuite/Description --out-root /hpc/home/connect.ytan910/code/LLM/ChipVerilogSuite/Generated_Verilog --sleep 10
  ./run_copilot_batch_txt_serial_outfolders.sh --src-root /hpc/home/connect.ytan910/code/LLM/ChipVerilogSuite/Description --module fpu_add
  ./run_copilot_batch_txt_serial_outfolders.sh --model gpt-5.2 --effort high
USAGE
}

SRC_ROOT="${SRC_ROOT_DEFAULT}"
TMP_ROOT="${TMP_ROOT_DEFAULT}"
LOG_ROOT="${LOG_ROOT_DEFAULT}"
OUT_ROOT="${OUT_ROOT_DEFAULT}"
MODULE_FILTER=""
MODEL=""
EFFORT=""
COPILOT_BIN="${COPILOT_BIN_DEFAULT}"
TERMINAL_BIN="${TERMINAL_BIN:-}"
SYSTEM_PROMPT="${SYSTEM_PROMPT:-${SYSTEM_PROMPT_DEFAULT}}"
DRY_RUN=0
SILENT=0
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
      "${terminal}" --title="${title}" --command "bash -lc '${command_line}'" &
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
    --copilot-bin)
      COPILOT_BIN="$2"
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
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --silent)
      SILENT=1
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

if [[ -n "${EFFORT}" && ! "${EFFORT}" =~ ^(low|medium|high|xhigh)$ ]]; then
  echo "--effort must be one of: low, medium, high, xhigh" >&2
  exit 1
fi

if [[ ! -d "${SRC_ROOT}" ]]; then
  echo "Source root does not exist: ${SRC_ROOT}" >&2
  exit 1
fi

if [[ "${COPILOT_BIN}" == */* ]]; then
  if [[ ! -x "${COPILOT_BIN}" ]]; then
    echo "Copilot CLI is not executable: ${COPILOT_BIN}" >&2
    exit 1
  fi
elif ! command -v "${COPILOT_BIN}" >/dev/null 2>&1; then
  echo "Copilot CLI not found in PATH: ${COPILOT_BIN}" >&2
  exit 1
fi

mkdir -p "${TMP_ROOT}" "${LOG_ROOT}" "${OUT_ROOT}"

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
  local safe_module_name
  local -a copilot_args

  echo "model: ${MODEL:-default}"
  echo "effort: ${EFFORT:-default}"
  echo "copilot command: ${COPILOT_BIN} --model ${MODEL:-default} --effort ${EFFORT:-default}"
  
  safe_module_name=$(printf '%s' "${module_name}" | tr '/[:space:]' '___')
  output_name="${module_name}_t1.v"
  output_dir="${OUT_ROOT}/${safe_module_name}"
  output_path="${output_dir}/${output_name}"
  workspace=$(mktemp -d "${TMP_ROOT}/${safe_module_name}_XXXXXX")
  log_path="${LOG_ROOT}/${safe_module_name}.log"
  description_content=$(<"${txt_file}")

  prompt=$(cat <<PROMPT_EOF
${SYSTEM_PROMPT}

This task is fully independent from every other module.
You are running in a separate terminal/session and an isolated workspace for module ${module_name}.

Mandatory workflow:
- Use only the specification embedded below for this module.
- Treat this as a fresh task, not as template matching.
- Do not reuse structure, boilerplate, or assumptions from previous modules.
- Do not read, search, glob, grep, cat, open, inspect, or reference any file except the output file you create.
- Do not inspect parent directories, sibling directories, repository files, .v files, reference answers, golden solutions, previous outputs, or external source files.
- Do not rely on any local txt/description file; the full specification is already provided here.

<description>
${description_content}
</description>

Task:
- Generate one synthesizable Verilog implementation from the embedded specification.
- Write the result to ./${output_name}.
- If the embedded specification does not explicitly define the module name, use ${module_name}.
- The file content must be plain Verilog only, with no Markdown, no placeholders, and no TODOs.
- Do not create any file other than ./${output_name}.

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
    echo
  } | tee "${log_path}"

  copilot_args=(
    -p "${prompt}"
    --allow-all-tools
    --no-custom-instructions
    --no-auto-update
    --stream off
  )

  if [[ ${SILENT} -eq 1 ]]; then
    copilot_args+=(--silent)
  fi

  if [[ -n "${MODEL}" ]]; then
    copilot_args+=(--model "${MODEL}")
  fi

  if [[ -n "${EFFORT}" ]]; then
    copilot_args+=(--effort "${EFFORT}")
  fi

  if ! (
    cd "${workspace}"
    "${COPILOT_BIN}" "${copilot_args[@]}" </dev/null 2>&1 | tee -a "${log_path}"
  ); then
    echo "Copilot failed for module ${module_name}. Workspace kept at ${workspace}" | tee -a "${log_path}" >&2
    return 1
  fi

  if [[ ! -f "${workspace}/${output_name}" ]]; then
    echo "Expected output file was not created: ${workspace}/${output_name}" | tee -a "${log_path}" >&2
    echo "Workspace kept at ${workspace}" | tee -a "${log_path}" >&2
    return 1
  fi

  mkdir -p "${output_dir}"
  cat "${workspace}/${output_name}" > "${output_path}"
  rm -rf "${workspace}"
  echo "wrote ${output_path}" | tee -a "${log_path}"
}

if [[ ${INTERNAL_RUN} -eq 1 ]]; then
  run_module "${INTERNAL_TX_FILE}" "${INTERNAL_MODULE_NAME}"
  status=$?
  if [[ ${KEEP_TERMINAL_OPEN} -eq 1 ]]; then
    echo
    read -r -p "Module finished with status ${status}. Press Enter to close this terminal..." _unused || true
  fi
  exit "${status}"
fi

module_count=0

if [[ ${USE_TERMINAL} -eq 1 ]]; then
  TERMINAL_BIN_RESOLVED=$(find_terminal) || {
    echo "No supported terminal emulator found. Use --terminal-bin PATH or --no-terminal." >&2
    exit 1
  }
fi

while IFS= read -r -d '' txt_file; do
  txt_base=$(basename "${txt_file}")
  module_name="${txt_base%.txt}"

  if [[ -n "${MODULE_FILTER}" ]]; then
    if [[ "${module_name}" != "${MODULE_FILTER}" && "${module_name}" != "${MODULE_FILTER}_description" ]]; then
      continue
    fi
  fi

  module_count=$((module_count + 1))

  if [[ ${USE_TERMINAL} -eq 1 ]]; then
    echo "launch terminal for ${module_name}"
    self_args=(
      "$0"
      --internal-run-txt "${txt_file}" "${module_name}"
      --src-root "${SRC_ROOT}"
      --tmp-root "${TMP_ROOT}"
      --log-root "${LOG_ROOT}"
      --out-root "${OUT_ROOT}"
      --copilot-bin "${COPILOT_BIN}"
      --sleep "${SLEEP_SECONDS}"
    )
    if [[ -n "${MODEL}" ]]; then
      self_args+=(--model "${MODEL}")
    fi
    if [[ -n "${EFFORT}" ]]; then
      self_args+=(--effort "${EFFORT}")
    fi
    if [[ ${DRY_RUN} -eq 1 ]]; then
      self_args+=(--dry-run)
    fi
    if [[ ${SILENT} -eq 1 ]]; then
      self_args+=(--silent)
    fi
    if [[ ${KEEP_TERMINAL_OPEN} -eq 1 ]]; then
      self_args+=(--keep-terminal-open)
    fi

    terminal_exec \
      "${TERMINAL_BIN_RESOLVED}" \
      "copilot-${module_name}" \
      "${self_args[@]}"

    if [[ ${SEQUENTIAL} -eq 1 ]]; then
      wait
      if [[ ${SLEEP_SECONDS} -gt 0 ]]; then
        sleep "${SLEEP_SECONDS}"
      fi
    fi
  else
    run_module "${txt_file}" "${module_name}"
    if [[ ${SLEEP_SECONDS} -gt 0 ]]; then
      sleep "${SLEEP_SECONDS}"
    fi
  fi
done < <(find "${SRC_ROOT}" -mindepth 1 -maxdepth 1 -type f -name '*.txt' -print0 | sort -z)

if [[ ${module_count} -eq 0 ]]; then
  echo "No matching .txt files found under ${SRC_ROOT}" >&2
  exit 1
fi

if [[ ${USE_TERMINAL} -eq 1 && ${SEQUENTIAL} -eq 0 ]]; then
  echo "Launched ${module_count} txt/module terminal(s). Logs: ${LOG_ROOT}"
else
  echo "Processed ${module_count} txt/module(s). Logs: ${LOG_ROOT}"
fi
