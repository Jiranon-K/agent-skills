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
has()  { grep -qF -- "$3" "$2" 2>/dev/null && ok || fail "$1: '$3' not in $2"; }
lacks() { grep -qF -- "$3" "$2" 2>/dev/null && fail "$1: '$3' found in $2" || ok; }

FAKE_HOME="$TMP/home"
BIN="$FAKE_HOME/.local/bin"
LOOP="$FAKE_HOME/loop"
mkdir -p "$BIN" "$LOOP/bin" "$LOOP/specs" "$FAKE_HOME/.claude/plugins/cache/market/pstack/1.0.0/skills"
for script in loop-run.sh loop-state loop-spec loop-clean; do ln -s "$REPO/loop/bin/$script" "$LOOP/bin/$script"; done
cp "$REPO/loop/config.example.sh" "$LOOP/config.sh"

git init -q --bare "$TMP/origin.git"
git init -q "$TMP/web-app"
git -C "$TMP/web-app" commit -q --allow-empty -m init
git -C "$TMP/web-app" branch -M staging
git -C "$TMP/web-app" remote add origin "$TMP/origin.git"
git -C "$TMP/web-app" push -q origin staging staging:master
echo "web-app $TMP/web-app staging repo:web-app" > "$LOOP/repos"
printf -- '---\ntask: EX-2\nstatus: ready\n---\n' > "$LOOP/specs/EX-2.md"

fake() { printf '#!/bin/bash\n%s\n' "$2" > "$BIN/$1"; chmod +x "$BIN/$1"; }
fake osascript 'exit 0'
fake curl 'exit 0'
fake hc 'exit 1'
fake memory_pressure 'echo "System-wide memory free percentage: 80%"'
fake herdr-core 'cat "$HOME/spaces.json" 2>/dev/null'
fake herdr-app 'case "$1" in status) exit 0 ;; do) printf "%s\n" "$3" >> "$HOME/spaces.json" ;; esac'
fake claude 'case "$*" in
  *"/loop-triage"*)
    printf "%s\n" "$*" > "$HOME/triage-prompt.txt"
    printf "NOTIFY: picked\nPICK: EX-2 web-app medium\nDESIGN: EX-1 web-app low\nCLOSED: EX-9\n### report\n" ;;
  *) echo "summary" ;;
esac'

run_loop() { HOME="$FAKE_HOME" FORCE=1 bash "$LOOP/bin/loop-run.sh"; }
spec() { LOOP_DIR="$LOOP" "$LOOP/bin/loop-spec" "$@"; }
state() { LOOP_DIR="$LOOP" "$LOOP/bin/loop-state" "$@"; }
session_field() {
  python3 -I -c 'import json,sys
for line in open(sys.argv[1]):
    space = json.loads(line)
    if space["name"] == sys.argv[2]:
        argv = space["argv"]
        print({"command": argv[-1], "mode": argv[argv.index("--permission-mode") + 1], "folder": space["folder"],
               "adddir": argv[argv.index("--add-dir") + 1],
               "deny": " ".join(argv[argv.index("--disallowedTools") + 1:argv.index("--")]),
               "allow": " ".join(argv[argv.index("--allowedTools") + 1:argv.index("--disallowedTools")])}[sys.argv[3]])' \
    "$FAKE_HOME/spaces.json" "$1" "$2"
}

printf -- '---\ntask: EX-9\nstatus: ready\n---\n' > "$LOOP/specs/EX-9.md"
printf -- '---\ntask: EX-8\nstatus: ready\n---\n' > "$LOOP/specs/EX-8.md"
state set EX-8 merged repo=web-app

run_loop
LOG=$(ls "$LOOP"/logs/*.md | grep -v launchd | head -n 1)

[ -e "$LOOP/specs/EX-8.md" ] && fail "a merged task's spec is archived at the start of a run" || ok
[ -e "$LOOP/specs/EX-9.md" ] && fail "a task triage reports closed is archived" || ok
[ -f "$LOOP/archive/$(date +%Y-%m)/EX-9/EX-9.md" ] && ok || fail "the closed task's spec is in the archive"
lacks "the report keeps no CLOSED line" "$LOOP/state/last-triage.md" "CLOSED:"
has "the cleanup is logged" "$LOG" "cleanup: archived 1"

has "triage is told the Designer slots" "$FAKE_HOME/triage-prompt.txt" "Designer slots: 1"
has "triage is told the ready specs" "$FAKE_HOME/triage-prompt.txt" "EX-2"
has "triage tools use the configured MCP server" "$FAKE_HOME/triage-prompt.txt" "mcp__workspace__query_view"
eq "pstack link points at the plugin" "$(readlink "$LOOP/pstack")" "$FAKE_HOME/.claude/plugins/cache/market/pstack/1.0.0"

eq "worker is started for the ready spec" "$(state get EX-2 status)" "working"
eq "worker session runs loop-work" "$(session_field "loop EX-2" command)" "/loop-work EX-2 web-app medium"
eq "worker session denies instead of asking" "$(session_field "loop EX-2" mode)" "dontAsk"
eq "worker session opens in its slot" "$(session_field "loop EX-2" folder)" "$TMP/web-app/.claude/worktrees/loop-1"
case "$(session_field "loop EX-2" deny)" in *"loop-spec approve"*) ok ;; *) fail "worker may not approve a spec" ;; esac

eq "designer claims the design" "$(spec status EX-1)" "designing"
eq "designer session runs loop-design" "$(session_field "design EX-1" command)" "/loop-design EX-1 web-app low"
eq "designer session denies instead of asking" "$(session_field "design EX-1" mode)" "dontAsk"
eq "designer session may read the loop folder from the shell" "$(session_field "design EX-1" adddir)" "$LOOP"
eq "designer session opens in the main checkout" "$(session_field "design EX-1" folder)" "$TMP/web-app"
case "$(session_field "design EX-1" deny)" in *"loop-spec approve"*"git commit"*|*"git commit"*"loop-spec approve"*) ok ;; *) fail "designer may not approve or commit" ;; esac
case "$(session_field "design EX-1" allow)" in *"Write(~/loop/designs/**)"*) ok ;; *) fail "designer writes only its package" ;; esac
case "$(session_field "design EX-1" allow)" in *"Edit "*|*" Write "*) fail "designer has no blanket edit" ;; *) ok ;; esac
has "the run is logged" "$LOG" "designer started EX-1 (web-app, risk:low)"
lacks "the report keeps no DESIGN line" "$LOOP/state/last-triage.md" "DESIGN:"

run_loop
has "a second run sees no free Designer slot" "$FAKE_HOME/triage-prompt.txt" "Designer slots: 0"
has "a second run lists the design" "$FAKE_HOME/triage-prompt.txt" "- EX-1 designing repo=web-app risk=low"
has "a busy Designer is not doubled" "$LOG" "designer skipped — EX-1: no free Designer slot"
eq "one designer session only" "$(grep -c '"design EX-1"' "$FAKE_HOME/spaces.json")" "1"

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
