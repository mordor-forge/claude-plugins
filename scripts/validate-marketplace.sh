#!/usr/bin/env bash
# Validates the marketplace catalog.
#
# Usage: scripts/validate-marketplace.sh [--plugins]
#   (default)   structural checks with jq + `claude plugin validate .`
#   --plugins   also clone every listed plugin at its pinned ref/sha and run
#               `claude plugin validate` on it (needs network)
#
# Uses the `claude` CLI when installed, otherwise `npx @anthropic-ai/claude-code`.
set -uo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root" || exit 1
catalog=.claude-plugin/marketplace.json

plugins=false
[ "${1:-}" = "--plugins" ] && plugins=true

errors=0
ok() { printf 'ok   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; errors=$((errors + 1)); }

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
if command -v claude >/dev/null 2>&1; then
  claude=(claude)
else
  claude=(npx -y @anthropic-ai/claude-code)
fi

check() {
  if jq -e "$2" "$catalog" >/dev/null 2>&1; then ok "$1"; else fail "$1"; fi
}

if ! jq empty "$catalog" 2>/dev/null; then
  fail "$catalog is not valid JSON"
  exit 1
fi
check "marketplace name is mordor-forge" '.name == "mordor-forge"'
check "every plugin has a kebab-case name" 'all(.plugins[]; .name | test("^[a-z0-9]+(-[a-z0-9]+)*$"))'
check "plugin names are unique" '[.plugins[].name] | length == (unique | length)'
check "every plugin has a description" 'all(.plugins[]; (.description // "") | length > 0)'
check "every plugin source is a remote git repository" 'all(.plugins[]; .source | type == "object" and (.source == "url" or .source == "github" or .source == "git-subdir"))'
check "plugins are sorted by name" '[.plugins[].name] == ([.plugins[].name] | sort)'

if out=$("${claude[@]}" plugin validate . 2>&1); then ok "claude plugin validate ."; else fail "claude plugin validate ."; printf '%s\n' "$out" | sed 's/^/     /'; fi

if $plugins; then
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  while IFS=$'\t' read -r name url ref sha; do
    dir="$work/$name"
    if ! git clone --quiet --filter=blob:none ${ref:+--branch "$ref"} "$url" "$dir" 2>/dev/null; then
      fail "$name: cannot clone $url${ref:+ at $ref}"
      continue
    fi
    if [ -n "$sha" ] && ! git -C "$dir" checkout --quiet "$sha" 2>/dev/null; then
      fail "$name: sha $sha not found in $url"
      continue
    fi
    if [ ! -f "$dir/.claude-plugin/plugin.json" ]; then
      fail "$name: $url has no .claude-plugin/plugin.json${ref:+ at $ref}"
      continue
    fi
    manifest_name=$(jq -r '.name // empty' "$dir/.claude-plugin/plugin.json")
    if [ "$manifest_name" = "$name" ]; then ok "$name: plugin.json name matches"; else fail "$name: plugin.json name is '$manifest_name', catalog says '$name'"; fi
    if out=$("${claude[@]}" plugin validate "$dir" 2>&1); then ok "$name: claude plugin validate"; else fail "$name: claude plugin validate"; printf '%s\n' "$out" | sed 's/^/     /'; fi
  done < <(jq -r '.plugins[] | .source as $s | [.name, ($s.url // ("https://github.com/" + ($s.repo // "") + ".git")), ($s.ref // ""), ($s.sha // "")] | @tsv' "$catalog")
fi

if [ "$errors" -gt 0 ]; then
  echo "$errors check(s) failed"
  exit 1
fi
echo "marketplace ok"
