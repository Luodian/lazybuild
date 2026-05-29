#!/usr/bin/env bash
# Mark the current tmux window's agent as working (1) or idle (0).
#
# Driven by Claude Code hooks: UserPromptSubmit -> `cc-working.sh 1` (turn
# started), Stop -> `cc-working.sh 0` (turn finished). The hook runs inside the
# agent's pane, so $TMUX_PANE identifies the window without any process-tree
# walking. tab-spinner.sh animates a spinner on windows where @cc_working == 1.
#
# MUST stay silent on stdout — a UserPromptSubmit hook's stdout is injected into
# the prompt context, so anything printed here would pollute every turn.
[ -n "${TMUX_PANE:-}" ] || exit 0
tmux set-option -t "$TMUX_PANE" -w @cc_working "${1:-0}" >/dev/null 2>&1 || true
tmux refresh-client -S >/dev/null 2>&1 || true
exit 0
