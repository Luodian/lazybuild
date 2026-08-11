#!/usr/bin/env bash
# alt+h / alt+l "Zellij-style" nav for Herdr, mirroring tmux's:
#   bind -n M-h if-shell -F '#{pane_at_left}'  'if-shell ... previous-window' 'select-pane -L'
#   bind -n M-l if-shell -F '#{pane_at_right}' 'if-shell ... next-window'     'select-pane -R'
#
# Move pane focus within a split; at the edge, fall through to the
# previous/next tab in the same workspace — stopping at the first/last tab
# instead of wrapping (mirrors tmux's window_index guard). Bound as a
# `type = "shell"` custom command per direction in config.toml, so it just
# needs to dispatch to the real action as a side effect; there's nothing to
# display.
#
# Usage: nav-or-switch-tab.sh left|right
#
# `type = "shell"` commands run detached with nowhere to surface a failure,
# so errors go to a log instead of vanishing silently.

set -euo pipefail
direction="$1"  # left|right

LOG="${HOME}/.cache/herdr-tab-rename/nav.log"
mkdir -p "$(dirname "$LOG")"
exec 2>> "$LOG"
trap 'echo "[$(date "+%F %T")] failed: direction=$direction line=$LINENO"' ERR

edges_json=$(herdr pane edges --current 2>/dev/null) || exit 0
info=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])['result']['edges']
direction = sys.argv[2]
print(d[direction], d['layout']['tab_id'], d['layout']['workspace_id'])
" "$edges_json" "$direction") || exit 0
read -r at_edge tab_id workspace_id <<< "$info"

if [[ "$at_edge" != "True" ]]; then
  exec herdr pane focus --direction "$direction" --current
fi

tabs_json=$(herdr tab list --workspace "$workspace_id" 2>/dev/null) || exit 0
target_tab=$(python3 -c "
import json, sys
tabs = sorted(json.loads(sys.argv[1])['result']['tabs'], key=lambda t: t['number'])
ids = [t['tab_id'] for t in tabs]
tab_id, direction = sys.argv[2], sys.argv[3]
if tab_id not in ids:
    sys.exit(0)
i = ids.index(tab_id)
j = i - 1 if direction == 'left' else i + 1
if 0 <= j < len(ids):
    print(ids[j])
" "$tabs_json" "$tab_id" "$direction") || true

[[ -n "$target_tab" ]] && exec herdr tab focus "$target_tab"
exit 0
