#!/bin/bash

remove_codex_skill_dir() {
  local source_dir="$1"
  local target_dir="$2"
  local skill_name="$3"
  local source_path="$4"

  if [[ "$skill_name" != act-* ]]; then
    if [ -e "$target_dir" ]; then
      echo -e "  ${YELLOW}⚠${NC} Skipped non-ACT Codex skill entry: $target_dir"
    else
      total_not_found=$((total_not_found + 1))
    fi
    return
  fi

  if [ ! -L "$target_dir" ] && codex_skill_generated_for_source "$target_dir" "$source_path"; then
    rm -rf "$target_dir"
    echo -e "  ${GREEN}✓${NC} Removed $target_dir"
    total_removed=$((total_removed + 1))
  elif [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
    echo -e "  ${YELLOW}⚠${NC} Skipped non-Lite Codex skill entry: $target_dir"
  else
    total_not_found=$((total_not_found + 1))
  fi
}
