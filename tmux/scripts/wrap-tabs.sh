#!/usr/bin/env bash
# Wrap the tmux window-tab list across multiple status rows by *measured* width.
#
# Layout produced (per session):
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
# reusing the global `window-status-format` / `-current-format` via `#{T:...}`.
# Only the row boundaries are precomputed — current-window highlight, activity
# flags, and `range=window` mouse zones stay live and are redrawn by tmux
# itself, not baked into a literal.
#
# Enforcement model: `status` and `status-format[*]` are SESSION options, so
# every session gets its own boundaries computed from its own windows at the
# width of its own widest attached client. Hook-trigger context is irrelevant —
# a rename in a 1-window session can no longer collapse a 12-window session
# (the old global-only version packed for whichever client happened to be
# active and applied it to everyone). A global single-row fallback is kept so
# a brand-new session renders sanely until its first hook lands (its creation
# fires window-linked, so that is immediate in practice).
set -euo pipefail

# Printable sentinels — tmux's format parser strips raw control bytes, so we
# use tokens that won't occur in a window name.
SENT_ROW='@@WT_ROW@@'   # separates window entries in the measurement blob
SENT_FLD='@@WT_FLD@@'   # separates fields (also index/tab within an entry)
SENT_SES='@@WT_SES@@'   # separates per-session records
MAX_STATUS=5
MAX_TAB_ROWS=3
FALLBACK_WIDTH=200

PANE_FMT_DEFAULT='#[align=left] #{P: #{pane_index}:#{?#{==:#{pane_title},#{host}},#{pane_current_command},#{pane_title}} ,#[reverse] #{pane_index}:#{?#{==:#{pane_title},#{host}},#{pane_current_command},#{pane_title}} #[noreverse] }'

# Row 0 — session (left) + clock/host (right), no tabs. Reuses tmux's default
# left/right segments verbatim (range + push/pop-default + norange) so the
# session chip's background does not bleed across the empty middle of the row.
ROW0_FMT='#[align=left range=left #{E:status-left-style}]#[push-default]#{T;=/#{status-left-length}:status-left}#[pop-default]#[norange default]#[nolist align=right range=right #{E:status-right-style}]#[push-default]#{T;=/#{status-right-length}:status-right}#[pop-default]#[norange default]'

# Thin divider between tabs. NB: no comma in this style — a literal comma
# would be parsed as the #{?...} branch separator and break the conditional.
DIV=' #[fg=#56697e]│#[default] '

opt() { tmux show-option -gqv "$1" 2>/dev/null || true; }

pane_fmt=$(opt '@wrap_tabs_pane_format'); [[ -n "$pane_fmt" ]] || pane_fmt="$PANE_FMT_DEFAULT"

# Widest client anywhere — fallback width for sessions with no client of
# their own (detached regen: continuum restore, scripted session creation).
global_width=$(tmux list-clients -F '#{client_width}' 2>/dev/null | sort -rn | head -1 || true)
[[ "$global_width" =~ ^[0-9]+$ && "$global_width" -gt 0 ]] || global_width=$FALLBACK_WIDTH

sessions=$(tmux list-sessions -F '#{session_id}' 2>/dev/null || true)
[[ -n "$sessions" ]] || exit 0

# One record per session: "<sid> FLD <width> FLD <blob>". The blob renders
# every window's tab (correct current styling via the 2-arg W form) prefixed
# with its index — width measurement is a single pass per session.
records=''
for sid in $sessions; do
  w=$(tmux list-clients -t "$sid" -F '#{client_width}' 2>/dev/null | sort -rn | head -1 || true)
  [[ "$w" =~ ^[0-9]+$ && "$w" -gt 0 ]] || w=$global_width
  blob=$(tmux display-message -p -t "$sid" \
    "#{W:#{window_index}${SENT_FLD}#{T:window-status-format}${SENT_ROW},#{window_index}${SENT_FLD}#{T:window-status-current-format}${SENT_ROW}}" \
    2>/dev/null || true)
  records+="${sid}${SENT_FLD}${w}${SENT_FLD}${blob}${SENT_SES}"
done

# Emit the ranged tab-row format for windows lo..hi. Each in-range window is
# wrapped in #[range=window|N] ... #[norange default] so clicking a tab still
# selects the window; a divider follows every tab except the row's last.
tab_row_fmt() {
  local lo="$1" hi="$2"
  local cond="#{&&:#{>=:#{window_index},${lo}},#{<=:#{window_index},${hi}}}"
  local sep="#{?#{<:#{window_index},${hi}},${DIV},}"
  local a="#{?${cond},#[range=window|#{window_index}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]${sep},}"
  local b="#{?${cond},#[range=window|#{window_index} list=focus]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange default]${sep},}"
  printf '%s' "#[align=left] #[list=on]#{W:${a},${b}}"
}

