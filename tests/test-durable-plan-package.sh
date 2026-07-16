#!/bin/bash

set -euo pipefail
shopt -s nullglob

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root_dir
readonly marketplace_path="${root_dir}/.agents/plugins/marketplace.json"
readonly manifest_path="${root_dir}/plugins/durable-plan/.codex-plugin/plugin.json"

jq -e '
  .name == "mochi-mart"
  and .interface.displayName == "Mochi Mart"
  and (.plugins | length) == 1
  and .plugins[0].name == "durable-plan"
  and .plugins[0].source.source == "local"
  and .plugins[0].source.path == "./plugins/durable-plan"
  and .plugins[0].policy.installation == "AVAILABLE"
  and .plugins[0].policy.authentication == "ON_INSTALL"
  and .plugins[0].category == "Productivity"
' "${marketplace_path}" >/dev/null

jq -e '
  .name == "durable-plan"
  and .version == "0.1.0"
  and .description == "Save decision-complete Codex plans and hand them to Terra."
  and .author.name == "Mochi Mart Maintainer"
  and .author.url == "https://github.com/rktoomey/mochi-mart"
  and .homepage == "https://github.com/rktoomey/mochi-mart#durable-plan"
  and .repository == "https://github.com/rktoomey/mochi-mart"
  and .license == "MIT"
  and .keywords == ["codex", "planning", "handoff", "terra"]
  and .interface.displayName == "Durable Plan"
  and .interface.shortDescription == "Persist final Plan-mode decisions"
  and .interface.longDescription == "Persist final plans and display a Terra command."
  and .interface.developerName == "Mochi Mart Maintainer"
  and .interface.category == "Productivity"
  and .interface.capabilities == ["Lifecycle hooks", "Write"]
  and .interface.defaultPrompt == ["Use Durable Plan in Plan mode."]
  and (has("hooks") | not)
  and (has("skills") | not)
  and (has("apps") | not)
  and (has("mcpServers") | not)
' "${manifest_path}" >/dev/null
