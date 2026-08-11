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
# Two stability rules keep a refresh from visibly scrambling the sidebar:
#   1. Workspace labels are only rewritten while the workspace holds a
#      SINGLE tab. Herdr's sidebar paints the workspace label on every
#      agent row, so with several tabs one focused pane (typically omp,
#      since it is the one being looked at) would repaint every row as
#      that pane — the "everything became OMP" failure. With one tab the
#      workspace IS that session, so tracking it is correct.
#   2. Hysteresis: a label that still matches one of its group's panes is
#      kept as-is. Without this, focus moves between two panes of one tab
#      flip the tab's label back and forth on every tick.
#
# `herdr tab list`/`agent list`/`workspace list` with no --workspace filter
# cover every workspace, not just the focused one (verified against a
# throwaway second workspace). Herdr exposes no event stream (`herdr api`
# has only snapshot/schema), so freshness comes from polling; a tick is
# four cheap local socket calls with no LLM in the loop, so 5s is fine.
#
# Usage:
#   agent-rename.sh            # scan all tabs/workspaces once
#   agent-rename.sh --watch [interval]   # poll forever (default 5s)

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
import json, re, subprocess, sys

PREFIX = {"claude": "cc", "codex": "cdx", "omp": "omp"}

agent_panes = json.loads(sys.argv[1])["result"]["agents"]
tabs = json.loads(sys.argv[2])["result"]["tabs"]
workspaces = json.loads(sys.argv[3])["result"]["workspaces"]
current_tab_label = {t["tab_id"]: t["label"] for t in tabs}
current_ws_label = {w["workspace_id"]: w["label"] for w in workspaces}
tab_count = {w["workspace_id"]: w.get("tab_count", 0) for w in workspaces}


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
    # Drop OMP's brand + state separator ("π ⠦ label", "π > label", "π: label"
    # → "label") — the spinner animates while the agent works, so keeping it
    # would rename the tab every tick and defeat the hysteresis above. Same
    # treatment as tmux/scripts/agent-rename.sh's omp_title.
    if title.startswith("π"):
        title = re.sub(r"^π(?:\s+\S+)?\s*", "", title)
        title = re.sub(r"^\W+\s*", "", title)
        if not title:
            return None
    prefix = PREFIX.get(p["agent"], p["agent"])
    return f"{prefix}/{title}"


def maybe_rename(kind, oid, agents, current):
    names = [n for n in (display_name(p) for p in agents) if n]
    if not names:
        return
    # Hysteresis: while any pane in the group still backs the current label,
    # keep it — focus moves between panes of one tab must not flap the label.
    if current in names:
        return
    name = display_name(min(agents, key=rank))
    if name and current != name:
        subprocess.run(["herdr", kind, "rename", oid, name], capture_output=True)


for tab_id, agents in group_by("tab_id").items():
    maybe_rename("tab", tab_id, agents, current_tab_label.get(tab_id))

# Workspace labels only track an agent while the workspace holds a single
# tab. With several tabs no one pane's title represents the workspace, and
# the sidebar paints the workspace label on every agent row — one focused
# pane would repaint the whole sidebar as itself.
for ws_id, agents in group_by("workspace_id").items():
    if tab_count.get(ws_id, 0) != 1:
        continue
    maybe_rename("workspace", ws_id, agents, current_ws_label.get(ws_id))
PY
}

if [[ "${1:-}" == "--watch" ]]; then
  interval="${2:-5}"
  [[ "$interval" =~ ^[0-9]+$ && "$interval" -gt 0 ]] || interval=5
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
