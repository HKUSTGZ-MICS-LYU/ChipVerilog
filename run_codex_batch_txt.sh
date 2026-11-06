#!/usr/bin/env bash

set -euo pipefail

# Generate Verilog from task descriptions using Bash, curl, and jq.
# "codex" is the result-directory label. No Codex CLI is invoked.
# CODEX_API_BASE includes any API prefix (e.g. /v1), without /chat/completions.
# export CODEX_API_BASE="https://YOUR_API_HOST/v1"
# export CODEX_API_KEY="YOUR_API_KEY"
# export CODEX_MODEL="gpt-5.4"
#
# Preview without credentials or network access:
#   bash run_codex_batch_txt.sh --dry-run --modules cordic mips_alu
# Generate into a separate directory, preserving the cached benchmark:
#   bash run_codex_batch_txt.sh --output-root .codex_batch_work/Result/codex

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
src_root="${REPO_ROOT}/Src"
output_root="${REPO_ROOT}/Result/codex"
log_root="${REPO_ROOT}/.codex_batch_logs"
model=${CODEX_MODEL-gpt-5.4}
samples=5
temperature=""
max_completion_tokens=""
reasoning_effort=""
timeout=180
retries=3
retry_delay=3
request_delay=0
overwrite=0
dry_run=0
modules=()
module_count=0

usage() {
  cat <<'HELP'
Usage: bash run_codex_batch_txt.sh [options]

Generate Verilog through an OpenAI-compatible Chat Completions API.
Requires Bash, curl, jq, and standard Unix tools; no Python is needed.
Set CODEX_API_BASE and CODEX_API_KEY except for --dry-run.

  --src-root DIR                  Task source root (default: repository Src/)
  --output-root DIR               Candidate root (default: Result/codex/)
  --log-root DIR                  Log root (default: .codex_batch_logs/)
  --model ID                      Model ID (default: CODEX_MODEL or gpt-5.4)
  --samples N                     Separate requests per task (default: 5)
  --modules NAME [NAME ...]       Result module names, e.g. cordic mips_alu fpu
  --temperature NUMBER            Omitted unless supplied
  --max-completion-tokens N        Omitted unless supplied
  --reasoning-effort VALUE         Omitted unless supplied
  --timeout SECONDS                HTTP timeout (default: 180)
  --retries N                      Maximum HTTP attempts per sample (default: 3)
  --retry-delay SECONDS            Linear retry delay (default: 3)
  --request-delay SECONDS          Delay after each attempted sample (default: 0)
  --overwrite                     Replace existing nonempty candidates
  --dry-run                       Print the plan without API calls or file writes
  -h, --help                      Show this help
HELP
}

die() { printf 'error: %s\n' "$*" >&2; exit 2; }

