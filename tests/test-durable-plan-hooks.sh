#!/bin/bash

set -euo pipefail
shopt -s nullglob

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root_dir
test_dir="$(mktemp -d)"
readonly test_dir
readonly hook="${root_dir}/plugins/durable-plan/hooks/durable-plan"
readonly test_home="${test_dir}/home"
readonly codex_home="${test_home}/.codex"
readonly repo_dir="${test_dir}/repo with spaces"

cleanup() {
  chmod -R u+w "${test_dir}" 2>/dev/null || true
  rm -rf "${test_dir}"
}
trap cleanup EXIT

mkdir -p "${test_home}" "${repo_dir}"
git -C "${repo_dir}" init -q
git -C "${repo_dir}" remote add origin \
  https://github.com/example/Example-Repo.git

run_hook() {
  local input="$1"

  printf '%s' "${input}" |
    CODEX_HOME="${codex_home}" HOME="${test_home}" "${hook}"
}

prompt_default="$(run_hook "$(jq -cn \
  --arg cwd "${repo_dir}" \
  '{hook_event_name:"UserPromptSubmit",permission_mode:"default",cwd:$cwd}')")"
readonly prompt_default
if [[ -n "${prompt_default}" ]]; then
  printf 'non-Plan UserPromptSubmit produced output\n' >&2
  exit 1
fi

prompt_plan="$(run_hook "$(jq -cn \
  --arg cwd "${repo_dir}" \
  '{hook_event_name:"UserPromptSubmit",permission_mode:"plan",cwd:$cwd}')")"
readonly prompt_plan
jq -e '
  .hookSpecificOutput.hookEventName == "UserPromptSubmit"
  and (.hookSpecificOutput.additionalContext | contains("<!-- durable-plan: draft -->"))
  and (.hookSpecificOutput.additionalContext | contains("<!-- durable-plan: final slug=<slug> -->"))
' <<<"${prompt_plan}" >/dev/null

draft_output="$(run_hook "$(jq -cn \
  --arg cwd "${repo_dir}" \
  --arg message $'# Planning\n\nStill deciding.\n\n<!-- durable-plan: draft -->' \
  '{hook_event_name:"Stop",permission_mode:"plan",cwd:$cwd,
    stop_hook_active:false,last_assistant_message:$message}')")"
readonly draft_output
jq -e '. == {}' <<<"${draft_output}" >/dev/null
if [[ -d "${codex_home}/plans" ]]; then
  printf 'draft created a plans directory\n' >&2
  exit 1
fi

readonly final_message=$'# Plan\n\nBody\n\n<!-- durable-plan: final slug=approved-plan -->'
final_output="$(run_hook "$(jq -cn \
  --arg cwd "${repo_dir}" \
  --arg message "${final_message}" \
  '{hook_event_name:"Stop",permission_mode:"plan",cwd:$cwd,
    stop_hook_active:false,last_assistant_message:$message}')")"
readonly final_output
readonly plan_path="${codex_home}/plans/example-repo/approved-plan.md"
diff -u <(printf '# Plan\n\nBody\n') "${plan_path}"
jq -e \
  --arg plan_path "${plan_path}" \
  --arg repo_dir "${repo_dir}" '
    .systemMessage | contains($plan_path)
    and contains("gpt-5.6-terra")
    and contains($repo_dir)
  ' <<<"${final_output}" >/dev/null

original_inode="$(stat -f '%i' "${plan_path}")"
readonly original_inode
unchanged_output="$(run_hook "$(jq -cn \
  --arg cwd "${repo_dir}" \
  --arg message "${final_message}" \
  '{hook_event_name:"Stop",permission_mode:"plan",cwd:$cwd,
    stop_hook_active:false,last_assistant_message:$message}')")"
readonly unchanged_output
unchanged_inode="$(stat -f '%i' "${plan_path}")"
readonly unchanged_inode
if [[ "${original_inode}" != "${unchanged_inode}" ]]; then
  printf 'identical plan replaced the canonical file\n' >&2
  exit 1
fi
jq -e '.systemMessage | contains("Unchanged")' \
  <<<"${unchanged_output}" >/dev/null

