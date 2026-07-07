#!/bin/bash

codex_skill_generated_for_source() {
  local target_dir="$1"
  local source_path="$2"
  local marker="<!-- ACT generated Codex skill from $source_path. Do not edit this installed copy. -->"
  local line

  [ -d "$target_dir" ] || return 1
  [ -f "$target_dir/SKILL.md" ] || return 1
  [ ! -L "$target_dir/SKILL.md" ] || return 1

  while IFS= read -r line; do
    if [[ "$line" == "$marker" ]]; then
      return 0
    fi
  done < "$target_dir/SKILL.md"
  return 1
}

codex_legacy_command_source_for_skill() {
  local skill_name="$1"

  case "$skill_name" in
    act-update) echo "commands/act-update.md" ;;
    *) return 1 ;;
  esac
}
