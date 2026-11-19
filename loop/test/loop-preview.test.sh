#!/bin/bash
set -u
cd "$(dirname "$0")/../.."
REPO="$(pwd)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
eq()   { [ "$2" = "$3" ] && ok || fail "$1: expected '$3', got '$2'"; }

FAKE_HOME="$TMP/home"
BIN="$FAKE_HOME/.local/bin"
LOOP="$FAKE_HOME/loop"
MAIN="$TMP/web-app"
WT="$MAIN/.claude/worktrees/EX-1"
mkdir -p "$BIN" "$LOOP/bin" "$FAKE_HOME/.claude/hooks"
for script in loop-state loop-preview; do ln -s "$REPO/loop/bin/$script" "$LOOP/bin/$script"; done

git init -q "$MAIN"
git -C "$MAIN" commit -q --allow-empty -m init
git -C "$MAIN" branch -M staging
git -C "$MAIN" branch fix/EX-1-thing
echo "web-app $MAIN staging repo:web-app" > "$LOOP/repos"
echo 'LOOP_DEV_web_app="yarn start"' > "$LOOP/config.sh"

fake() { printf '#!/bin/bash\n%s\n' "$2" > "$1"; chmod +x "$1"; }
fake "$BIN/hc" 'exit 1'
fake "$BIN/memory_pressure" 'echo "System-wide memory free percentage: ${FREE:-80}%"'
fake "$BIN/herdr-core" 'cat "$HOME/spaces.json" 2>/dev/null'
fake "$BIN/herdr-app" 'case "$1:${2:-}" in
  status:*) exit 0 ;;
  ls:*) [ -f "$HOME/spaces.json" ] && echo "{\"spaces\":[{\"id\":\"sp1\",\"name\":\"preview EX-1\"}]}" ;;
  do:space.new) printf "%s\n" "$3" >> "$HOME/spaces.json" ;;
  do:space.close) printf "%s\n" "$3" >> "$HOME/closed.json"; rm -f "$HOME/spaces.json" ;;
esac'
fake "$FAKE_HOME/.claude/hooks/wt-setup" 'printf "%s\n" "$1" >> "$HOME/wt-setup-calls"'

state() { LOOP_DIR="$LOOP" "$LOOP/bin/loop-state" "$@"; }
preview() { HOME="$FAKE_HOME" LOOP_DIR="$LOOP" "$LOOP/bin/loop-preview" "$@" 2>&1; }
space_field() {
  python3 -I -c 'import json, sys
space = json.loads(open(sys.argv[1]).readline())
print({"name": space["name"], "folder": space["folder"], "argv": " ".join(space["argv"])}[sys.argv[2]])' \
    "$FAKE_HOME/spaces.json" "$1"
}

preview EX-1 >/dev/null && fail "a task without loop-state is refused" || ok
preview ../x >/dev/null && fail "a path as task key is refused" || ok

state set EX-1 mr-open repo=web-app branch=fix/EX-1-thing
FREE=10 preview EX-1 >/dev/null && fail "low memory is refused" || ok
[ -e "$WT" ] && fail "a refused preview creates no worktree" || ok

eq "the preview reports its space" "$(preview EX-1)" "herdr space 'preview EX-1': yarn start in $WT"
eq "the worktree is on the task's branch" "$(git -C "$WT" branch --show-current)" "fix/EX-1-thing"
eq "local files are linked into the new worktree" "$(cat "$FAKE_HOME/wt-setup-calls")" "$WT"
eq "the space is named after the task" "$(space_field name)" "preview EX-1"
eq "the space opens in the worktree" "$(space_field folder)" "$WT"
eq "the space runs the repo's dev command" "$(space_field argv)" "/bin/zsh -lc yarn start"

eq "a second run opens nothing new" "$(preview EX-1)" "herdr space 'preview EX-1' is already open: yarn start in $WT"
eq "one space only" "$(grep -c . "$FAKE_HOME/spaces.json")" "1"

eq "stop closes the space" "$(preview stop EX-1)" "herdr space 'preview EX-1' closed"
eq "stop names the space and confirms" "$(cat "$FAKE_HOME/closed.json")" '{"id": "sp1", "confirmed": true}'
[ -d "$WT" ] && ok || fail "stop keeps the worktree"
eq "stop with nothing running says so" "$(preview stop EX-1)" "no preview of EX-1 is running"
preview stop ../x >/dev/null && fail "stop refuses a path as task key" || ok

echo 'LOOP_DEV_web_app="pwd"' > "$LOOP/config.sh"
eq "here runs the dev command in the worktree, in the caller's terminal" "$(preview here EX-1)" "$WT"
[ -e "$FAKE_HOME/spaces.json" ] && fail "here opens no herdr space" || ok
eq "a finished server is not taken for a running one" "$(preview stop EX-1)" "no preview of EX-1 is running"
echo 'LOOP_DEV_web_app="sleep 60"' > "$LOOP/config.sh"
rm -f "$LOOP/state/preview-EX-1.pid"
(HOME="$FAKE_HOME" LOOP_DIR="$LOOP" "$LOOP/bin/loop-preview" here EX-1 >/dev/null 2>&1 &)
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$LOOP/state/preview-EX-1.pid" ] && break; sleep 0.5; done
SERVER=$(sed -n 1p "$LOOP/state/preview-EX-1.pid" 2>/dev/null)
eq "a second here starts no second server" "$(preview here EX-1)" "dev server of EX-1 is already running: sleep 60 in $WT"
eq "stop ends the server started here" "$(preview stop EX-1)" "dev server of EX-1 stopped"
for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$SERVER" 2>/dev/null || break; sleep 0.5; done
kill -0 "$SERVER" 2>/dev/null && fail "the stopped server is gone" || ok
echo 'LOOP_DEV_web_app="yarn start"' > "$LOOP/config.sh"

FREE=10 FORCE=1 preview EX-1 >/dev/null && ok || fail "FORCE=1 skips the memory check"
eq "an existing worktree is reused" "$(grep -c . "$FAKE_HOME/wt-setup-calls")" "1"

state set EX-2 mr-open repo=web-app branch=fix/EX-2-gone
preview EX-2 >/dev/null && fail "a branch that exists nowhere is refused" || ok

echo 'LOOP_MR_LABELS="x"' > "$LOOP/config.sh"
rm "$FAKE_HOME/spaces.json"
preview EX-1 >/dev/null && fail "a repo without a dev command is refused" || ok

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
