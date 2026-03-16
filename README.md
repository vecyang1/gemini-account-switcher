# Gemini CLI Multi-Account Switcher & proxy Wrapper

A robust, git-backed, zero-data-loss account switcher and smart proxy wrapper specifically designed for the **Google Gemini CLI**. 

Tired of `gemini` throwing `socket hang up` errors because your VPN isn't natively bound to Node.js? Sick of manually copying tokens to switch between different Google Workspace / Personal accounts in the terminal? This toolkit solves both problems seamlessly.

## Features

### 1. Smart Proxy Wrapper (Zero Config for VPNs)
If you run `gemini` on macOS while using VPNs (like Clash Verge, V2Ray, Shadowsocks), the underlying Node.js instance sometimes fails to respect the system proxy, resulting in a `socket hang up` error.

This toolkit includes a lightweight zsh wrapper that:
- **Auto-Detects Active Tunnels**: Loops through common VPN ports (`7897, 7890, 1080, 10809, 10808`) in milliseconds using `nc`.
- **Dynamic Injection**: If a proxy is found, it automatically sets `https_proxy`/`http_proxy`/`all_proxy` just for that standard `gemini` command execution.
- **Seamless Fallback**: If no proxy is running, it falls back to a direct connection gracefully. Zero perceived latency, zero config required.

### 2. Multi-Account Switcher (Git-Backed)
Switch between different Google accounts safely without ever losing your OAuth tokens.
- **Git Versioned**: Every time you save or switch accounts, it automatically commits your `oauth_creds.json` and `google_accounts.json` to a local, isolated git repository (`~/.gemini/accounts/.git`). 
- **Absolute Data Safety**: If a token gets corrupted, you can easily use standard `git log` and `git checkout` to recover your last working session.
- **Native Parsing**: Uses `jq` to reliably read your currently active email.
- **Visual Feedback**: The `ls` command shows all saved accounts and highlights the actively used one.

## Installation

### Step 1: Install the Account Switcher Script
1. Create a scripts directory if you don't have one:
```bash
mkdir -p ~/.gemini/scripts
```

2. Download the `gemini-switch.sh` script to that directory and make it executable:
```bash
curl -O https://raw.githubusercontent.com/vecyang1/gemini-account-switcher/main/gemini-switch.sh
mv gemini-switch.sh ~/.gemini/scripts/
chmod +x ~/.gemini/scripts/gemini-switch.sh
```

### Step 2: Configure your `~/.zshrc` (or `~/.bashrc`)
Add the following blocks to your shell configuration file to enable the intelligent Proxy Wrapper and the Account Switcher Aliases:

```bash
# ==========================================
# Gemini CLI Toolkit
# ==========================================

# 1. Account Switcher Aliases
alias gemini-switch="$HOME/.gemini/scripts/gemini-switch.sh"
alias gs="gemini-switch"

# 2. Smart Proxy Wrapper for Gemini CLI
# Auto-detects common VPN ports and injects proxy for Node.js
function gemini() {
  local proxy_ports=(7897 7890 1080 10809 10808)
  local active_port=""
  
  for port in "${proxy_ports[@]}"; do
    if nc -z 127.0.0.1 "$port" 2>/dev/null; then
      active_port="$port"
      break
    fi
  done

  if [ -n "$active_port" ]; then
    https_proxy="http://127.0.0.1:$active_port" http_proxy="http://127.0.0.1:$active_port" all_proxy="socks5://127.0.0.1:$active_port" command gemini "$@"
  else
    command gemini "$@"
  fi
}
# ==========================================
```

Restart your terminal or run `source ~/.zshrc`.

## Usage Instructions

### Account Switcher Commands
You can use `gs` instead of `gemini-switch` for all commands to type faster!

```bash
# Interactive Quick Switch (Shows a numbered list of accounts to pick from)
gs

# List all saved accounts (highlights the active one)
gs ls                

# Clear current authentication to log into a new account
# (Automatically saves and backs up your current session first)
gs new               

# Once you've logged in, force-save your current active session
gs save              

# Switch to a previously saved account instantly by email
gs switch name@example.com    

# Quick check on which account you are currently using
gs status            

# See the chronological backup history of your account states
gs history           
```

## How It Works
The switcher script maps the global `~/.gemini/oauth_creds.json` and `google_accounts.json` target files into isolated folders under `~/.gemini/accounts/<email>/`. Whenever you switch, it synchronizes these files and performs a `git add . && git commit` to construct an immutable backup history of your credentials. 

## License
MIT License
