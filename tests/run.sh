#!/bin/bash

set -euo pipefail
shopt -s nullglob

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root_dir

readonly scripts=(
  "${root_dir}/tests/test-durable-plan-package.sh"
  "${root_dir}/tests/test-durable-plan-hooks.sh"
  "${root_dir}/tests/test-install-durable-plan.sh"
)

for script in "${scripts[@]}"; do
  "${script}"
done

shellcheck \
  "${root_dir}/plugins/durable-plan/hooks/durable-plan" \
  "${root_dir}/scripts/install-durable-plan" \
  "${root_dir}/tests/fixtures/fake-codex-durable-plan" \
  "${root_dir}/tests/test-durable-plan-hooks.sh" \
  "${root_dir}/tests/test-durable-plan-package.sh" \
  "${root_dir}/tests/test-install-durable-plan.sh" \
  "${root_dir}/tests/run.sh"

shfmt -d -i 2 -ci \
  "${root_dir}/plugins/durable-plan/hooks/durable-plan" \
  "${root_dir}/scripts/install-durable-plan" \
  "${root_dir}/tests/fixtures/fake-codex-durable-plan" \
  "${root_dir}/tests/test-durable-plan-hooks.sh" \
  "${root_dir}/tests/test-durable-plan-package.sh" \
  "${root_dir}/tests/test-install-durable-plan.sh" \
  "${root_dir}/tests/run.sh"
