#!/bin/bash

install_codex_skill_dir() {
  local source_dir="$1"
  local target_dir="$2"
  local source_path="$3"
  local source_skill="$source_dir/SKILL.md"
  local tmp_dir="$target_dir.tmp.$$"
  local target_exists=false
  local replace_allowed=false
  local entry
  local basename
  local skill_name
  local legacy_source_path

  skill_name="$(basename "$target_dir")"

  if [ ! -f "$source_skill" ]; then
    echo -e "  ${RED}✗${NC} Missing skill source: $source_skill"
    exit 1
  fi

  if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
    target_exists=true
    if [ ! -L "$target_dir" ] && codex_skill_generated_for_source "$target_dir" "$source_path"; then
      replace_allowed=true
    elif [ ! -L "$target_dir" ] && legacy_source_path="$(codex_legacy_command_source_for_skill "$skill_name")" && codex_skill_generated_for_source "$target_dir" "$legacy_source_path"; then
      replace_allowed=true
    else
      echo -e "  ${YELLOW}⚠${NC} $target_dir exists and is not an ACT-generated Codex skill"
      read -p "    Replace with generated ACT Lite Codex skill? [Y/n] " -n 1 -r
      echo ""
      if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
        replace_allowed=true
      fi
    fi
  else
    replace_allowed=true
  fi

  if [ "$replace_allowed" != true ]; then
    echo -e "    ${CYAN}Kept existing${NC}"
    return
  fi

  rm -rf "$tmp_dir"
  if ! mkdir -p "$tmp_dir"; then
    echo -e "  ${RED}✗${NC} Failed to create temporary directory: $tmp_dir"
    exit 1
  fi

  if ! node "$ACT_SKILL_CODEX_TRANSFORM_SCRIPT" --input "$source_skill" --output "$tmp_dir/SKILL.md" --source-path "$source_path"; then
    echo -e "  ${RED}✗${NC} Failed to generate Codex skill from $source_skill"
    rm -rf "$tmp_dir"
    exit 1
  fi

  for entry in "$source_dir"/*; do
    [ -e "$entry" ] || continue
    basename="$(basename "$entry")"
    if [[ "$basename" == "SKILL.md" ]]; then
      continue
    fi
    if ! ln -s "$entry" "$tmp_dir/$basename"; then
      echo -e "  ${RED}✗${NC} Failed to link Codex skill auxiliary entry: $entry"
      rm -rf "$tmp_dir"
      exit 1
    fi
  done

  if [ "$target_exists" = true ]; then
    rm -rf "$target_dir"
  fi
  if ! mv "$tmp_dir" "$target_dir"; then
    echo -e "  ${RED}✗${NC} Failed to install generated Codex skill: $target_dir"
    rm -rf "$tmp_dir"
    exit 1
  fi

  if [ "$target_exists" = true ]; then
    total_replaced=$((total_replaced + 1))
    echo -e "  ${GREEN}✓${NC} $target_dir ${GREEN}(regenerated)${NC}"
  else
    total_new=$((total_new + 1))
    echo -e "  ${GREEN}✓${NC} $target_dir ${GREEN}(generated)${NC}"
  fi
}
