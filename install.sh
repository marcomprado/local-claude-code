#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# local-claude installer
# Configure Claude Code to use any LLM server
# ============================================================

# --- Constants & Colors ---

if [ -t 1 ]; then
  BOLD='\033[1m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  RED='\033[0;31m'
  RESET='\033[0m'
else
  BOLD='' GREEN='' YELLOW='' CYAN='' RED='' RESET=''
fi

CONFIG_DIR="$HOME/.claude"
CONFIG_FILE="$CONFIG_DIR/localllm.json"
ALIAS_NAME="local-claude"
LAUNCHER_DIR="$HOME/.local/bin"
LAUNCHER_FILE="$LAUNCHER_DIR/$ALIAS_NAME"
ALIAS_MARKER="# --- local-claude alias (added by local-claude installer) ---"

trap 'printf "\n${RED}Installation cancelled.${RESET}\n"; exit 1' INT

# --- Utility Functions ---

print_header() {
  printf "\n${BOLD}${CYAN}"
  printf "============================================\n"
  printf "   local-claude installer\n"
  printf "   Use Claude Code with any LLM server\n"
  printf "============================================${RESET}\n\n"
}

print_step() {
  printf "${BOLD}${CYAN}[%s/%s]${RESET} ${BOLD}%s${RESET}\n" "$1" "$2" "$3"
}

print_success() {
  printf "  ${GREEN}[ok]${RESET} %s\n" "$1"
}

print_warn() {
  printf "  ${YELLOW}[!]${RESET} %s\n" "$1"
}

print_error() {
  printf "  ${RED}[error]${RESET} %s\n" "$1"
}

prompt_input() {
  local prompt_text="$1"
  local default_val="${2:-}"
  local result

  if [ -n "$default_val" ]; then
    printf "${CYAN}> %s [%s]:${RESET} " "$prompt_text" "$default_val"
  else
    printf "${CYAN}> %s:${RESET} " "$prompt_text"
  fi

  read -r result
  if [ -z "$result" ] && [ -n "$default_val" ]; then
    result="$default_val"
  fi
  echo "$result"
}

validate_url() {
  local url="$1"
  if [[ "$url" =~ ^https?://[^[:space:]]+ ]]; then
    return 0
  fi
  return 1
}

detect_shell_rc() {
  case "$(basename "$SHELL")" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash)
      if [ -f "$HOME/.bash_profile" ]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
    *)    echo "$HOME/.profile" ;;
  esac
}

# --- JSON Generation ---

generate_config() {
  local url="$1"
  local api_key="$2"
  local model="$3"
  local timeout="$4"

  local api_key_line=""
  if [ -n "$api_key" ]; then
    api_key_line="        \"ANTHROPIC_API_KEY\": \"${api_key}\","
  fi

  cat <<EOF
{
    "env": {
        "ANTHROPIC_BASE_URL": "${url}",
${api_key_line:+${api_key_line}
}        "API_TIMEOUT_MS": "${timeout}",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1,
        "ANTHROPIC_MODEL": "${model}",
        "ANTHROPIC_SMALL_FAST_MODEL": "${model}",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "${model}",
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "${model}",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${model}"
    }
}
EOF
}

# --- Install ---

do_install() {
  print_header

  # Preflight checks
  printf "${BOLD}Checking prerequisites...${RESET}\n"

  if [ ! -d "$CONFIG_DIR" ]; then
    print_error "Directory $CONFIG_DIR not found."
    printf "\n  ${BOLD}Claude Code does not appear to be installed.${RESET}\n"
    printf "  Install it using one of the following commands:\n\n"
    printf "  ${CYAN}Mac / Linux / WSL:${RESET}\n"
    printf "    curl -fsSL https://claude.ai/install.sh | bash\n\n"
    printf "  ${CYAN}PowerShell:${RESET}\n"
    printf "    irm https://claude.ai/install.ps1 | iex\n\n"

    printf "${CYAN}> Would you like to install Claude Code now? [Y/n]:${RESET} "
    read -r do_install_claude
    if [[ "$do_install_claude" =~ ^[nN]$ ]]; then
      printf "${YELLOW}Aborted. Install Claude Code first and run this script again.${RESET}\n"
      exit 1
    fi

    printf "\n${BOLD}Installing Claude Code...${RESET}\n"
    curl -fsSL https://claude.ai/install.sh | bash

    # Verify installation succeeded
    if [ ! -d "$CONFIG_DIR" ]; then
      print_error "Installation failed. $CONFIG_DIR still not found."
      exit 1
    fi
    print_success "Claude Code installed successfully"
  else
    print_success "$CONFIG_DIR directory found"
  fi

  if [ -f "$CONFIG_FILE" ]; then
    print_warn "Config already exists at $CONFIG_FILE"
    printf "${CYAN}> Overwrite? [y/N]:${RESET} "
    read -r overwrite
    if [[ ! "$overwrite" =~ ^[yY]$ ]]; then
      printf "${YELLOW}Aborted.${RESET}\n"
      exit 0
    fi
  fi

  printf "\n"

  # Step 1: Server URL
  local total_steps=3
  local server_url
  local attempts=0

  print_step 1 $total_steps "LLM Server URL"
  printf "  Enter the base URL of your LLM server.\n"
  printf "  Example: ${CYAN}http://192.168.1.1:1234${RESET}\n"

  while true; do
    server_url=$(prompt_input "Server URL" "http://localhost:1234")
    if validate_url "$server_url"; then
      break
    fi
    attempts=$((attempts + 1))
    if [ $attempts -ge 3 ]; then
      print_error "Invalid URL after 3 attempts. Aborting."
      exit 1
    fi
    print_error "Invalid URL. Must start with http:// or https://"
  done
  printf "\n"

  # Step 2: API Key
  print_step 2 $total_steps "API Key (optional)"
  printf "  If your server requires an API key, enter it below.\n"
  printf "  Leave blank to skip.\n"
  local api_key
  api_key=$(prompt_input "API Key" "")
  printf "\n"

  # Step 3: Model Name
  print_step 3 $total_steps "Model Name"
  printf "  Enter the model identifier your server exposes.\n"
  printf "  This will be used for all Claude model slots.\n"
  local model_name
  model_name=$(prompt_input "Model name" "default_model")
  printf "\n"

  # Generate config
  local timeout="3000000"
  printf "${BOLD}Generating config...${RESET}\n"
  generate_config "$server_url" "$api_key" "$model_name" "$timeout" > "$CONFIG_FILE"
  print_success "Written to $CONFIG_FILE"
  printf "\n"

  # Launcher setup
  printf "${BOLD}How would you like to launch local-claude?${RESET}\n"
  printf "  ${CYAN}[1]${RESET} Shell alias (adds '${ALIAS_NAME}' alias to your shell config)\n"
  printf "  ${CYAN}[2]${RESET} Launcher script (creates ${LAUNCHER_FILE})\n"
  printf "  ${CYAN}[3]${RESET} Skip (I'll run it manually)\n"

  local choice
  choice=$(prompt_input "Choice" "1")

  printf "\n"

  case "$choice" in
    1)
      local rc_file
      rc_file=$(detect_shell_rc)
      local alias_line="alias ${ALIAS_NAME}='claude --settings ${CONFIG_FILE}'"

      if grep -qF "$ALIAS_NAME" "$rc_file" 2>/dev/null; then
        print_warn "Alias already exists in $rc_file, updating..."
        sed -i.bak "/${ALIAS_NAME}/d" "$rc_file"
        rm -f "${rc_file}.bak"
      fi

      {
        echo ""
        echo "$ALIAS_MARKER"
        echo "$alias_line"
      } >> "$rc_file"

      print_success "Alias added to $rc_file"
      printf "  Run: ${CYAN}source %s${RESET}\n" "$rc_file"
      ;;
    2)
      mkdir -p "$LAUNCHER_DIR"
      cat > "$LAUNCHER_FILE" <<SCRIPT
