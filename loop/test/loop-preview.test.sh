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
fake "$FAKE_HOME/.claude/hooks/wt-setup" 'printf "%s\n" "$1" >> "$HOME/wt-setup-calls"'

state() { LOOP_DIR="$LOOP" "$LOOP/bin/loop-state" "$@"; }
preview() { HOME="$FAKE_HOME" LOOP_DIR="$LOOP" "$LOOP/bin/loop-preview" "$@" 2>&1; }
server() { sed -n 1p "$LOOP/state/preview-EX-1.pid" 2>/dev/null; }
gone() {
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$1" 2>/dev/null || return 0; sleep 0.5; done
  return 1
}

preview EX-1 >/dev/null && fail "a task without loop-state is refused" || ok
preview ../x >/dev/null && fail "a path as task key is refused" || ok

state set EX-1 mr-open repo=web-app branch=fix/EX-1-thing

echo 'LOOP_DEV_web_app="sleep 60"' > "$LOOP/config.sh"
eq "the preview reports its server" "$(preview EX-1)" "dev server of EX-1 started: sleep 60 in $WT (log: $LOOP/state/preview-EX-1.log)"
eq "the worktree is on the task's branch" "$(git -C "$WT" branch --show-current)" "fix/EX-1-thing"
eq "local files are linked into the new worktree" "$(cat "$FAKE_HOME/wt-setup-calls")" "$WT"
SERVER=$(server)
eq "the server runs in the worktree" "$(lsof -a -p "$SERVER" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')" "$(cd "$WT" && pwd -P)"

eq "a second run starts nothing new" "$(preview EX-1)" "dev server of EX-1 is already running: sleep 60 in $WT"
eq "one server only" "$(server)" "$SERVER"

eq "stop ends the detached server" "$(preview stop EX-1)" "dev server of EX-1 stopped"
gone "$SERVER" && ok || fail "the stopped detached server is gone"
[ -d "$WT" ] && ok || fail "stop keeps the worktree"
eq "stop with nothing running says so" "$(preview stop EX-1)" "no preview of EX-1 is running"
preview stop ../x >/dev/null && fail "stop refuses a path as task key" || ok

echo 'LOOP_DEV_web_app="pwd"' > "$LOOP/config.sh"
eq "here runs the dev command in the worktree, in the caller's terminal" "$(preview here EX-1)" "$WT"
eq "a finished server is not taken for a running one" "$(preview stop EX-1)" "no preview of EX-1 is running"
echo 'LOOP_DEV_web_app="sleep 60"' > "$LOOP/config.sh"
rm -f "$LOOP/state/preview-EX-1.pid"
(HOME="$FAKE_HOME" LOOP_DIR="$LOOP" "$LOOP/bin/loop-preview" here EX-1 >/dev/null 2>&1 &)
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$LOOP/state/preview-EX-1.pid" ] && break; sleep 0.5; done
SERVER=$(server)
eq "a second here starts no second server" "$(preview here EX-1)" "dev server of EX-1 is already running: sleep 60 in $WT"
eq "stop ends the server started here" "$(preview stop EX-1)" "dev server of EX-1 stopped"
gone "$SERVER" && ok || fail "the stopped server is gone"

preview EX-1 >/dev/null
preview stop EX-1 >/dev/null
eq "an existing worktree is reused" "$(grep -c . "$FAKE_HOME/wt-setup-calls")" "1"

state set EX-2 mr-open repo=web-app branch=fix/EX-2-gone
preview EX-2 >/dev/null && fail "a branch that exists nowhere is refused" || ok

echo 'LOOP_MR_LABELS="x"' > "$LOOP/config.sh"
preview EX-1 >/dev/null && fail "a repo without a dev command is refused" || ok

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
