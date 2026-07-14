#!/usr/bin/env bash
# Wires up AI window auto-rename (hooks, keybinding, background watcher).
# Vendored from Luodian/tmux-autoname-agent-sessions — invoked directly via
# run-shell from tmux.conf, no longer a TPM-managed plugin. agent-rename.sh
# lives alongside this script (sibling, not a scripts/ subdirectory).

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tmux_opt() {
  local value
  value="$(tmux show-option -gqv "$1" 2>/dev/null)"
  printf '%s\n' "${value:-$2}"
}

normalize_key() {
  case "$1" in
    ''|off|none|disabled|disable) printf '\n' ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# ── Window auto-rename (AI session → short title) ──────────

printf -v rename_cmd "bash %q" "$CURRENT_DIR/agent-rename.sh"
printf -v rename_current_cmd "bash %q --current" "$CURRENT_DIR/agent-rename.sh"

rename_enable="$(tmux_opt '@autoname_enable' 'on')"

if [[ "$rename_enable" == "on" ]]; then
  # Full scan on session switch AND on window switch (keeps every tab current
  # whenever you navigate); fast --current scan on new-window / pane switch.
  # Explicit [9] indices keep reloads idempotent (won't duplicate).
  tmux set-hook -g 'client-session-changed[9]' "run-shell -b \"$rename_cmd\""
  tmux set-hook -g 'after-new-window[9]'       "run-shell -b \"$rename_current_cmd\""
  tmux set-hook -g 'after-select-window[9]'    "run-shell -b \"$rename_cmd\""
  tmux set-hook -g 'after-select-pane[9]'      "run-shell -b \"$rename_current_cmd\""

  # Manual refresh: prefix + R
  rename_key="$(normalize_key "$(tmux_opt '@autoname_bind_rename' 'R')")"
  if [[ -n "$rename_key" ]]; then
    tmux bind-key "$rename_key" run-shell "$rename_cmd" \; display "AI window names refreshed"
  fi

  # Periodic background refresh (tmux has no timer hook). Set to 0/off to disable.
  refresh_interval="$(tmux_opt '@autoname_refresh_interval' '30')"
  case "$refresh_interval" in
    ''|off|none|0|disabled|disable) : ;;
    *)
      printf -v watch_cmd "bash %q --watch %q" "$CURRENT_DIR/agent-rename.sh" "$refresh_interval"
      tmux run-shell -b "$watch_cmd"
      ;;
  esac
else
  tmux set-hook -gu 'client-session-changed[9]' 2>/dev/null || true
  tmux set-hook -gu 'after-new-window[9]' 2>/dev/null || true
  tmux set-hook -gu 'after-select-window[9]' 2>/dev/null || true
  tmux set-hook -gu 'after-select-pane[9]' 2>/dev/null || true

  # Stop the periodic refresh watcher if one is running.
  watch_pidfile="${HOME}/.cache/tmux-ai-rename/watch.pid"
  if [[ -f "$watch_pidfile" ]]; then
    kill "$(cat "$watch_pidfile" 2>/dev/null)" 2>/dev/null || true
  fi
fi
