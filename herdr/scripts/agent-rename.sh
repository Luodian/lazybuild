#!/usr/bin/env bash
# Auto-rename Herdr tabs AND workspaces to mirror the live title Herdr
# already paints onto each agent pane (`terminal_title_stripped` in the
# socket API), the same way tmux/scripts/agent-rename.sh renames tmux
# windows. Herdr keeps pane titles fresh on its own; tab labels ("1", "2")
# and workspace labels (the static cwd-derived name, e.g. "amilabs") never
# got wired to them.
#
# Renames are tick-based and activity-gated. Each tick takes a fresh
# snapshot and reconsiders ONLY tabs/workspaces holding at least one
# "working" pane — plus, one tick late, groups whose state_change_seq
# advanced since the previous tick: a session that started AND finished
# between two ticks still bumps its seq, so the tick after it goes idle
# lands the final title once and the group then freezes again. Without
# that edge pass, a mostly-idle session with short working bursts (watch
# loops, quick turns) can miss every working-phase tick and leave the tab
# wearing the PREVIOUS session's name forever. A group whose sessions are
# idle with a static seq keeps its last label — a finished session's final
# title is its latest result, and there is no --clear to revert to anyway
# (verified: `--clear` is taken as a literal label, not a flag). A
# workspace's static project label is only replaced once an agent is
# actually running somewhere inside it. The seq watermark lives in
# CACHE_DIR/last-seq.json; a missing file (first run / restart) starts
# frozen and never triggers the edge pass.
#
# Within a live group, both levels pick one representative pane the same
# way: the active ("working") one first — the tick fires because something
# is active, so the label reflects that pane's latest title — then the
# focused one, then the most recently active by state_change_seq. Computed
# independently per tab and per workspace (a workspace's pick can come from
# a different tab than that tab's own pick, by design: a tab shows what's
# relevant to IT, the workspace shows what's relevant across all of it).
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
# has only snapshot/schema), so polling is the only freshness lever; a tick
# is four cheap local socket calls with no LLM in the loop (~0.1s per
# tick). The activity gate plus the seq edge, not the interval, is what
# suppresses churn, so the interval is pure freshness (Brian runs 30s;
# whatever a burst did between ticks is still caught one tick later).
#
# Usage:
#   agent-rename.sh            # scan all tabs/workspaces once
#   agent-rename.sh --watch [interval]   # poll forever; interval in
#                                        # seconds, or Nm/Nh (default 5s)

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

  python3 - "$agents" "$tabs" "$workspaces" "$CACHE_DIR" <<'PY'
import json, os, re, subprocess, sys

agent_panes = json.loads(sys.argv[1])["result"]["agents"]
tabs = json.loads(sys.argv[2])["result"]["tabs"]
workspaces = json.loads(sys.argv[3])["result"]["workspaces"]
current_tab_label = {t["tab_id"]: t["label"] for t in tabs}
current_ws_label = {w["workspace_id"]: w["label"] for w in workspaces}
tab_count = {w["workspace_id"]: w.get("tab_count", 0) for w in workspaces}

# Tabs/workspaces explicitly renamed by the tab-smart-rename plugin stay owned
# by it while its label is intact (state.json expectedLabel/autoLabel ==
# current label). Once the label diverges the plugin itself marks the entry
# manual and this watcher resumes ownership, so the skip needs no lock
# handling and never freezes a label the plugin no longer backs.
plugin_state_path = os.path.expanduser(
    "~/.local/state/herdr/plugins/tab-smart-rename/state.json"
)
try:
    with open(plugin_state_path) as fh:
        plugin_state = json.load(fh)
except (OSError, json.JSONDecodeError):
    plugin_state = {}

# Seq watermark for the activity edge: max state_change_seq seen per group
# on the previous tick. An all-idle group whose seq still advanced gets ONE
# reconciliation pass (its session worked and finished between ticks); a
# missing watermark (first run / restart) means frozen, no edge pass.
seq_state_path = os.path.join(sys.argv[4], "last-seq.json")
try:
    with open(seq_state_path) as fh:
        last_seq = json.load(fh)
