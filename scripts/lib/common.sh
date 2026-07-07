#!/bin/bash

parse_tool_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tool)
        if [[ -z "${2+x}" || "$2" == --* ]]; then
          usage
          exit 1
        fi
        TOOL="$2"
        shift 2
        ;;
      --config-dir)
        if [[ -z "${2+x}" || -z "$2" || "$2" == --* ]]; then
          echo -e "${RED}Error: --config-dir requires a non-empty value${NC}"
          usage
          exit 1
        fi
        CONFIG_DIR="$2"
        CONFIG_DIR_PROVIDED=true
        shift 2
        ;;
      *)
        echo -e "${RED}Unknown argument: $1${NC}"
        usage
        exit 1
        ;;
    esac
  done

  if [[ -z "$TOOL" ]]; then
    usage
    exit 1
  fi

  if [[ "$TOOL" != "claude" && "$TOOL" != "opencode" && "$TOOL" != "cursor" && "$TOOL" != "codex" && "$TOOL" != "gemini" && "$TOOL" != "antigravity" ]]; then
    echo -e "${RED}Invalid tool: $TOOL${NC}"
    usage
    exit 1
  fi

  if [[ "$CONFIG_DIR_PROVIDED" == true && "$TOOL" != "claude" ]]; then
    echo -e "${RED}Error: --config-dir is only supported with --tool claude${NC}"
    usage
    exit 1
  fi
}

resolve_config_path() {
  local raw_path="$1"

  case "$raw_path" in
    "~") raw_path="$HOME" ;;
    "~/"*) raw_path="$HOME/${raw_path#\~/}" ;;
  esac

  if [[ "$raw_path" == /* ]]; then
    echo "$raw_path"
  else
    echo "$(pwd -P)/$raw_path"
  fi
}

resolve_claude_config_dir() {
  CLAUDE_CONFIG_DIR_RESOLVED=""
  if [[ "$TOOL" == "claude" ]]; then
    if [[ "$CONFIG_DIR_PROVIDED" == true ]]; then
      CLAUDE_CONFIG_DIR_RESOLVED="$(resolve_config_path "$CONFIG_DIR")"
    elif [[ -n "${CLAUDE_CONFIG_DIR:-}" ]]; then
      CLAUDE_CONFIG_DIR_RESOLVED="$(resolve_config_path "$CLAUDE_CONFIG_DIR")"
    else
      CLAUDE_CONFIG_DIR_RESOLVED="$HOME/.claude"
    fi
  fi
}

configure_tool() {
  if [[ "$TOOL" == "claude" ]]; then
    TOOL_LABEL="Claude Code"
  elif [[ "$TOOL" == "opencode" ]]; then
    TOOL_LABEL="OpenCode"
  elif [[ "$TOOL" == "codex" ]]; then
    TOOL_LABEL="Codex"
  elif [[ "$TOOL" == "gemini" || "$TOOL" == "antigravity" ]]; then
    TOOL_LABEL="Antigravity / Gemini CLI"
  else
    TOOL_LABEL="Cursor"
  fi
}

get_target_dir() {
  local folder_type="$1"
  if [[ "$TOOL" == "claude" ]]; then
    echo "$CLAUDE_CONFIG_DIR_RESOLVED/$folder_type"
  elif [[ "$TOOL" == "codex" && "$folder_type" == "skills" ]]; then
    echo "$HOME/.codex/skills"
  elif [[ "$TOOL" == "gemini" || "$TOOL" == "antigravity" ]]; then
    echo "$HOME/.gemini/$folder_type"
  else
    echo "$HOME/.config/opencode/$folder_type"
  fi
}

resolve_symlink_dir_target() {
  local symlink_path="$1"
  local symlink_dir
  local link_target

  if [ ! -L "$symlink_path" ] || [ ! -e "$symlink_path" ]; then
    return 1
  fi

  symlink_dir="$(dirname "$symlink_path")"
  link_target="$(readlink "$symlink_path")"

  (cd "$symlink_dir" && cd "$link_target" 2>/dev/null && pwd -P)
}

is_act_checkout_root() {
  local checkout_root="$1"

  [ -d "$checkout_root" ] || return 1
  [ -f "$checkout_root/.cursor-plugin/plugin.json" ] || return 1
  [ -d "$checkout_root/skills" ] || return 1
}

reset_skill_conflict_state() {
  skill_conflict_mode="normal"
  skill_conflict_old_root=""
  skill_bulk_decision=""
  skill_bulk_count=0
  skill_bulk_replaced=0
  skill_bulk_skipped=0
  skill_all_remaining_decision=""
}

get_act_skill_symlink_old_root() {
  local target="$1"
  local skill_name="$2"
  local resolved_target
  local old_root

  if ! resolved_target="$(resolve_symlink_dir_target "$target")"; then
    return 1
  fi

  case "$resolved_target" in
    */skills/"$skill_name")
      old_root="${resolved_target%/skills/$skill_name}"
      ;;
    *)
      return 1
      ;;
  esac

  if [ "$old_root" = "$TOOLKIT_PATH" ]; then
    return 1
  fi

  if is_act_checkout_root "$old_root"; then
    echo "$old_root"
    return 0
  fi

  return 1
}

