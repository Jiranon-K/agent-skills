#!/bin/sh
# Bound to a herdr key (see config.toml): opens a pane to the right of the
# focused one that keeps listing that repo's changed files.
# With --watch it is the loop that runs inside that pane.
set -eu

if [ "${1:-}" = "--watch" ]; then
  while :; do
    out=$(git -c color.status=always status --short --branch 2>&1; echo; git diff --stat --color=always HEAD 2>/dev/null | tail -n 30)
    printf '\033[H\033[2J%s\n' "$out"
    sleep 2
  done
fi

pane=$(herdr pane split --pane "$HERDR_ACTIVE_PANE_ID" --direction right --ratio 0.7 \
  --cwd "$HERDR_ACTIVE_PANE_CWD" | jq -r '.result.pane.pane_id')
herdr pane rename "$pane" changes >/dev/null 2>&1 || true
herdr pane run "$pane" "sh $HOME/.config/herdr/changes-panel.sh --watch"
