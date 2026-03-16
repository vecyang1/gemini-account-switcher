#!/usr/bin/env bash
set -e

# Configuration
ACCOUNTS_DIR="$HOME/.gemini/accounts"
OAUTH_FILE="$HOME/.gemini/oauth_creds.json"
GOOGLE_ACCTS_FILE="$HOME/.gemini/google_accounts.json"
MCP_OAUTH_FILE="$HOME/.gemini/mcp-oauth-tokens-v2.json"

# Setup directories and Git
setup_environment() {
  if [ ! -d "$ACCOUNTS_DIR" ]; then
    mkdir -p "$ACCOUNTS_DIR"
  fi

  if [ ! -d "$ACCOUNTS_DIR/.git" ]; then
    cd "$ACCOUNTS_DIR" || exit 1
    git init -q
    echo "Initialized git repository for account backups to ensure zero data loss."
  fi
}

error_exit() {
  echo "❌ Error: $1" >&2
  exit 1
}

warn() {
  echo "⚠️ Warning: $1" >&2
}

info() {
  echo "✅ $1"
}

# Safely extract email from google_accounts.json
get_current_email() {
  if [ ! -f "$GOOGLE_ACCTS_FILE" ]; then
    return 0
  fi
  
  # Use jq if available for robust parsing, fallback to grep
  if command -v jq >/dev/null 2>&1; then
    jq -r '.active // empty' "$GOOGLE_ACCTS_FILE" 2>/dev/null || true
  else
    grep -o '"active": *"[^"]*"' "$GOOGLE_ACCTS_FILE" | cut -d'"' -f4 || true
  fi
}

save_current_account() {
  local email=$(get_current_email)
  
  if [ -z "$email" ]; then
    warn "No active account found. Nothing to save."
    return 0
  fi

  local account_dir="$ACCOUNTS_DIR/$email"
  mkdir -p "$account_dir"
  
  local copied=false
  if [ -f "$OAUTH_FILE" ]; then
    cp "$OAUTH_FILE" "$account_dir/oauth_creds.json"
    copied=true
  fi
  
  if [ -f "$GOOGLE_ACCTS_FILE" ]; then
    cp "$GOOGLE_ACCTS_FILE" "$account_dir/google_accounts.json"
    copied=true
  fi

  if [ -f "$MCP_OAUTH_FILE" ]; then
    cp "$MCP_OAUTH_FILE" "$account_dir/mcp-oauth-tokens-v2.json"
    copied=true
  fi

  if [ "$copied" = true ]; then
    cd "$ACCOUNTS_DIR" || error_exit "Could not access accounts directory."
    git add .
    
    # Only commit if there are changes
    if ! git diff --cached --quiet; then
      git commit -qm "Auto-backup account state: $email at $(date)"
      info "Successfully saved and backed up account: $email"
    else
      info "Account '$email' is already up to date in backups."
    fi
  else
    warn "No credentials found to save for $email."
  fi
}

list_accounts() {
  echo "Available accounts:"
  local accounts=$(find "$ACCOUNTS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.git' -exec basename {} \;)
  
  if [ -z "$accounts" ]; then
    echo "  (No accounts saved yet)"
  else
    local current=$(get_current_email)
    for acc in $accounts; do
      if [ "$acc" = "$current" ]; then
        echo "  * $acc (active)"
      else
        echo "    $acc"
      fi
    done
  fi
}

switch_account() {
  local target_email="$1"
  local target_dir=""

  if [ -z "$target_email" ]; then
    # Interactive mode
    echo "Available accounts:"
    local accounts=($(cd "$ACCOUNTS_DIR" && find . -mindepth 1 -maxdepth 1 -type d ! -name '.git' -exec basename {} \;))
    
    if [ ${#accounts[@]} -eq 0 ]; then
      error_exit "No accounts saved yet."
    fi

    local current=$(get_current_email)
    for i in "${!accounts[@]}"; do
      local acc="${accounts[$i]}"
      local marker="  "
      if [ "$acc" = "$current" ]; then
        marker="* "
      fi
      echo "  $((i+1)). $marker$acc"
    done
    
    echo ""
    read -p "Enter number to switch (or press Enter to cancel): " choice
    if [ -z "$choice" ]; then
      echo "Cancelled."
      exit 0
    fi
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#accounts[@]}" ]; then
      error_exit "Invalid selection."
    fi
    
    target_email="${accounts[$((choice-1))]}"
  fi

  target_dir="$ACCOUNTS_DIR/$target_email"

  if [ ! -d "$target_dir" ]; then
    error_exit "Account '$target_email' not found in backups. Use 'gemini-switch ls' to view available."
  fi

  # Save current before switching to prevent data loss
  save_current_account

  if [ -f "$target_dir/oauth_creds.json" ]; then
    cp "$target_dir/oauth_creds.json" "$OAUTH_FILE"
  else
    warn "Target oauth_creds.json missing."
  fi
  
  if [ -f "$target_dir/google_accounts.json" ]; then
    cp "$target_dir/google_accounts.json" "$GOOGLE_ACCTS_FILE"
  else
    warn "Target google_accounts.json missing."
  fi

  if [ -f "$target_dir/mcp-oauth-tokens-v2.json" ]; then
    cp "$target_dir/mcp-oauth-tokens-v2.json" "$MCP_OAUTH_FILE"
  else
    rm -f "$MCP_OAUTH_FILE"
  fi

  info "Successfully switched to account: $target_email."
}

new_account() {
  save_current_account
  
  echo "Logging out of current account..."
  rm -f "$OAUTH_FILE"
  rm -f "$GOOGLE_ACCTS_FILE"
  rm -f "$MCP_OAUTH_FILE"
  
  info "Tokens cleared. Please run 'gemini' to authenticate with the new account."
  echo "After authentication, run 'gemini-switch save' to back it up."
}

show_history() {
  cd "$ACCOUNTS_DIR" || exit 1
  if ! git --no-pager log --oneline -n 15 2>/dev/null; then
    echo "No history available yet."
  fi
}

show_help() {
  cat << EOF
Gemini CLI Account Switcher (Git Versioned)

Usage:
  gemini-switch ls                - List available accounts saved
  gemini-switch switch <email>    - Switch to a specific account
  gemini-switch new               - Clear current auth to log in to a new account
  gemini-switch save              - Force save and version the current account
  gemini-switch status            - Show current active account
  gemini-switch history           - Show git version history of accounts
EOF
}

# Main execution
setup_environment

case "${1:-}" in
  ls|list)
    list_accounts
    ;;
  switch|use)
    switch_account "${2:-}"
    ;;
  new|add)
    new_account
    ;;
  save)
    save_current_account
    ;;
  status)
    email=$(get_current_email)
    if [ -n "$email" ]; then
      info "Current active account: $email"
    else
      echo "No active account found."
    fi
    ;;
  history)
    show_history
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    # Default to quick switch if no argument is provided
    if [ -z "${1:-}" ]; then
      switch_account
    else
      show_help
    fi
    ;;
esac
