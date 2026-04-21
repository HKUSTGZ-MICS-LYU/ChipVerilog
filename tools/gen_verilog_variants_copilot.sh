#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SUITE_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
PROJECT_ROOT_DEFAULT="${SUITE_ROOT}/double_fpu"

SRC_ROOT_DEFAULT="${PROJECT_ROOT_DEFAULT}/des/verilog"
OUT_ROOT_DEFAULT="${PROJECT_ROOT_DEFAULT}/gen10_copilot"
TMP_ROOT_DEFAULT="${PROJECT_ROOT_DEFAULT}/.copilot_work"
VARIANTS_DEFAULT=10
MODEL_DEFAULT=""
EFFORT_DEFAULT=""

usage() {
  cat <<'EOF'
Usage:
  tools/gen_verilog_variants_copilot.sh [options]

Options:
  --src-root PATH      Source root containing per-module subdirectories with description.txt
  --out-root PATH      Output root for generated variants
  --tmp-root PATH      Temporary root used as isolated Copilot workspaces
  --variants N         Number of variants per module
  --module NAME        Generate only one module subdirectory
  --model MODEL        Pass --model MODEL to copilot
  --effort LEVEL       Pass --effort LEVEL to copilot (low|medium|high|xhigh)
  --silent             Suppress copilot output and only keep script-level messages
  --dry-run            Print planned work without calling copilot
  -h, --help           Show this help

Environment:
  COPILOT_ROLE_PROMPT  Override the role/system-style prompt prefix

Examples:
  tools/gen_verilog_variants_copilot.sh
  tools/gen_verilog_variants_copilot.sh --module fpu_add --variants 10
  tools/gen_verilog_variants_copilot.sh --model gpt-5.2 --effort high
EOF
}

SRC_ROOT="${SRC_ROOT_DEFAULT}"
OUT_ROOT="${OUT_ROOT_DEFAULT}"
TMP_ROOT="${TMP_ROOT_DEFAULT}"
VARIANTS="${VARIANTS_DEFAULT}"
MODULE_FILTER=""
MODEL="${MODEL_DEFAULT}"
EFFORT="${EFFORT_DEFAULT}"
SILENT=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src-root)
      SRC_ROOT="$2"
      shift 2
      ;;
    --out-root)
      OUT_ROOT="$2"
      shift 2
      ;;
    --tmp-root)
      TMP_ROOT="$2"
      shift 2
      ;;
    --variants)
      VARIANTS="$2"
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
    --silent)
      SILENT=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
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

if ! [[ "${VARIANTS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "--variants must be a positive integer" >&2
  exit 1
fi

if [[ -n "${EFFORT}" && ! "${EFFORT}" =~ ^(low|medium|high|xhigh)$ ]]; then
  echo "--effort must be one of: low, medium, high, xhigh" >&2
  exit 1
fi

if ! command -v copilot >/dev/null 2>&1; then
  echo "copilot CLI not found in PATH" >&2
  exit 1
fi

if [[ ! -d "${SRC_ROOT}" ]]; then
  echo "Source root does not exist: ${SRC_ROOT}" >&2
  exit 1
fi

mkdir -p "${OUT_ROOT}" "${TMP_ROOT}"

ROLE_PROMPT="${COPILOT_ROLE_PROMPT:-You are a senior Verilog RTL designer with strong experience in synthesizable hardware design.}"

declare -a STYLE_HINTS=(
  "flat datapath"
  "wire-heavy decomposition"
  "stepwise staged datapath"
  "compact implementation"
  "clarity-first verbose implementation"
  "if-else oriented structure"
  "case-oriented control structure"
  "early special-case handling"
  "datapath/control separated"
  "different internal naming and decomposition"
  "balanced staged structure with explicit normalization steps"
  "separate intermediate transforms into multiple named signals"
)

style_for_variant() {
  local idx=$1
  local count=${#STYLE_HINTS[@]}
  local zero_based=$((idx - 1))
  local base_index=$((zero_based % count))
  local cycle=$((zero_based / count))
  local style="${STYLE_HINTS[$base_index]}"

  if [[ ${cycle} -gt 0 ]]; then
    style="${style}; style cycle ${cycle}"
  fi

  printf '%s' "${style}"
}

run_variant() {
  local module_dir=$1
  local module_name=$2
  local variant_idx=$3
  local out_dir=$4
  local tmp_dir
  local out_file
  local description_content
  local style_hint
  local prompt
  local -a copilot_args

  out_file="${out_dir}/${module_name}_$(printf '%02d' "${variant_idx}").v"
  tmp_dir=$(mktemp -d "${TMP_ROOT}/${module_name}_${variant_idx}_XXXXXX")
  description_content=$(<"${module_dir}/description.txt")
  style_hint=$(style_for_variant "${variant_idx}")

  if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "[dry-run] ${module_name} variant ${variant_idx} -> ${out_file}"
    rm -rf "${tmp_dir}"
    return 0
  fi

  prompt=$(cat <<EOF
${ROLE_PROMPT}

Use only the following specification. Do not inspect or rely on any existing Verilog implementation.

<description>
${description_content}
</description>

Task:
- Generate one synthesizable Verilog module.
- Module name must be ${module_name}.
- Write the result to ./${module_name}.v.

Variant control:
- This is variant ${variant_idx} of ${VARIANTS}.
- Style hint: ${style_hint}.
- Make the internal implementation structurally different from the other variants.

Restrictions:
- Do not access parent directories or sibling directories.
- Do not create a testbench.
- Do not leave placeholders or TODOs.

Final response:
- Only confirm whether ./${module_name}.v was written successfully.
EOF
)

  echo "  variant ${variant_idx}/${VARIANTS}: ${module_name} -> ${out_file}"
  echo "  workspace: ${tmp_dir}"

  copilot_args=(
    -p "${prompt}"
    --allow-all-tools
    --no-custom-instructions
    --no-auto-update
    --stream on
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

  (
    cd "${tmp_dir}"
    copilot "${copilot_args[@]}"
  )

  if [[ ! -f "${tmp_dir}/${module_name}.v" ]]; then
    echo "copilot did not write expected file: ${tmp_dir}/${module_name}.v" >&2
    rm -rf "${tmp_dir}"
    return 1
  fi

  # The local copilot wrapper runs inside Docker as root, so create the final
  # file as the current user instead of preserving container-side ownership.
  cat "${tmp_dir}/${module_name}.v" > "${out_file}"
  rm -rf "${tmp_dir}"
  echo "wrote ${out_file}"
}

module_count=0

while IFS= read -r -d '' module_dir; do
  module_name=$(basename "${module_dir}")

  if [[ -n "${MODULE_FILTER}" && "${module_name}" != "${MODULE_FILTER}" ]]; then
    continue
  fi

  if [[ ! -f "${module_dir}/description.txt" ]]; then
    continue
  fi

  module_count=$((module_count + 1))
  out_dir="${OUT_ROOT}/${module_name}"
  mkdir -p "${out_dir}"
  echo "module ${module_name}: generating ${VARIANTS} variants into ${out_dir}"

  for ((variant_idx = 1; variant_idx <= VARIANTS; variant_idx++)); do
    run_variant "${module_dir}" "${module_name}" "${variant_idx}" "${out_dir}"
  done
done < <(find "${SRC_ROOT}" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

if [[ ${module_count} -eq 0 ]]; then
  echo "No matching module directories found under ${SRC_ROOT}" >&2
  exit 1
fi
