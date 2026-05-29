#!/usr/bin/env bash
# Animate a braille spinner on tabs whose @cc_working == 1 (set by the Claude
# Code UserPromptSubmit/Stop hooks via cc-working.sh).
#
# Advances a single global @cc_spin frame and repaints the status line only
# while at least one window is working — idle ticks just poll list-windows and
# never refresh, so the cost when nothing is running is negligible. tmux caches
# #() output (cpu/battery in tmux-power), so the forced redraw doesn't re-run
# those either.
#
# Cooperative single-instance (last writer wins; superseded instances exit
# cleanly), and self-terminates when the tmux server goes away. See the watcher
# in tmux-autoname-agent-sessions for the same pattern and rationale.
set -euo pipefail

pidfile="${HOME}/.cache/tmux-ai-rename/spin.pid"
mkdir -p "$(dirname "$pidfile")"

frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
n=${#frames[@]}

printf '%s\n' "$$" > "$pidfile"
trap 'exit 0' TERM INT
trap '[[ "$(cat "$pidfile" 2>/dev/null)" == "$$" ]] && rm -f "$pidfile"' EXIT

i=0
while tmux has-session 2>/dev/null; do
  [[ "$(cat "$pidfile" 2>/dev/null)" == "$$" ]] || exit 0   # superseded
  if tmux list-windows -a -F '#{@cc_working}' 2>/dev/null | grep -q '^1$'; then
    tmux set-option -g @cc_spin "${frames[i]}" 2>/dev/null || true
    tmux refresh-client -S 2>/dev/null || true
    i=$(( (i + 1) % n ))
    sleep 0.5
  else
    sleep 1.5
  fi
done
exit 0