except (OSError, json.JSONDecodeError):
    last_seq = {}
last_seq.setdefault("tabs", {})
last_seq.setdefault("workspaces", {})


def plugin_owns(kind, oid, current):
    if current is None:
        return False
    rec = plugin_state.get(f"{kind}s", {}).get(oid) or {}
    return current in {rec.get("expectedLabel"), rec.get("autoLabel")} - {None}
def rank(p):
    # Active first: a tick only renames a group because one of its sessions
    # is working, so the label must come from that session's latest title.
    # Focus breaks ties between active panes, then recency.
    return (
        p.get("agent_status") != "working",
        not p.get("focused"),
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
    # Claude paints the same kind of animated status glyph into its own title
    # ("✳ X", "◑ X", "◐ X", …) which terminal_title_stripped does not always
    # remove — strip a leading run of non-word chars for every agent so no
    # spinner leaks into a label (CJK/Latin titles start with \w and pass
    # through untouched). Without this, claude tabs would carry a stale glyph
    # and rename on every tick while the glyph rotates.
    title = re.sub(r"^\W+\s*", "", title)
    # Labels are the bare title — no cc//cdx//omp/ agent prefix. The tab shows
    # one session's title; the agent kind added noise without disambiguating
    # anything.
    return title or None


def maybe_rename(kind, oid, agents, current, force=False):
    # Plugin-owned labels win: an explicit tab-smart-rename rename (prefix+t)
    # is never clobbered by the mirror.
    if plugin_owns(kind, oid, current):
        return
    # Tick gate: a group is only reconsidered while one of its sessions is
    # active, or — via force — once when its seq advanced since the last
    # tick even though it is idle now (a burst that started and finished
    # between ticks; this tick lands its final title, then it freezes).
    # Otherwise idle/done groups keep their last label: no renames fire
    # between bursts of activity, and a finished session keeps its result.
    if not force and not any(p.get("agent_status") == "working" for p in agents):
        return
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


def max_seq(agents):
    return max((p.get("state_change_seq", 0) for p in agents), default=0)


def seq_edge(kind, oid, seq):
    prev = last_seq[kind].get(oid)
    return prev is not None and seq > prev


tab_seq = {}
for tab_id, agents in group_by("tab_id").items():
    tab_seq[tab_id] = max_seq(agents)
    maybe_rename(
        "tab", tab_id, agents, current_tab_label.get(tab_id),
        force=seq_edge("tabs", tab_id, tab_seq[tab_id]),
    )

# Workspace labels only track an agent while the workspace holds a single
# tab. With several tabs no one pane's title represents the workspace, and
# the sidebar paints the workspace label on every agent row — one focused
# pane would repaint the whole sidebar as itself.
ws_seq = {}
for ws_id, agents in group_by("workspace_id").items():
    ws_seq[ws_id] = max_seq(agents)
    if tab_count.get(ws_id, 0) != 1:
        continue
    maybe_rename(
        "workspace", ws_id, agents, current_ws_label.get(ws_id),
        force=seq_edge("workspaces", ws_id, ws_seq[ws_id]),
    )

# Persist the watermark only after the pass, atomically: a tick that dies
# mid-pass leaves the old watermark behind, so the next tick retries the
# edge instead of silently dropping it.
_tmp = seq_state_path + ".tmp"
with open(_tmp, "w") as fh:
    json.dump({"tabs": tab_seq, "workspaces": ws_seq}, fh)
os.replace(_tmp, seq_state_path)
PY
}

if [[ "${1:-}" == "--watch" ]]; then
  interval="${2:-5}"
  case "$interval" in
    *s) interval="${interval%s}" ;;
    *m) interval=$(( ${interval%m} * 60 )) ;;
    *h) interval=$(( ${interval%h} * 3600 )) ;;
  esac
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
