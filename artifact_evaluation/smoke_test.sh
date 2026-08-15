#!/usr/bin/env bash

set -euo pipefail

AE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${AE_DIR}/.." && pwd)
SMOKE_ROOT=$(mktemp -d /tmp/chipverilog-ae-smoke.XXXXXX)
trap 'rm -rf -- "${SMOKE_ROOT}"' EXIT

cd "${REPO_ROOT}"

required_files=(
  LICENSE
  THIRD_PARTY_LICENSES.md
  artifact_evaluation/Artifact_Access.md
  artifact_evaluation/README.md
  artifact_evaluation/METRIC_DEFINITION.md
  artifact_evaluation/environment.yml
  artifact_evaluation/reproduce_metrics.py
  tools/formal_equivalence.py
)
for required_file in "${required_files[@]}"; do
  if [[ ! -f "${required_file}" ]]; then
    echo "missing required file: ${required_file}" >&2
    exit 1
  fi
done

for executable in python3 iverilog vvp; do
  if ! command -v "${executable}" >/dev/null 2>&1; then
    echo "missing required executable: ${executable}" >&2
    exit 1
  fi
done

python3 artifact_evaluation/reproduce_metrics.py

verify_cached_task() {
  local model=$1
  local module=$2
  local expected_compile=$3
  local expected_function=$4
  local result_root="${SMOKE_ROOT}/Result"
  local output="${SMOKE_ROOT}/${model}-${module}.json"

  mkdir -p "${result_root}/${model}"
  cp -R "Result/${model}/${module}" "${result_root}/${model}/${module}"
  python3 tools/formal_equivalence.py verify \
    "${result_root}/${model}/${module}" \
    --result-root "${result_root}" \
    --report-dir "${SMOKE_ROOT}/reports" \
    --depth 8 \
    --timeout 120 >"${output}"

  python3 - "${output}" "${expected_compile}" "${expected_function}" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
expected_compile = int(sys.argv[2])
expected_function = int(sys.argv[3])
actual = (payload["rows"], payload["compile_pass"], payload["function_pass"])
expected = (5, expected_compile, expected_function)
assert actual == expected, {"expected": expected, "actual": actual, "payload": payload}
PY
  echo "${model}/${module}: PASS (compile ${expected_compile}/5, function ${expected_function}/5)"
}

verify_cached_task deepseek mips_data_mem 5 5

iverilog -g2012 -s fpu_addsub_tb \
  -o "${SMOKE_ROOT}/reference-addsub" \
  Des/double_fpu/fpu_addsub_pipeline/fpu_addsub_pipeline.v \
  Des/double_fpu/fpu_addsub_pipeline/fpu_addsub_pipeline_TB.v
vvp -n "${SMOKE_ROOT}/reference-addsub" >"${SMOKE_ROOT}/reference-addsub.log"

iverilog -g2012 -s fpu_mul_tb \
  -o "${SMOKE_ROOT}/reference-mul" \
  Des/double_fpu/fpu_mul_pipeline/fpu_mul_pipeline.v \
  Des/double_fpu/fpu_mul_pipeline/fpu_mul_pipeline_TB.v
vvp -n "${SMOKE_ROOT}/reference-mul" >"${SMOKE_ROOT}/reference-mul.log"

if grep -q 'Error! out is incorrect' \
  "${SMOKE_ROOT}/reference-addsub.log" "${SMOKE_ROOT}/reference-mul.log"; then
  echo "FPU reference sanity check failed" >&2
  exit 1
fi
echo "FPU references: PASS (16/16 add/sub, 10/10 multiply vectors)"

verify_cached_task claude fpu_addsub_pipeline 5 0
verify_cached_task claude fpu_mul_pipeline 5 0
verify_cached_task codex fpu_addsub_pipeline 5 1
verify_cached_task codex fpu_mul_pipeline 5 0

echo "AE smoke test: PASS"