while (( $# )); do
  case "$1" in
    --*=*) set -- "${1%%=*}" "${1#*=}" "${@:2}" ;;
    --src-root|--output-root|--log-root|--model|--samples|--temperature|--max-completion-tokens|--reasoning-effort|--timeout|--retries|--retry-delay|--request-delay)
      (( $# >= 2 )) || die "Missing value for $1"
      option=$1
      value=$2
      [[ -n "$value" && "$value" != --* ]] || die "Missing value for $option"
      case "$option" in
        --src-root) src_root=$value ;;
        --output-root) output_root=$value ;;
        --log-root) log_root=$value ;;
        --model) model=$value ;;
        --samples) samples=$value ;;
        --temperature) temperature=$value ;;
        --max-completion-tokens) max_completion_tokens=$value ;;
        --reasoning-effort) reasoning_effort=$value ;;
        --timeout) timeout=$value ;;
        --retries) retries=$value ;;
        --retry-delay) retry_delay=$value ;;
        --request-delay) request_delay=$value ;;
      esac
      shift 2
      ;;
    --modules)
      shift
      previous_count=$module_count
      while (( $# )) && [[ "$1" != -* ]]; do
        modules+=("$1")
        module_count=$((module_count + 1))
        shift
      done
      (( module_count > previous_count )) || die "--modules needs at least one name"
      ;;
    --overwrite) overwrite=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

for executable in curl jq find sort mktemp; do
  command -v "$executable" >/dev/null 2>&1 || die "Missing executable: $executable"
done
[[ "$samples" =~ ^[1-9][0-9]*$ ]] || die "--samples must be a positive integer"
[[ "$retries" =~ ^[1-9][0-9]*$ ]] || die "--retries must be a positive integer"
if [[ -n "$max_completion_tokens" ]]; then
  [[ "$max_completion_tokens" =~ ^[1-9][0-9]*$ ]] || die "--max-completion-tokens must be a positive integer"
fi
for number in "$retry_delay" "$request_delay"; do
  jq -en --arg value "$number" '$value | tonumber | isfinite and . >= 0' >/dev/null 2>&1 \
    || die "Delays must be finite, nonnegative numbers"
done
jq -en --arg value "$timeout" '$value | tonumber | isfinite and . > 0' >/dev/null 2>&1 \
  || die "--timeout must be positive and finite"
if [[ -n "$temperature" ]]; then
  jq -en --arg value "$temperature" '$value | tonumber | isfinite and . >= 0 and . <= 2' >/dev/null 2>&1 \
    || die "--temperature must be between 0 and 2"
fi
[[ "$model" =~ [^[:space:]] ]] || die "Model ID must not be empty"
[[ -d "$src_root" ]] || die "Source directory does not exist: $src_root"
src_root=$(cd -- "$src_root" && pwd)

description_files=()
module_names=()
top_names=()
task_count=0
while IFS= read -r description_file; do
  relative_path=${description_file#"${src_root}/"}
  top_name=${description_file%/*}
  top_name=${top_name##*/}
  [[ "$top_name" != fpu_double ]] || top_name=fpu
  module_name=$top_name
  [[ "$relative_path" != mips_16/* ]] || module_name="mips_${top_name}"
  if (( module_count )); then
    selected=0
    for requested in "${modules[@]}"; do
      [[ "$requested" != "$module_name" ]] || selected=1
    done
    (( selected )) || continue
  fi
  description_files+=("$description_file")
  module_names+=("$module_name")
  top_names+=("$top_name")
  task_count=$((task_count + 1))
done < <(find "$src_root" -type f -name description.txt -path '*/des/*' | LC_ALL=C sort)
(( task_count )) || die "No matching task descriptions found"
if (( module_count )); then
  for requested in "${modules[@]}"; do
    found=0
    for module_name in "${module_names[@]}"; do
      [[ "$requested" != "$module_name" ]] || found=1
    done
    (( found )) || die "Unknown result module: $requested"
  done
fi

printf 'Model: %s\n' "$model"
printf 'Discovered %s modules and %s target files under %s.\n' "$task_count" "$((task_count * samples))" "$output_root"
printf 'Logs will be stored under %s.\n' "$log_root"
for (( task=0; task<task_count; task++ )); do
  printf '  %s: %s -> %s/%s (t1..t%s)\n' \
    "${module_names[task]}" "${description_files[task]}" "$output_root" "${module_names[task]}" "$samples"
done
(( ! dry_run )) || exit 0

api_base=${CODEX_API_BASE-}
api_key=${CODEX_API_KEY-}
[[ -n "$api_base" && -n "$api_key" ]] || die "Set CODEX_API_BASE and CODEX_API_KEY; see the commented configuration"
while [[ "$api_base" == */ ]]; do api_base=${api_base%/}; done
case "$api_base" in http://*|https://*) ;; *) die "CODEX_API_BASE must be an http(s) API base URL" ;; esac
authority=${api_base#*://}
authority=${authority%%/*}
[[ -n "$authority" && "$authority" != *@* && "$api_base" != *\?* && "$api_base" != *\#* && ! "$api_base" =~ [[:space:]] ]] \
  || die "API base URL must not contain credentials, whitespace, query, or fragment"
[[ "$api_base" != *YOUR_API_* && "$api_key" != YOUR_API_KEY ]] || die "Replace the API placeholders"
validate_key() { local LC_ALL=C; [[ "$api_key" =~ ^[[:graph:]]+$ ]]; }
validate_key || die "CODEX_API_KEY must contain printable ASCII characters without whitespace"
api_url="${api_base}/chat/completions"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/chipverilog-codex.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT
# Keep credentials out of command arguments and request logs.
printf 'Authorization: Bearer %s\n' "$api_key" >"${work_dir}/auth.header"
printf '%s' "$api_key" >"${work_dir}/api_key"
cat >"${work_dir}/system_prompt.txt" <<'PROMPT'
You are an expert RTL designer.
Generate correct, complete Verilog from the provided specification.
Return only the final Verilog source code.
Do not include markdown fences, explanations, TODOs, or placeholders.
PROMPT

redact_error() {
  jq -Rrs --rawfile secret "${work_dir}/api_key" 'split($secret) | join("[REDACTED]")' "$1"
}

call_api() {
  local payload_file=$1 response_file=$2 error_file=$3
  local attempt curl_status http_code delay
  for (( attempt=1; attempt<=retries; attempt++ )); do
    curl_status=0
    http_code=$(curl --disable --silent --show-error --max-time "$timeout" \
      --proto '=http,https' --request POST \
      --header "@${work_dir}/auth.header" --header 'Content-Type: application/json' \
      --data-binary "@${payload_file}" --output "$response_file" --write-out '%{http_code}' \
      "$api_url" 2>"${work_dir}/curl_error.txt") || curl_status=$?
    if (( curl_status == 0 )) && [[ "$http_code" == 2?? ]]; then
      return 0
    fi
    if (( curl_status )); then
      redact_error "${work_dir}/curl_error.txt" >"$error_file" || return 1
    else
      { printf 'HTTP %s: ' "$http_code"; redact_error "$response_file"; } >"$error_file" || return 1
    fi
    rm -f -- "$response_file" || return 1
    if (( curl_status == 0 )) && [[ "$http_code" != 429 && "$http_code" != 5?? ]]; then
      return 2
    fi
    (( attempt < retries )) || return 1
    printf '[retry] HTTP attempt %s/%s failed\n' "$attempt" "$retries" >&2
    delay=$(jq -nr --arg delay "$retry_delay" --argjson attempt "$attempt" '($delay | tonumber) * $attempt') || return 1
    sleep "$delay" || return 1
  done
  return 1
}

extract_content() {
  jq -ej '
    .choices[0].message.content
    | if type == "array" then
        map(select(type == "object") | .text | select(type == "string")) | join("")
      else . end
    | if type == "string" and test("\\S") then .
      else error("Response has no final text; see the response log.") end
  ' "$1"
}

normalize_verilog() {
  jq -jn --rawfile content "$1" '
    def trim: sub("^\\s+"; "") | sub("\\s+$"; "");
    [$content
      | match("(?:\\A|(?<=\\n))[ \\t]*```(?<language>[^\\r\\n]*)\\r?\\n(?<code>.*?)(?<=\\n)[ \\t]*```[ \\t]*(?:\\r?\\n|\\z)"; "gm")
      | .captures | map({key: .name, value: .string}) | from_entries
      | select(.language | trim | ascii_downcase | . == "" or . == "verilog" or . == "systemverilog")
      | .code | trim
    ] as $blocks
    | (if ($blocks | length) > 0 then $blocks | join("\n\n") else $content | trim end)
    | if test("\\S") then sub("\\s+$"; "") + "\n"
      else error("Empty code after Markdown fence removal; see the raw content log.") end
  '
}

generated=0
skipped=0
failed=0
for (( task=0; task<task_count; task++ )); do
  module_name=${module_names[task]}
  description_file=${description_files[task]}
  task_output_dir="${output_root}/${module_name}"
  task_log_dir="${log_root}/${module_name}"
  # Each sample uses the same system/user pair without earlier outputs,
  # reference RTL, tool access, validation feedback, or conversation history.
  jq -n --arg model "$model" --arg top "${top_names[task]}" \
    --rawfile system "${work_dir}/system_prompt.txt" --rawfile description "$description_file" \
    --arg temperature "$temperature" --arg max_tokens "$max_completion_tokens" \
    --arg reasoning "$reasoning_effort" '
      def trim: sub("^\\s+"; "") | sub("\\s+$"; "");
      {model: $model, messages: [
        {role: "system", content: ($system | rtrimstr("\n"))},
        {role: "user", content: (
          "Generate a Verilog implementation for the module \"" + $top + "\".\n\n" +
          "Requirements:\n" +
          "- Return only Verilog source code.\n" +
          "- Do not use markdown code fences.\n" +
          "- Do not include explanations before or after the code.\n" +
          "- Produce a complete implementation, not pseudocode.\n" +
          "- Use Verilog-2001 unless the specification clearly requires otherwise.\n\n" +
          "Specification:\n" + ($description | trim) + "\n"
        )}
      ], n: 1, stream: false}
      + (if $temperature == "" then {} else {temperature: ($temperature | tonumber)} end)
      + (if $max_tokens == "" then {} else {max_completion_tokens: ($max_tokens | tonumber)} end)
      + (if $reasoning == "" then {} else {reasoning_effort: $reasoning} end)
    ' >"${work_dir}/payload.json"
  for (( sample=1; sample<=samples; sample++ )); do
    stem="${module_name}_t${sample}"
    output_file="${task_output_dir}/${stem}.v"
    if (( ! overwrite )) && [[ -s "$output_file" ]]; then
      skipped=$((skipped + 1))
      printf '[skip] %s\n' "$output_file"
      continue
    fi
    printf '[gen] %s\n' "$output_file"
    mkdir -p -- "$task_log_dir"
    response_file="${task_log_dir}/${stem}_response.json"
    raw_file="${task_log_dir}/${stem}_raw_content.txt"
    normalized_file="${task_log_dir}/${stem}_normalized.v"
    error_file="${task_log_dir}/${stem}_error.txt"
    rm -f -- "$response_file" "$raw_file" "$normalized_file" "$error_file"
    # The endpoint base and Authorization header are deliberately not logged.
    jq -n --arg description "$description_file" --arg output "$output_file" \
      --argjson sample "$sample" --slurpfile payload "${work_dir}/payload.json" '
        {procedure: "api-generation", description_file: $description, output_file: $output,
         sample_index: $sample, endpoint_path: "/chat/completions", request: $payload[0]}
      ' >"${task_log_dir}/${stem}_request.json"
    api_status=0
    call_api "${work_dir}/payload.json" "$response_file" "$error_file" || api_status=$?
    if (( api_status == 0 )); then
      if ! extract_content "$response_file" >"$raw_file" 2>"$error_file"; then
        rm -f -- "$raw_file"
        api_status=1
      elif ! normalize_verilog "$raw_file" >"$normalized_file" 2>"$error_file"; then
        rm -f -- "$normalized_file"
        api_status=1
      else
        mkdir -p -- "$task_output_dir"
        temporary_output=$(mktemp "${task_output_dir}/.${stem}.XXXXXX")
        cp -- "$normalized_file" "$temporary_output"
        mv -f -- "$temporary_output" "$output_file"
        rm -f -- "$error_file"
        generated=$((generated + 1))
      fi
    fi
    if (( api_status )); then
      failed=$((failed + 1))
      printf '[error] %s: ' "$output_file" >&2
      cat "$error_file" >&2
      (( api_status != 2 )) || exit 1
    fi
    sleep "$request_delay"
  done
done
printf 'Finished. generated=%s skipped=%s failed=%s\n' "$generated" "$skipped" "$failed"
(( failed == 0 ))