#!/usr/bin/env bash
exec claude --settings ${CONFIG_FILE} "\$@"
SCRIPT
      chmod +x "$LAUNCHER_FILE"
      print_success "Launcher created at $LAUNCHER_FILE"

      if [[ ":$PATH:" != *":$LAUNCHER_DIR:"* ]]; then
        print_warn "$LAUNCHER_DIR is not on your PATH."
        printf "  Add this to your shell config: ${CYAN}export PATH=\"%s:\$PATH\"${RESET}\n" "$LAUNCHER_DIR"
      fi
      ;;
    3)
      print_success "Skipped launcher setup."
      printf "  Run manually: ${CYAN}claude --settings %s${RESET}\n" "$CONFIG_FILE"
      ;;
    *)
      print_warn "Invalid choice, skipping launcher setup."
      printf "  Run manually: ${CYAN}claude --settings %s${RESET}\n" "$CONFIG_FILE"
      ;;
  esac

  printf "\n${BOLD}${GREEN}"
  printf "============================================\n"
  printf "  Installation complete!\n"
  printf "  Run '${ALIAS_NAME}' to start.\n"
  printf "============================================${RESET}\n\n"
}

# --- Uninstall ---

do_uninstall() {
  print_header
  printf "${BOLD}Uninstalling local-claude...${RESET}\n\n"

  # Remove config
  if [ -f "$CONFIG_FILE" ]; then
    rm -f "$CONFIG_FILE"
    print_success "Removed $CONFIG_FILE"
  else
    print_warn "$CONFIG_FILE not found, skipping."
  fi

  # Remove alias from shell rc
  local rc_file
  rc_file=$(detect_shell_rc)
  if grep -qF "$ALIAS_NAME" "$rc_file" 2>/dev/null; then
    sed -i.bak "/$ALIAS_MARKER/d;/alias ${ALIAS_NAME}/d" "$rc_file"
    rm -f "${rc_file}.bak"
    print_success "Removed alias from $rc_file"
  else
    print_warn "No alias found in $rc_file"
  fi

  # Remove launcher script
  if [ -f "$LAUNCHER_FILE" ]; then
    rm -f "$LAUNCHER_FILE"
    print_success "Removed $LAUNCHER_FILE"
  else
    print_warn "$LAUNCHER_FILE not found, skipping."
  fi

  printf "\n${BOLD}${GREEN}Uninstall complete.${RESET}\n\n"
}

# --- Help ---

show_help() {
  printf "Usage: %s [OPTIONS]\n\n" "$(basename "$0")"
  printf "Options:\n"
  printf "  --uninstall    Remove local-claude configuration and aliases\n"
  printf "  --help, -h     Show this help message\n"
  printf "\nWith no options, runs the interactive installer.\n"
}

# --- Entry Point ---

main() {
  case "${1:-}" in
    --uninstall) do_uninstall ;;
    --help|-h)   show_help ;;
    *)           do_install ;;
  esac
}

main "$@"
