#!/bin/bash

# Uninstall ACT Lite skill entries for supported agent tools.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
TOOLKIT_PATH="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/codex.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/uninstall-codex.sh"

LITE_SKILLS=(
  "act-config"
  "act-update"
  "act-interview"
  "act-create-spec"
  "act-refine-spec"
  "act-create-issues"
  "act-implement"
)

TOOL=""
CONFIG_DIR=""
CONFIG_DIR_PROVIDED=false

usage() {
  echo "Usage: uninstall.sh --tool [claude|opencode|cursor|codex|gemini|antigravity] [--config-dir <path>]"
}

parse_tool_args "$@"
resolve_claude_config_dir
configure_tool

echo -e "${BLUE}Removing $TOOL_LABEL entries...${NC}"
echo ""

total_removed=0
total_not_found=0

CURSOR_PLUGIN_LINK="$HOME/.cursor/plugins/local/agentic-coding-toolkit"

if [[ "$TOOL" == "cursor" ]]; then
  remove_cursor_plugin_link "$CURSOR_PLUGIN_LINK" "$TOOLKIT_PATH"

  echo ""
  echo -e "${GREEN}✓ Removed $total_removed symlink(s)${NC}"
  echo ""
  echo -e "${CYAN}•${NC} Left shared ACT runtime helpers untouched under $HOME/.config/agentic-coding-toolkit"
  exit 0
fi

SOURCE_DIR="$TOOLKIT_PATH/skills"
TARGET_DIR="$(get_target_dir skills)"

if [ ! -d "$SOURCE_DIR" ]; then
  echo -e "  ${CYAN}•${NC} Lite skills directory not found: $SOURCE_DIR"
else
  for dirname in "${LITE_SKILLS[@]}"; do
    dir="$SOURCE_DIR/$dirname"
    [ -d "$dir" ] || continue
    target="$TARGET_DIR/$dirname"

    if [[ "$TOOL" == "codex" ]]; then
      remove_codex_skill_dir "$SOURCE_DIR/$dirname" "$target" "$dirname" "skills/$dirname/SKILL.md"
    else
      remove_lite_skill_symlink "$target" "$SOURCE_DIR/$dirname" "$dirname"
    fi
  done
fi

echo ""
echo -e "${GREEN}✓ Removed $total_removed symlink(s)${NC}"
echo ""
echo -e "${CYAN}•${NC} Left shared ACT runtime helpers untouched under $HOME/.config/agentic-coding-toolkit"
