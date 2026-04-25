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

Generate one Verilog file for each selected subdirectory under
Description_copilot using a single Copilot invocation by default.

The full text of each selected module's description.txt is embedded directly
into one Copilot prompt so the model receives the complete specifications as
input instead of reading files through shell commands at runtime.

Options:
  --src-root PATH      Root directory containing per-module subdirectories
  --tmp-root PATH      Temporary root for the Copilot workspace
  --module NAME        Process only one module subdirectory
  --delegate-read      Let Copilot read description.txt files itself and plan
                       the work in one autonomous run instead of embedding all
                       descriptions into the initial prompt
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
      <module_name>_t3.v
  - One Copilot invocation handles all selected modules in a single task.
  - Default mode embeds each description.txt directly into the prompt.
  - `--delegate-read` uses a smaller prompt and lets Copilot read the
    description.txt files itself from the source tree.

Examples:
  ./run_copilot_batch.sh
  ./run_copilot_batch.sh --module fpu_add
  ./run_copilot_batch.sh --delegate-read
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
DELEGATE_READ=0

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
    --delegate-read)
      DELEGATE_READ=1
      shift
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

selected_count=0
module_dirs=()
selected_dirs=()
selected_names=()
selected_outputs=()

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

  selected_count=$((selected_count + 1))
  selected_dirs+=("${module_dir}")
  selected_names+=("${module_name}")
  selected_outputs+=("${module_name}_t3.v")
done

if [[ ${selected_count} -eq 0 ]]; then
  echo "No matching module directories found under ${SRC_ROOT}" >&2
  exit 1
fi

if [[ ${DRY_RUN} -eq 1 ]]; then
  for idx in "${!selected_dirs[@]}"; do
    echo "[dry-run] ${selected_names[$idx]} -> ${selected_dirs[$idx]}/${selected_outputs[$idx]}"
  done
  if [[ ${DELEGATE_READ} -eq 1 ]]; then
    echo "Planned single Copilot invocation for ${selected_count} module(s) using delegated file reads."
  else
    echo "Planned single Copilot invocation for ${selected_count} module(s) using embedded descriptions."
  fi
  exit 0
fi

run_modules() {
  local workspace
  local prompt
  local description_content
  local module_dir
  local module_name
  local output_name
  local output_path
  local copied_count
  local idx
  local -a missing_outputs
  local -a copilot_args

  if [[ ${DELEGATE_READ} -eq 1 ]]; then
    workspace="${SRC_ROOT}"

    prompt=$(cat <<EOF
${SYSTEM_PROMPT}

You are handling multiple independent Verilog generation tasks in one session.

Work autonomously in the current directory, which is the source root that
contains the selected module subdirectories.

Global requirements:
- Complete every selected module listed below in this single run.
- For each selected module, first read its local description.txt file.
- Build your own plan and then execute it autonomously without asking the user.
- Treat every module as a fresh task, not as template matching.
- Do not reuse structure, boilerplate, or assumptions from one module in another.
- Use only each module's own description.txt as the specification for that module.
- Write exactly one Verilog file for each selected module at the required path.
- Do not create any additional files.
- Before finishing, verify that every required output file exists.

Selected modules:
EOF
)

    for idx in "${!selected_names[@]}"; do
      prompt+=$(cat <<EOF
- module_name: ${selected_names[$idx]}
  description_path: ./${selected_names[$idx]}/description.txt
  output_path: ./${selected_names[$idx]}/${selected_outputs[$idx]}
EOF
)
    done

    prompt+=$(cat <<EOF

Per-module requirements:
- Generate one synthesizable Verilog implementation.
- If a module's description.txt does not explicitly define the module name, use the subdirectory name.
- The file content must be plain Verilog only, with no Markdown, no placeholders, and no TODOs.

Final response:
- Only report whether all requested output files were written successfully.
EOF
)
  else
    workspace=$(mktemp -d "${TMP_ROOT}/batch_XXXXXX")

    for idx in "${!selected_names[@]}"; do
      mkdir -p "${workspace}/${selected_names[$idx]}"
    done

    prompt=$(cat <<EOF
${SYSTEM_PROMPT}

You are handling multiple independent Verilog generation tasks in one session.

Global requirements:
- Complete every module listed below in this single run.
- Use only each module's embedded specification for that module.
- Treat every module as a fresh task, not as template matching.
- Do not reuse structure, boilerplate, or assumptions from one module in another.
- Do not inspect parent directories, sibling directories, or external source files.
- The full specifications are already provided below.
- Write exactly one Verilog file for each module at the required path.
- Do not create any additional files.
- Before finishing, verify that every required output file exists.

Module tasks:
EOF
)

    for idx in "${!selected_dirs[@]}"; do
      module_dir="${selected_dirs[$idx]}"
      module_name="${selected_names[$idx]}"
      output_name="${selected_outputs[$idx]}"
      description_content=$(<"${module_dir}/description.txt")

      prompt+=$(cat <<EOF

<module_task>
module_name: ${module_name}
output_path: ./${module_name}/${output_name}
requirements:
- Generate one synthesizable Verilog implementation from the embedded specification.
- If the embedded specification does not explicitly define the module name, use ${module_name}.
- The file content must be plain Verilog only, with no Markdown, no placeholders, and no TODOs.
- This module must be handled independently from all other modules in this task.

<description>
${description_content}
</description>
</module_task>
EOF
)
    done

    prompt+=$(cat <<EOF

Final response:
- Only report whether all requested output files were written successfully.
EOF
)
  fi

  echo "processing ${selected_count} module(s) in a single Copilot invocation"
  echo "  source root: ${SRC_ROOT}"
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
    echo "Copilot failed. Workspace kept at ${workspace}" >&2
    return 1
  fi

  copied_count=0
  missing_outputs=()

  for idx in "${!selected_dirs[@]}"; do
    module_dir="${selected_dirs[$idx]}"
    module_name="${selected_names[$idx]}"
    output_name="${selected_outputs[$idx]}"
    output_path="${module_dir}/${output_name}"

    if [[ ${DELEGATE_READ} -eq 1 ]]; then
      if [[ ! -f "${output_path}" ]]; then
        missing_outputs+=("${module_name}/${output_name}")
        continue
      fi

      copied_count=$((copied_count + 1))
      echo "  wrote ${output_path}"
      continue
    fi

    if [[ ! -f "${workspace}/${module_name}/${output_name}" ]]; then
      missing_outputs+=("${module_name}/${output_name}")
      continue
    fi

    cat "${workspace}/${module_name}/${output_name}" > "${output_path}"
    copied_count=$((copied_count + 1))
    echo "  wrote ${output_path}"
  done

  if [[ ${#missing_outputs[@]} -gt 0 ]]; then
    echo "Copilot did not create all expected files." >&2
    echo "Copied ${copied_count}/${selected_count} output file(s)." >&2
    printf 'Missing: %s\n' "${missing_outputs[@]}" >&2
    echo "Workspace kept at ${workspace}" >&2
    return 1
  fi

  if [[ ${DELEGATE_READ} -eq 0 ]]; then
    rm -rf "${workspace}"
  fi
  echo "Processed ${selected_count} module(s)."
}

run_modules