# Apply one session's layout: status height, row 0, tab rows, pane row, and
# clear session-local rows left over from a higher previous row count. The
# whole layout is a pure function of the row list, so a matching signature
# (stored in @wrap_tabs_sig) means nothing to do — keeps hook churn cheap and
# flicker-free (autoname renames fire this constantly).
apply_session() {
  local sid="$1"; shift
  local n=$#
  local status_n=$(( 1 + n + 1 ))
  (( status_n <= MAX_STATUS )) || status_n=$MAX_STATUS
  local sig="v2:${status_n}:$*"
  local prev; prev=$(tmux show-options -t "$sid" -qv '@wrap_tabs_sig' 2>/dev/null || true)
  [[ "$sig" == "$prev" ]] && return 0
  tmux set-option -t "$sid" status "$status_n"
  tmux set-option -t "$sid" 'status-format[0]' "$ROW0_FMT"
  local r=1 spec lo hi
  for spec in "$@"; do
    lo=${spec% *}; hi=${spec#* }
    tmux set-option -t "$sid" "status-format[${r}]" "$(tab_row_fmt "$lo" "$hi")"
    r=$(( r + 1 ))
  done
  tmux set-option -t "$sid" "status-format[$(( status_n - 1 ))]" "$pane_fmt"
  local i=$status_n
  while (( i < MAX_STATUS )); do
    tmux set-option -t "$sid" -u "status-format[$i]" 2>/dev/null || true
    i=$(( i + 1 ))
  done
  tmux set-option -t "$sid" '@wrap_tabs_sig' "$sig"
}

# Greedy width-pack per session → "sid lo hi" per row. Python handles CJK
# (count as 2 cells) and strips #[...] style directives.
cur_sid=''
cur_rows=()
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  sid=${line%% *}; spec=${line#* }
  if [[ "$sid" != "$cur_sid" ]]; then
    if [[ -n "$cur_sid" ]]; then apply_session "$cur_sid" "${cur_rows[@]}" || true; fi
    cur_sid="$sid"; cur_rows=()
  fi
  cur_rows+=("$spec")
done < <(printf '%s' "$records" | MAXROWS="$MAX_TAB_ROWS" \
  SENT_ROW="$SENT_ROW" SENT_FLD="$SENT_FLD" SENT_SES="$SENT_SES" python3 -c '
import os, re, sys, unicodedata
maxrows = int(os.environ["MAXROWS"])
srow = os.environ["SENT_ROW"]; sfld = os.environ["SENT_FLD"]; sses = os.environ["SENT_SES"]
data = sys.stdin.buffer.read().decode("utf-8", "replace")
def vis(s):
    s = re.sub(r"#\[[^]]*\]", "", s)
    w = 0
    for ch in s:
        if ch == "\x00": continue
        w += 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
    return w
for rec in (r for r in data.split(sses) if r):
    try:
        sid, width, blob = rec.split(sfld, 2)
        width = int(width)
    except ValueError:
        continue
    items = []
    for e in (x for x in blob.split(srow) if x):
        idx, _, tab = e.partition(sfld)
        try: idx = int(idx)
        except ValueError: continue
        items.append((idx, vis(tab) + 3))   # +3 for the divider between tabs
    if not items: continue                  # no windows resolved — leave as-is
    rows, cur_w = [], 0
    for idx, w in items:
        if not rows:
            rows.append([idx, idx]); cur_w = w
        elif cur_w + w > width and len(rows) < maxrows:
            rows.append([idx, idx]); cur_w = w
        else:
            rows[-1][1] = idx; cur_w += w
    for lo, hi in rows: print(sid, lo, hi)
')
if [[ -n "$cur_sid" ]]; then apply_session "$cur_sid" "${cur_rows[@]}" || true; fi

# Global fallback — what a session shows between its creation and its first
# hook-driven pack: our row 0, ONE unranged native tab row, the pane row.
# Guarded by the same signature trick on the global scope.
gsig="v2:global"
gprev=$(opt '@wrap_tabs_sig')
if [[ "$gsig" != "$gprev" ]]; then
  glast="#{?#{==:#{window_index},#{session_windows}},,${DIV}}"
  ga="#[range=window|#{window_index}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]${glast}"
  gb="#[range=window|#{window_index} list=focus]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange default]${glast}"
  tmux set-option -g status 3
  tmux set-option -g 'status-format[0]' "$ROW0_FMT"
  tmux set-option -g 'status-format[1]' "#[align=left] #[list=on]#{W:${ga},${gb}}"
  tmux set-option -g 'status-format[2]' "$pane_fmt"
  tmux set-option -gu 'status-format[3]' 2>/dev/null || true   # rows the pre-
  tmux set-option -gu 'status-format[4]' 2>/dev/null || true   # v2 global-only script may have left
  tmux set-option -g '@wrap_tabs_sig' "$gsig"
fi
exit 0