readonly changed_message=$'# Plan\n\nChanged body\n\n<!-- durable-plan: final slug=approved-plan -->'
run_hook "$(jq -cn \
  --arg cwd "${repo_dir}" \
  --arg message "${changed_message}" \
  '{hook_event_name:"Stop",permission_mode:"plan",cwd:$cwd,
    stop_hook_active:false,last_assistant_message:$message}')" >/dev/null
diff -u <(printf '# Plan\n\nChanged body\n') "${plan_path}"

invalid_output="$(run_hook "$(jq -cn \
  --arg cwd "${repo_dir}" \
  --arg message $'# Plan\n\nBody\n\n<!-- durable-plan: final slug=../escape -->' \
  '{hook_event_name:"Stop",permission_mode:"plan",cwd:$cwd,
    stop_hook_active:false,last_assistant_message:$message}')")"
readonly invalid_output
jq -e '.decision == "block"' <<<"${invalid_output}" >/dev/null
if [[ -e "${codex_home}/plans/escape.md" ]]; then
  printf 'invalid slug escaped the plans directory\n' >&2
  exit 1
fi

missing_output="$(run_hook "$(jq -cn \
  --arg cwd "${repo_dir}" \
  --arg message '# Missing marker' \
  '{hook_event_name:"Stop",permission_mode:"plan",cwd:$cwd,
    stop_hook_active:false,last_assistant_message:$message}')")"
readonly missing_output
jq -e '.decision == "block"' <<<"${missing_output}" >/dev/null

retry_output="$(run_hook "$(jq -cn \
  --arg cwd "${repo_dir}" \
  --arg message '# Still missing marker' \
  '{hook_event_name:"Stop",permission_mode:"plan",cwd:$cwd,
    stop_hook_active:true,last_assistant_message:$message}')")"
readonly retry_output
jq -e 'has("decision") | not' <<<"${retry_output}" >/dev/null
jq -e '.systemMessage | contains("not saved")' <<<"${retry_output}" >/dev/null

git -C "${repo_dir}" remote set-url origin git@github.com:example/Example-Repo.git
run_hook "$(jq -cn \
  --arg cwd "${repo_dir}" \
  --arg message $'# SSH Plan\n\nBody\n\n<!-- durable-plan: final slug=ssh-plan -->' \
  '{hook_event_name:"Stop",permission_mode:"plan",cwd:$cwd,
    stop_hook_active:false,last_assistant_message:$message}')" >/dev/null
if [[ ! -f "${codex_home}/plans/example-repo/ssh-plan.md" ]]; then
  printf 'SSH origin did not produce the expected repository key\n' >&2
  exit 1
fi

git -C "${repo_dir}" remote remove origin
run_hook "$(jq -cn \
  --arg cwd "${repo_dir}" \
  --arg message $'# Fallback Plan\n\nBody\n\n<!-- durable-plan: final slug=fallback-plan -->' \
  '{hook_event_name:"Stop",permission_mode:"plan",cwd:$cwd,
    stop_hook_active:false,last_assistant_message:$message}')" >/dev/null
if [[ ! -f "${codex_home}/plans/repo-with-spaces/fallback-plan.md" ]]; then
  printf 'missing origin did not fall back to the Git root basename\n' >&2
  exit 1
fi

readonly preserved_path="${codex_home}/plans/repo-with-spaces/preserved.md"
printf '# Existing\n' >"${preserved_path}"
chmod u-w "${codex_home}/plans/repo-with-spaces"
if run_hook "$(jq -cn \
  --arg cwd "${repo_dir}" \
  --arg message $'# Replacement\n\n<!-- durable-plan: final slug=preserved -->' \
  '{hook_event_name:"Stop",permission_mode:"plan",cwd:$cwd,
    stop_hook_active:false,last_assistant_message:$message}')" |
  jq -e '.systemMessage | contains("not saved")' >/dev/null; then
  :
else
  printf 'failed write did not report a visible error\n' >&2
  exit 1
fi
diff -u <(printf '# Existing\n') "${preserved_path}"