prepare_skill_symlink_conflicts() {
  local source_dir="$1"
  local target_dir="$2"
  local dirname
  local target
  local source_path
  local old_root
  local act_conflict_count=0
  local non_act_symlink_conflict_count=0
  local first_old_root=""
  local homogeneous=true

  reset_skill_conflict_state

  for dir in "$source_dir"/*/; do
    [ -d "$dir" ] || continue
    dirname=$(basename "$dir")
    target="$target_dir/$dirname"
    source_path="$(cd "$source_dir/$dirname" && pwd -P)"

    if [ -L "$target" ]; then
      if resolved_target="$(resolve_symlink_dir_target "$target")" && [ "$resolved_target" = "$source_path" ]; then
        continue
      fi

      if old_root="$(get_act_skill_symlink_old_root "$target" "$dirname")"; then
        act_conflict_count=$((act_conflict_count + 1))
        if [ -z "$first_old_root" ]; then
          first_old_root="$old_root"
        elif [ "$first_old_root" != "$old_root" ]; then
          homogeneous=false
        fi
      else
        non_act_symlink_conflict_count=$((non_act_symlink_conflict_count + 1))
      fi
    fi
  done

  if [ "$act_conflict_count" -gt 1 ] && [ "$non_act_symlink_conflict_count" -eq 0 ] && [ "$homogeneous" = true ]; then
    skill_conflict_mode="bulk"
    skill_conflict_old_root="$first_old_root"
    skill_bulk_count=$act_conflict_count
    echo -e "  ${YELLOW}⚠${NC} Found $act_conflict_count ACT skill symlink(s) from another toolkit:"
    echo -e "    Current root: $first_old_root"
    echo -e "    New root: $TOOLKIT_PATH"
    printf "    Replace all %s ACT skill symlinks with this toolkit? [Y/n] " "$act_conflict_count"
    read -n 1 -r
    echo ""
    if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
      skill_bulk_decision="replace"
    else
      skill_bulk_decision="skip"
    fi
  elif [ "$act_conflict_count" -gt 1 ]; then
    skill_conflict_mode="mixed"
  fi
}

install_skill_symlink() {
  local source_path="$1"
  local target="$2"
  local dirname="$3"
  local link_target
  local old_root

  if [ -L "$target" ]; then
    link_target=$(readlink "$target")
    if resolved_target="$(resolve_symlink_dir_target "$target")" && [ "$resolved_target" = "$source_path" ]; then
      echo -e "  ${GREEN}✓${NC} $target ${CYAN}(already exists)${NC}"
      total_existing=$((total_existing + 1))
    elif [ "$skill_conflict_mode" = "bulk" ] && old_root="$(get_act_skill_symlink_old_root "$target" "$dirname")" && [ "$old_root" = "$skill_conflict_old_root" ]; then
      if [ "$skill_bulk_decision" = "replace" ]; then
        rm "$target"
        ln -s "$source_path" "$target"
        echo -e "  ${GREEN}✓${NC} $target ${GREEN}(replaced)${NC}"
        total_replaced=$((total_replaced + 1))
        skill_bulk_replaced=$((skill_bulk_replaced + 1))
      else
        skill_bulk_skipped=$((skill_bulk_skipped + 1))
      fi
    else
      echo -e "  ${YELLOW}⚠${NC} $target points to: $link_target"
      if [ "$skill_conflict_mode" = "mixed" ] && old_root="$(get_act_skill_symlink_old_root "$target" "$dirname")"; then
        if [ "$skill_all_remaining_decision" = "replace" ]; then
          REPLY="y"
        elif [ "$skill_all_remaining_decision" = "skip" ]; then
          REPLY="n"
        else
          printf "    Replace with this toolkit? [y/n/a/q] "
          read -n 1 -r
          echo ""
          if [[ $REPLY =~ ^[Aa]$ ]]; then
            skill_all_remaining_decision="replace"
            REPLY="y"
          elif [[ $REPLY =~ ^[Qq]$ ]]; then
            skill_all_remaining_decision="skip"
            REPLY="n"
          fi
        fi
      else
        printf "    Replace with this toolkit? [Y/n] "
        read -n 1 -r
        echo ""
      fi
      if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
        rm "$target"
        ln -s "$source_path" "$target"
        echo -e "    ${GREEN}Replaced${NC}"
        total_replaced=$((total_replaced + 1))
      else
        echo -e "    ${CYAN}Kept existing${NC}"
      fi
    fi
  elif [ -e "$target" ]; then
    echo -e "  ${YELLOW}⚠${NC} $target exists and is not a symlink"
    printf "    Replace with this toolkit? [Y/n] "
    read -n 1 -r
    echo ""
    if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "$target"
      ln -s "$source_path" "$target"
      echo -e "    ${GREEN}Replaced${NC}"
      total_replaced=$((total_replaced + 1))
    else
      echo -e "    ${CYAN}Kept existing${NC}"
    fi
  else
    ln -s "$source_path" "$target"
    echo -e "  ${GREEN}✓${NC} $target ${GREEN}(new)${NC}"
    total_new=$((total_new + 1))
  fi
}

print_skill_conflict_summary() {
  if [ "$skill_bulk_skipped" -gt 0 ]; then
    echo -e "  ${CYAN}Skipped $skill_bulk_skipped existing skill symlink(s)${NC}"
  fi
}

install_cursor_plugin_link() {
  local link="$1"
  local expected_target="$2"
  local link_target

  if [ -L "$link" ]; then
    link_target=$(readlink "$link")
    if resolved_target="$(resolve_symlink_dir_target "$link")" && [ "$resolved_target" = "$expected_target" ]; then
      echo -e "  ${GREEN}✓${NC} $link ${CYAN}(already exists)${NC}"
      total_existing=$((total_existing + 1))
    else
      echo -e "  ${YELLOW}⚠${NC} $link points to: $link_target"
      read -p "    Replace with this toolkit? [Y/n] " -n 1 -r
      echo ""
      if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
        rm "$link"
        ln -s "$expected_target" "$link"
        echo -e "    ${GREEN}Replaced${NC}"
        total_replaced=$((total_replaced + 1))
      else
        echo -e "    ${CYAN}Kept existing${NC}"
      fi
    fi
  elif [ -e "$link" ]; then
    echo -e "  ${YELLOW}⚠${NC} $link exists and is not a symlink"
    read -p "    Replace with this toolkit? [Y/n] " -n 1 -r
    echo ""
    if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "$link"
      ln -s "$expected_target" "$link"
      echo -e "    ${GREEN}Replaced${NC}"
      total_replaced=$((total_replaced + 1))
    else
      echo -e "    ${CYAN}Kept existing${NC}"
    fi
  else
    ln -s "$expected_target" "$link"
    echo -e "  ${GREEN}✓${NC} $link ${GREEN}(new)${NC}"
    total_new=$((total_new + 1))
  fi
}

remove_lite_skill_symlink() {
  local target="$1"
  local source_dir="$2"
  local skill_name="$3"
  local source_path
  local resolved_target

  source_path="$(cd "$source_dir" && pwd -P)"

  if [ -L "$target" ]; then
    if resolved_target="$(resolve_symlink_dir_target "$target")" && [ "$resolved_target" = "$source_path" ]; then
      rm "$target"
      echo -e "  ${GREEN}✓${NC} Removed $target"
      total_removed=$((total_removed + 1))
    else
      echo -e "  ${YELLOW}⚠${NC} Skipped non-Lite skill symlink: $target"
    fi
  elif [ -e "$target" ]; then
    echo -e "  ${YELLOW}⚠${NC} Skipped non-symlink skill entry: $target"
  else
    total_not_found=$((total_not_found + 1))
  fi
}

remove_cursor_plugin_link() {
  local link="$1"
  local expected_target="$2"
  local link_target

  if [ -L "$link" ]; then
    link_target=$(readlink "$link")
    if resolved_target="$(resolve_symlink_dir_target "$link")" && [ "$resolved_target" = "$expected_target" ]; then
      rm "$link"
      echo -e "  ${GREEN}✓${NC} Removed $link"
      total_removed=$((total_removed + 1))
    else
      echo -e "  ${YELLOW}⚠${NC} Skipped non-Lite Cursor plugin symlink: $link -> $link_target"
    fi
  elif [ -e "$link" ]; then
    echo -e "  ${YELLOW}⚠${NC} Skipped non-symlink Cursor plugin entry: $link"
  else
    echo -e "  ${CYAN}•${NC} Cursor plugin link not found (already removed)"
  fi
}
