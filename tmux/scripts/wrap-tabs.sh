#!/usr/bin/env bash
# Wrap the tmux window-tab list across multiple status rows by *measured* width.
#
# Layout produced:
#   row 0          session name (left) + clock / host (right)
#   rows 1..K      window tabs, packed left-to-right; overflow flows to the
#                  next row (true width-based wrap, not fixed buckets)
#   last row       pane list of the current window
#
# tmux caps `status` at 5 lines. With the session row and the pane row that
# leaves at most 3 tab rows (K <= 3); windows past that pack into the 3rd row
# and tmux truncates it as before.
#
# Each tab row is a *native* `#{W:...}` expression filtered to an index range,
# reusing tmux-power's own `window-status-format` / `-current-format` via
# `#{T:...}`. Only the row boundaries are precomputed — current-window
# highlight, activity flags, and `range=window` mouse zones stay live and are
# redrawn by tmux itself, not baked into a literal.
#
# Boundaries are computed for the client that triggered the regen (its width
# and current session). With a single attached client that is exact; if a
# second client attaches on another session the tab *content* stays correct
# per-client, only the row balance follows the triggering client.
set -euo pipefail

# Printable sentinels — tmux's format parser strips raw control bytes, so we
# use tokens that won't occur in a window name.
SENT_ROW='@@WT_ROW@@'   # separates window entries in the measurement blob
SENT_FLD='@@WT_FLD@@'   # separates index from rendered tab within an entry
MAX_STATUS=5
MAX_TAB_ROWS=3

PANE_FMT_DEFAULT='#[align=left] #{P: #{pane_index}:#{?#{==:#{pane_title},#{host}},#{pane_current_command},#{pane_title}} ,#[reverse] #{pane_index}:#{?#{==:#{pane_title},#{host}},#{pane_current_command},#{pane_title}} #[noreverse] }'

opt() { tmux show-option -gqv "$1" 2>/dev/null || true; }

width=$(tmux display-message -p '#{client_width}' 2>/dev/null || echo 0)
[[ "$width" =~ ^[0-9]+$ && "$width" -gt 0 ]] || width=200

pane_fmt=$(opt '@wrap_tabs_pane_format'); [[ -n "$pane_fmt" ]] || pane_fmt="$PANE_FMT_DEFAULT"

# Render every window's tab (correct current styling via the 2-arg W form)
# prefixed with its index, in ONE call — width measurement is a single pass.
blob=$(tmux display-message -p \
  "#{W:#{window_index}${SENT_FLD}#{T:window-status-format}${SENT_ROW},#{window_index}${SENT_FLD}#{T:window-status-current-format}${SENT_ROW}}" \
  2>/dev/null || true)

# Greedy width-pack → "LO HI" per row. Python handles CJK (count as 2 cells)
# and strips #[...] style directives; the nerd-font arrows are width-1.
rows=()                       # bash 3.2 (macOS default) has no mapfile
while IFS= read -r _line; do
  [[ -n "$_line" ]] && rows+=("$_line")
done < <(printf '%s' "$blob" | WIDTH="$width" MAXROWS="$MAX_TAB_ROWS" \
  SENT_ROW="$SENT_ROW" SENT_FLD="$SENT_FLD" python3 -c '
import os, re, sys, unicodedata
width = int(os.environ["WIDTH"]); maxrows = int(os.environ["MAXROWS"])
srow = os.environ["SENT_ROW"]; sfld = os.environ["SENT_FLD"]
blob = sys.stdin.buffer.read().decode("utf-8", "replace")
def vis(s):
    s = re.sub(r"#\[[^]]*\]", "", s)
    w = 0
    for ch in s:
        if ch == "\x00": continue
        w += 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
    return w
items = []
for e in (x for x in blob.split(srow) if x):
    idx, _, tab = e.partition(sfld)
    try: idx = int(idx)
    except ValueError: continue
    items.append((idx, vis(tab) + 3))   # +3 for the " | " divider between tabs
if not items: sys.exit(0)
rows, cur_w = [], 0
for idx, w in items:
    if not rows:
        rows.append([idx, idx]); cur_w = w
    elif cur_w + w > width and len(rows) < maxrows:
        rows.append([idx, idx]); cur_w = w
    else:
        rows[-1][1] = idx; cur_w += w
for lo, hi in rows: print(lo, hi)
')

n_tab_rows=${#rows[@]}
[[ "$n_tab_rows" -ge 1 ]] || exit 0   # no windows resolved — leave layout as-is

status_n=$(( 1 + n_tab_rows + 1 ))
(( status_n <= MAX_STATUS )) || status_n=$MAX_STATUS
tmux set-option -g status "$status_n"

# Row 0 — session (left) + clock/host (right), no tabs. Reuses tmux's default
# left/right segments verbatim (range + push/pop-default + norange) so the
# session chip's background does not bleed across the empty middle of the row.
tmux set-option -g 'status-format[0]' \
  '#[align=left range=left #{E:status-left-style}]#[push-default]#{T;=/#{status-left-length}:status-left}#[pop-default]#[norange default]#[nolist align=right range=right #{E:status-right-style}]#[push-default]#{T;=/#{status-right-length}:status-right}#[pop-default]#[norange default]'

# Tab rows — one ranged native #{W:...} per row. Each in-range window is wrapped
# in #[range=window|N] ... #[norange default] so clicking a tab still selects the
# window (the default status-format provides these zones; reusing only
# #{T:window-status-format} would drop them and break mouse selection). A thin
# " │ " divider follows every tab except the last one in its row.
# NB: no comma in this style — a literal comma here would be parsed as the
# #{?...} branch separator and break the conditional.
div=' #[fg=#56697e]│#[default] '
r=1
for spec in "${rows[@]}"; do
  lo=${spec% *}; hi=${spec#* }
  cond="#{&&:#{>=:#{window_index},${lo}},#{<=:#{window_index},${hi}}}"
  sep="#{?#{<:#{window_index},${hi}},${div},}"   # divider unless this is the row's last tab
  a="#{?${cond},#[range=window|#{window_index}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]${sep},}"
  b="#{?${cond},#[range=window|#{window_index} list=focus]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange default]${sep},}"
  tmux set-option -g "status-format[${r}]" "#[align=left] #[list=on]#{W:${a},${b}}"
  r=$(( r + 1 ))
done

# Pane row — last visible line.
tmux set-option -g "status-format[$(( status_n - 1 ))]" "$pane_fmt"

# Drop any rows left over from a higher previous window count.
i=$status_n
while [[ $i -lt $MAX_STATUS ]]; do
  tmux set-option -gu "status-format[$i]" 2>/dev/null || true
  i=$(( i + 1 ))
done
