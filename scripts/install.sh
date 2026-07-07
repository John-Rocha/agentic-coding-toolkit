#!/bin/bash

# Install ACT Lite skills for supported agent tools.

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
source "$SCRIPT_DIR/lib/install-codex.sh"

TOOL=""
CONFIG_DIR=""
CONFIG_DIR_PROVIDED=false

usage() {
  echo "Usage: install.sh --tool [claude|opencode|cursor|codex|gemini|antigravity] [--config-dir <path>]"
}

parse_tool_args "$@"
resolve_claude_config_dir
configure_tool

ACT_CONFIG_ROOT="$HOME/.config/agentic-coding-toolkit"
ACT_SHARED_BIN_DIR="$ACT_CONFIG_ROOT/bin"
ACT_SHARED_RUNTIME_HELPER="act-run-script.js"
ACT_SKILL_CODEX_TRANSFORM_SCRIPT="$TOOLKIT_PATH/scripts/lib/transform-skill-codex.js"
CURSOR_PLUGIN_MANIFEST="$TOOLKIT_PATH/.cursor-plugin/plugin.json"
CURSOR_LOCAL_PLUGIN_DIR="$HOME/.cursor/plugins/local"
CURSOR_PLUGIN_LINK="$CURSOR_LOCAL_PLUGIN_DIR/agentic-coding-toolkit"
LITE_SKILLS=(
  "act-config"
  "act-update"
  "act-interview"
  "act-create-spec"
  "act-refine-spec"
  "act-create-issues"
  "act-implement"
)

if ! command -v node &>/dev/null; then
  echo -e "${RED}Error: Node.js is required but not found in PATH.${NC}"
  echo "Node is needed to install ACT Lite runtime settings."
  exit 1
fi

if ! node "$TOOLKIT_PATH/scripts/lib/bootstrap-act-settings.js"; then
  exit 1
fi

echo -e "${BLUE}Installing shared ACT runtime helper...${NC}"
if ! mkdir -p "$ACT_SHARED_BIN_DIR"; then
  echo -e "  ${RED}✗${NC} Failed to create helper directory: $ACT_SHARED_BIN_DIR"
  exit 1
fi
helper_source="$TOOLKIT_PATH/scripts/lib/$ACT_SHARED_RUNTIME_HELPER"
helper_target="$ACT_SHARED_BIN_DIR/$ACT_SHARED_RUNTIME_HELPER"
if [ ! -f "$helper_source" ]; then
  echo -e "  ${RED}✗${NC} Missing helper source: $helper_source"
  exit 1
fi
if ! cp "$helper_source" "$helper_target"; then
  echo -e "  ${RED}✗${NC} Failed to install helper: $helper_target"
  exit 1
fi
if ! chmod 755 "$helper_target"; then
  echo -e "  ${RED}✗${NC} Failed to mark helper executable: $helper_target"
  exit 1
fi
echo -e "  ${GREEN}✓${NC} Installed $helper_target"

echo -e "${BLUE}Creating $TOOL_LABEL entries...${NC}"
echo ""

total_new=0
total_existing=0
total_replaced=0

if [[ "$TOOL" == "cursor" ]]; then
  echo -e "${BLUE}Installing Cursor local plugin...${NC}"

  if [ ! -f "$CURSOR_PLUGIN_MANIFEST" ]; then
    echo -e "  ${RED}✗${NC} Missing Cursor plugin manifest: $CURSOR_PLUGIN_MANIFEST"
    exit 1
  fi

  if ! mkdir -p "$CURSOR_LOCAL_PLUGIN_DIR"; then
    echo -e "  ${RED}✗${NC} Failed to create directory: $CURSOR_LOCAL_PLUGIN_DIR"
    exit 1
  fi

  install_cursor_plugin_link "$CURSOR_PLUGIN_LINK" "$TOOLKIT_PATH"

  echo ""
  echo -e "${GREEN}✓ Install entries: $total_new new, $total_replaced replaced, $total_existing already existed${NC}"
  exit 0
fi

SOURCE_DIR="$TOOLKIT_PATH/skills"
TARGET_DIR="$(get_target_dir skills)"

if [ ! -d "$SOURCE_DIR" ]; then
  echo -e "  ${RED}✗${NC} Missing Lite skills directory: $SOURCE_DIR"
  exit 1
fi

if ! mkdir -p "$TARGET_DIR"; then
  echo -e "  ${RED}✗${NC} Failed to create directory: $TARGET_DIR"
  exit 1
fi

if [[ "$TOOL" != "codex" ]]; then
  reset_skill_conflict_state
fi

for dirname in "${LITE_SKILLS[@]}"; do
  dir="$SOURCE_DIR/$dirname"
  if [ ! -d "$dir" ]; then
    echo -e "  ${RED}✗${NC} Missing Lite skill: $dir"
    exit 1
  fi
  target="$TARGET_DIR/$dirname"
  source_path="$(cd "$SOURCE_DIR/$dirname" && pwd -P)"

  if [[ "$TOOL" == "codex" ]]; then
    install_codex_skill_dir "$SOURCE_DIR/$dirname" "$target" "skills/$dirname/SKILL.md"
  else
    install_skill_symlink "$source_path" "$target" "$dirname"
  fi
done

if [[ "$TOOL" != "codex" ]]; then
  print_skill_conflict_summary
fi

if [[ "$TOOL" == "codex" ]]; then
  echo -e "${CYAN}•${NC} Restart Codex if ACT Lite skills do not appear or still show old content"
fi

echo ""
echo -e "${GREEN}✓ Install entries: $total_new new, $total_replaced replaced, $total_existing already existed${NC}"
