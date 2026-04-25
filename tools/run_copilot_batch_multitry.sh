#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SRC_ROOT_DEFAULT="${SCRIPT_DIR}/Description_copilot"
TMP_ROOT_DEFAULT="${SCRIPT_DIR}/.copilot_batch_work"
COPILOT_BIN_DEFAULT="${COPILOT_BIN:-copilot}"
SYSTEM_PROMPT_DEFAULT="Please act as a professional verilog designer."

usage() {
  cat <<'EOF'
Usage:
  ./run_copilot_batch.sh [options]

Generate one Verilog file for each subdirectory under Description_copilot.
Each subdirectory is processed in a fresh Copilot invocation with an isolated
workspace per module.

The full text of each module's description.txt is embedded directly into the
Copilot prompt so the model receives the complete specification as input
instead of reading the file through a shell command at runtime.

Options:
  --src-root PATH      Root directory containing per-module subdirectories
  --tmp-root PATH      Temporary root for isolated Copilot workspaces
  --module NAME        Process only one module subdirectory
  --model MODEL        Pass --model MODEL to copilot
  --effort LEVEL       Pass --effort LEVEL to copilot (low|medium|high|xhigh)
  --copilot-bin PATH   Copilot CLI binary or command name
  --dry-run            Show planned work without calling Copilot
  --silent             Pass --silent to Copilot
  -h, --help           Show this help

Environment:
  COPILOT_BIN          Default Copilot CLI binary if --copilot-bin is omitted
  SYSTEM_PROMPT        Override the default system prompt text

Notes:
  - Run `copilot login` before using this script.
  - Output files are written back into each module directory as:
      <module_name>_t1.v
  - Each description.txt is embedded directly into the prompt instead of
    relying on Copilot to read the file at runtime.

Examples:
  ./run_copilot_batch.sh
  ./run_copilot_batch.sh --module fpu_add
  ./run_copilot_batch.sh --model gpt-5.2 --effort high
EOF
}

SRC_ROOT="${SRC_ROOT_DEFAULT}"
TMP_ROOT="${TMP_ROOT_DEFAULT}"
MODULE_FILTER=""
MODEL=""
EFFORT=""
COPILOT_BIN="${COPILOT_BIN_DEFAULT}"
SYSTEM_PROMPT="${SYSTEM_PROMPT:-${SYSTEM_PROMPT_DEFAULT}}"
DRY_RUN=0
SILENT=0

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
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --silent)
      SILENT=1
      shift
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

mkdir -p "${TMP_ROOT}"

run_module() {
  local module_dir=$1
  local module_name=$2
  local workspace
  local output_name
  local output_path
  local description_content
  local prompt
  local -a copilot_args

  output_name="${module_name}_t1.v"
  output_path="${module_dir}/${output_name}"
  workspace=$(mktemp -d "${TMP_ROOT}/${module_name}_XXXXXX")
  description_content=$(<"${module_dir}/description.txt")

  prompt=$(cat <<EOF
${SYSTEM_PROMPT}

This task is fully independent from every other module.
You are running in an isolated workspace for module ${module_name}.

Mandatory workflow:
- Use only the specification embedded below for this module.
- Treat this as a fresh task, not as template matching.
- Do not reuse structure, boilerplate, or assumptions from previous modules.
- Do not inspect parent directories, sibling directories, or external source files.
- Do not rely on any local description file; the full specification is already provided here.

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
EOF
)

  if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "[dry-run] ${module_name} -> ${output_path}"
    rm -rf "${workspace}"
    return 0
  fi

  echo "processing ${module_name}"
  echo "  description: ${module_dir}/description.txt"
  echo "  output: ${output_path}"
  echo "  workspace: ${workspace}"

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
    "${COPILOT_BIN}" "${copilot_args[@]}" </dev/null
  ); then
    echo "Copilot failed for module ${module_name}. Workspace kept at ${workspace}" >&2
    return 1
  fi

  if [[ ! -f "${workspace}/${output_name}" ]]; then
    echo "Expected output file was not created: ${workspace}/${output_name}" >&2
    echo "Workspace kept at ${workspace}" >&2
    return 1
  fi

  cat "${workspace}/${output_name}" > "${output_path}"
  rm -rf "${workspace}"
  echo "  wrote ${output_path}"
}

module_count=0
module_dirs=()

while IFS= read -r -d '' module_dir; do
  module_dirs+=("${module_dir}")
done < <(find "${SRC_ROOT}" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

for module_dir in "${module_dirs[@]}"; do
  module_name=$(basename "${module_dir}")

  if [[ -n "${MODULE_FILTER}" && "${module_name}" != "${MODULE_FILTER}" ]]; then
    continue
  fi

  if [[ ! -f "${module_dir}/description.txt" ]]; then
    echo "skip ${module_name}: missing description.txt"
    continue
  fi

  module_count=$((module_count + 1))
  run_module "${module_dir}" "${module_name}"
done

if [[ ${module_count} -eq 0 ]]; then
  echo "No matching module directories found under ${SRC_ROOT}" >&2
  exit 1
fi

echo "Processed ${module_count} module(s)."
