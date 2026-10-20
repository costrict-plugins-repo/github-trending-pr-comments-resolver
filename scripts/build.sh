#!/usr/bin/env bash
# Compatible with bash 3.2+ (macOS default ships bash 3.2; no associative arrays).
set -euo pipefail

cd "$(dirname "$0")/.."

ALL_AGENTS=(claude codex augment junie roo)

# Resolve output path for an agent (case statement instead of associative array).
out_path_for() {
  case "$1" in
    claude)  echo "skills/resolve-comments/SKILL.md" ;;
    codex)   echo "dist/codex/skills/resolve-comments/SKILL.md" ;;
    augment) echo "dist/augment/skills/resolve-comments/SKILL.md" ;;
    junie)   echo "dist/junie/.junie/skills/resolve-comments/SKILL.md" ;;
    roo)     echo "dist/roo/.roo/skills/resolve-comments/SKILL.md" ;;
    *) echo "ERROR: unknown agent '$1'" >&2; return 1 ;;
  esac
}

plugin_package_dir_for() {
  case "$1" in
    claude)  echo "plugins/claude/pr-comments-resolver" ;;
    codex)   echo "plugins/codex/pr-comments-resolver" ;;
    augment) echo "plugins/augment/pr-comments-resolver" ;;
    *) return 1 ;;
  esac
}

plugin_manifest_dir_for() {
  case "$1" in
    claude)  echo ".claude-plugin" ;;
    codex)   echo ".codex-plugin" ;;
    augment) echo ".augment-plugin" ;;
    *) return 1 ;;
  esac
}

plugin_manifest_src_for() {
  case "$1" in
    claude)  echo ".claude-plugin/plugin.json" ;;
    codex)   echo ".codex-plugin/plugin.json" ;;
    augment) echo ".augment-plugin/plugin.json" ;;
    *) return 1 ;;
  esac
}

skill_root_dir_for() {
  case "$1" in
    claude)  echo "skills" ;;
    codex)   echo "dist/codex/skills" ;;
    augment) echo "dist/augment/skills" ;;
    junie)   echo "dist/junie/.junie/skills" ;;
    roo)     echo "dist/roo/.roo/skills" ;;
    *) return 1 ;;
  esac
}

package_marketplace_plugin() {
  local agent="$1"
  local package_dir
  local manifest_dir
  local manifest_src
  local tmp_manifest

  package_dir="$(plugin_package_dir_for "$agent")" || return 0
  manifest_dir="$(plugin_manifest_dir_for "$agent")"
  manifest_src="$(plugin_manifest_src_for "$agent")"

  mkdir -p "$package_dir/$manifest_dir" "$package_dir/skills"
  rm -rf "$package_dir/skills/resolve-comments"
  cp -R "$(skill_root_dir_for "$agent")/resolve-comments" "$package_dir/skills/"
  cp icon.png "$package_dir/icon.png"

  tmp_manifest="$package_dir/$manifest_dir/plugin.json"
  cp "$manifest_src" "$tmp_manifest"

  case "$agent" in
    codex|augment)
      sed -i.bak 's#"skills": "\./dist/[a-z]*/skills/"#"skills": "./skills/"#' "$tmp_manifest"
      rm -f "$tmp_manifest.bak"
      ;;
  esac
}

build_one() {
  local agent="$1"
  local adapter_dir="adapters/${agent}"
  local out
  out="$(out_path_for "$agent")"

  test -d "$adapter_dir" || { echo "ERROR: missing adapter dir: $adapter_dir" >&2; return 1; }
  test -f "$adapter_dir/frontmatter.yaml" || { echo "ERROR: missing frontmatter.yaml for $agent" >&2; return 1; }
  test -f "$adapter_dir/prelude.md" || { echo "ERROR: missing prelude.md for $agent" >&2; return 1; }

  mkdir -p "$(dirname "$out")"

  # Concatenate: frontmatter wrapper + prelude + kernel (with placeholder substitution)
  {
    printf -- '---\n'
    cat "$adapter_dir/frontmatter.yaml"
    printf -- '---\n\n'
    cat "$adapter_dir/prelude.md"
    printf '\n'
    python3 scripts/substitute.py core/kernel.md "$adapter_dir/snippets"
  } > "$out"

  echo "Built $agent -> $out"
  build_platforms "$agent"
  package_marketplace_plugin "$agent"
}

build_platforms() {
  local agent="$1"
  local adapter_dir="adapters/${agent}"
  local out_skill
  out_skill="$(out_path_for "$agent")"
  local out_platforms_dir
  out_platforms_dir="$(dirname "$out_skill")/platforms"

  mkdir -p "$out_platforms_dir"

  shopt -s nullglob
  for src in core/platforms/*.md; do
    local name
    name="$(basename "$src")"
    python3 scripts/substitute.py "$src" "$adapter_dir/snippets" > "$out_platforms_dir/$name"
  done
  shopt -u nullglob
}

# Args: agent name(s) or 'all'
if [ $# -eq 0 ] || [ "$1" = "all" ]; then
  for agent in "${ALL_AGENTS[@]}"; do
    build_one "$agent"
  done
else
  for agent in "$@"; do
    build_one "$agent"
  done
fi
