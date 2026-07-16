#!/bin/bash

set -euo pipefail
shopt -s nullglob

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root_dir
test_dir="$(mktemp -d)"
readonly test_dir
readonly installer="${root_dir}/scripts/install-durable-plan"
readonly fake_codex="${root_dir}/tests/fixtures/fake-codex-durable-plan"
jq_bin="$(command -v jq)"
readonly jq_bin

cleanup() {
  rm -rf "${test_dir}"
}
trap cleanup EXIT

run_installer() {
  local mode="$1"
  local command_log="$2"

  COMMAND_LOG="${command_log}" \
    CODEX_BIN="${fake_codex}" \
    JQ_BIN="${jq_bin}" \
    FAKE_MARKETPLACE_MODE="${mode}" \
    "${installer}"
}

for missing_variable in CODEX_BIN JQ_BIN; do
  command_log="${test_dir}/missing-${missing_variable}.log"
  if env \
    COMMAND_LOG="${command_log}" \
    CODEX_BIN="${fake_codex}" \
    JQ_BIN="${jq_bin}" \
    FAKE_MARKETPLACE_MODE=absent \
    "${missing_variable}=${test_dir}/missing-command" \
    "${installer}" >/dev/null 2>&1; then
    printf 'installer accepted missing %s\n' "${missing_variable}" >&2
    exit 1
  fi
  if [[ -s "${command_log}" ]]; then
    printf 'installer mutated state before checking %s\n' \
      "${missing_variable}" >&2
    exit 1
  fi
done

readonly absent_log="${test_dir}/absent.log"
absent_output="$(run_installer absent "${absent_log}")"
readonly absent_output
if [[ "$(rg -c '^plugin marketplace add ' "${absent_log}")" -ne 1 ]]; then
  printf 'installer did not add an absent marketplace exactly once\n' >&2
  exit 1
fi
rg -q '^plugin marketplace add rktoomey/mochi-mart$' "${absent_log}"
rg -q '^plugin add durable-plan@mochi-mart$' "${absent_log}"
rg -q '^features enable hooks$' "${absent_log}"
if [[ "${absent_output}" != *'/hooks'* ]] ||
  [[ "${absent_output}" != *'durable-plan'* ]] ||
  [[ "${absent_output}" != *'trust only'* ]]; then
  printf 'installer omitted the manual hook trust boundary\n' >&2
  exit 1
fi
if [[ "${absent_output}" == *'--dangerously-bypass-hook-trust'* ]]; then
  printf 'installer recommended bypassing hook trust\n' >&2
  exit 1
fi

readonly matching_log="${test_dir}/matching.log"
run_installer matching "${matching_log}" >/dev/null
if rg -q '^plugin marketplace add ' "${matching_log}"; then
  printf 'installer re-added a matching marketplace\n' >&2
  exit 1
fi
rg -q '^plugin marketplace upgrade mochi-mart$' "${matching_log}"
rg -q '^plugin add durable-plan@mochi-mart$' "${matching_log}"
rg -q '^features enable hooks$' "${matching_log}"

readonly repeated_log="${test_dir}/repeated.log"
run_installer matching "${repeated_log}" >/dev/null
diff -u "${matching_log}" "${repeated_log}"

readonly fresh_codex_home="${test_dir}/fresh-home/.codex"
readonly fresh_home_log="${test_dir}/fresh-home.log"
if COMMAND_LOG="${fresh_home_log}" \
  CODEX_BIN="${fake_codex}" \
  JQ_BIN="${jq_bin}" \
  CODEX_HOME="${fresh_codex_home}" \
  FAKE_MARKETPLACE_MODE=absent \
  "${installer}" >/dev/null; then
  :
else
  printf 'installer did not initialize a missing CODEX_HOME\n' >&2
  exit 1
fi
if [[ ! -d "${fresh_codex_home}" ]]; then
  printf 'installer did not create CODEX_HOME\n' >&2
  exit 1
fi

readonly mismatch_log="${test_dir}/mismatch.log"
if run_installer mismatch "${mismatch_log}" >/dev/null 2>&1; then
  printf 'installer accepted a marketplace name collision\n' >&2
  exit 1
fi
if rg -q '^plugin add |^features enable |^plugin marketplace (add|upgrade) ' \
  "${mismatch_log}"; then
  printf 'installer mutated state after a marketplace collision\n' >&2
  exit 1
fi
