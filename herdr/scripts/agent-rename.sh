#!/usr/bin/env bash
# Auto-rename Herdr tabs AND workspaces to mirror the live title Herdr
# already paints onto each agent pane (`terminal_title_stripped` in the
# socket API), the same way tmux/scripts/agent-rename.sh renames tmux
# windows. Herdr keeps pane titles fresh on its own; tab labels ("1", "2")
# and workspace labels (the static cwd-derived name, e.g. "amilabs") never
# got wired to them.
#
# Both levels pick one representative agent pane the same way: the focused
# one, else the one currently "working", else the most recently active by
# state_change_seq — computed independently per tab and per workspace (a
# workspace's pick can come from a different tab than that tab's own pick,
# by design: a tab shows what's relevant to IT, the workspace shows what's
# relevant across all of it, mirroring one further level of the same focus
# logic). Idle tabs/workspaces with no agent pane are left untouched —
# neither `tab rename` nor `workspace rename` has a --clear, so there's
# nothing sane to revert to (verified: `--clear` is taken as a literal
# label, not a flag) — a workspace's static project label is only replaced
# once an agent is actually running somewhere inside it.
#
# `herdr tab list`/`agent list`/`workspace list` with no --workspace filter
# cover every workspace, not just the focused one (verified against a
# throwaway second workspace).
#
# Usage:
#   agent-rename.sh            # scan all tabs/workspaces once
#   agent-rename.sh --watch [interval]   # poll forever (default 30s)

set -euo pipefail

CACHE_DIR="${HOME}/.cache/herdr-tab-rename"
mkdir -p "$CACHE_DIR"

# Never let this watcher be the thing that spawns Herdr's server — only act
# while `herdr status server` already reports one running.
herdr_server_up() {
  herdr status server --json 2>/dev/null | grep -q '"running":true'
}

rename_once() {
  herdr_server_up || return 0
  local agents tabs workspaces
  # `pane list` carries every pane (including plain shells) but has no
  # `state_change_seq`, which silently broke the recency tie-break below —
  # every pane defaulted to the same rank. `agent list` already excludes
  # non-agent panes and carries `state_change_seq`; use it instead.
  agents=$(herdr agent list 2>/dev/null) || return 0
  tabs=$(herdr tab list 2>/dev/null) || return 0
  workspaces=$(herdr workspace list 2>/dev/null) || return 0
  [[ -n "$agents" && -n "$tabs" && -n "$workspaces" ]] || return 0

  python3 - "$agents" "$tabs" "$workspaces" <<'PY'
import json, subprocess, sys

PREFIX = {"claude": "cc", "codex": "cdx", "omp": "omp"}

agent_panes = json.loads(sys.argv[1])["result"]["agents"]
tabs = json.loads(sys.argv[2])["result"]["tabs"]
workspaces = json.loads(sys.argv[3])["result"]["workspaces"]
current_tab_label = {t["tab_id"]: t["label"] for t in tabs}
current_ws_label = {w["workspace_id"]: w["label"] for w in workspaces}


def rank(p):
    return (
        not p.get("focused"),
        p.get("agent_status") != "working",
        -p.get("state_change_seq", 0),
    )


def group_by(key):
    out = {}
    for p in agent_panes:
        if not p.get("agent"):
            continue
        out.setdefault(p[key], []).append(p)
    return out


def display_name(p):
    title = (p.get("terminal_title_stripped") or "").strip()
    if not title:
        return None
    prefix = PREFIX.get(p["agent"], p["agent"])
    return f"{prefix}/{title}"


for tab_id, agents in group_by("tab_id").items():
    name = display_name(min(agents, key=rank))
    if name and current_tab_label.get(tab_id) != name:
        subprocess.run(["herdr", "tab", "rename", tab_id, name], capture_output=True)

for ws_id, agents in group_by("workspace_id").items():
    name = display_name(min(agents, key=rank))
    if name and current_ws_label.get(ws_id) != name:
        subprocess.run(["herdr", "workspace", "rename", ws_id, name], capture_output=True)
PY
}

if [[ "${1:-}" == "--watch" ]]; then
  interval="${2:-30}"
  [[ "$interval" =~ ^[0-9]+$ && "$interval" -gt 0 ]] || interval=30
  pidfile="${CACHE_DIR}/watch.pid"
  printf '%s\n' "$$" > "$pidfile"
  trap 'exit 0' TERM INT
  trap '[[ "$(cat "$pidfile" 2>/dev/null)" == "$$" ]] && rm -f "$pidfile"' EXIT
  while :; do
    [[ "$(cat "$pidfile" 2>/dev/null)" == "$$" ]] || exit 0
    rename_once || true
    sleep "$interval"
  done
fi

rename_once
