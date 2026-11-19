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
git init -q "$TMP/api"
git -C "$TMP/api" commit -q --allow-empty -m init
git -C "$TMP/api" branch -M staging
git -C "$TMP/api" remote add origin "$TMP/origin.git"
printf '%s\n' "web-app $TMP/web-app staging repo:web-app" "api $TMP/api staging repo:api" > "$LOOP/repos"
printf -- '---\ntask: EX-2\nstatus: ready\n---\n' > "$LOOP/specs/EX-2.md"

fake() { printf '#!/bin/bash\n%s\n' "$2" > "$BIN/$1"; chmod +x "$BIN/$1"; }
fake osascript 'exit 0'
fake curl 'exit 0'
fake herdr-app 'case "$1" in
  status) exit 0 ;;
  do) printf "%s\n" "$3" >> "$HOME/spaces.json" ;;
esac'
fake claude 'case "$*" in
  *"/loop-triage"*)
    printf "%s\n" "$*" > "$HOME/triage-prompt.txt"
    printf "NOTIFY: picked\nPICK: EX-2 web-app medium\nDESIGN: EX-1 web-app low\nDESIGN: EX-5 web-app low\nDESIGN: OT-1 web-app,api high\nDESIGN: UT-1 api low\nCLOSED: EX-9\n### report\n" ;;
  "--bg "*)
    if [ "$PWD" = "$(cat "$HOME/untrusted")" ]; then
      echo "Workspace not trusted. Run claude in $PWD once and accept the trust prompt, then retry."
      exit 1
    fi
    python3 -I -c "import json, sys; print(json.dumps({\"folder\": sys.argv[1], \"argv\": sys.argv[2:]}))" "$PWD" "$@" >> "$HOME/sessions.json"
    echo "Starting background service…"
    echo "backgrounded · abc12345 · $3" ;;
  *) echo "summary" ;;
esac'

run_loop() { HOME="$FAKE_HOME" FORCE=1 bash "$LOOP/bin/loop-run.sh"; }
spec() { LOOP_DIR="$LOOP" "$LOOP/bin/loop-spec" "$@"; }
state() { LOOP_DIR="$LOOP" "$LOOP/bin/loop-state" "$@"; }
session_field() {
  python3 -I -c 'import json,sys
for line in open(sys.argv[1]):
    session = json.loads(line)
    argv = session["argv"]
    if argv[argv.index("-n") + 1] == sys.argv[2]:
        print({"command": argv[-1], "mode": argv[argv.index("--permission-mode") + 1], "folder": session["folder"],
               "adddir": argv[argv.index("--add-dir") + 1],
               "dirs": " ".join(argv[argv.index("--add-dir") + 1:argv.index("--allowedTools")]),
               "deny": " ".join(argv[argv.index("--disallowedTools") + 1:argv.index("--")]),
               "allow": " ".join(argv[argv.index("--allowedTools") + 1:argv.index("--disallowedTools")])}[sys.argv[3]])' \
    "$FAKE_HOME/sessions.json" "$1" "$2"
}

printf -- '---\ntask: EX-9\nstatus: ready\n---\n' > "$LOOP/specs/EX-9.md"
printf -- '---\ntask: EX-8\nstatus: ready\n---\n' > "$LOOP/specs/EX-8.md"
state set EX-8 merged repo=web-app

printf '%s' "$TMP/api" > "$FAKE_HOME/untrusted"
run_loop
LOG=$(ls "$LOOP"/logs/*.md | grep -v launchd | head -n 1)

[ -e "$LOOP/specs/EX-8.md" ] && fail "a merged task's spec is archived at the start of a run" || ok
[ -e "$LOOP/specs/EX-9.md" ] && fail "a task triage reports closed is archived" || ok
[ -f "$LOOP/archive/$(date +%Y-%m)/EX-9/EX-9.md" ] && ok || fail "the closed task's spec is in the archive"
lacks "the report keeps no CLOSED line" "$LOOP/state/last-triage.md" "CLOSED:"
has "the cleanup is logged" "$LOG" "cleanup: archived 1"

has "triage is told the Designer slots of each space" "$FAKE_HOME/triage-prompt.txt" "Designer slots: 1 per space"
has "no space is full before the first design" "$FAKE_HOME/triage-prompt.txt" "Spaces with no free Designer slot: (none)"
has "triage is told the ready specs" "$FAKE_HOME/triage-prompt.txt" "EX-2"
has "triage tools use the configured MCP server" "$FAKE_HOME/triage-prompt.txt" "mcp__workspace__query_view"
eq "pstack link points at the plugin" "$(readlink "$LOOP/pstack")" "$FAKE_HOME/.claude/plugins/cache/market/pstack/1.0.0"

eq "worker is started for the ready spec" "$(state get EX-2 status)" "working"
eq "worker session runs loop-work" "$(session_field "loop EX-2" command)" "/loop-work EX-2 web-app medium"
eq "worker session denies instead of asking" "$(session_field "loop EX-2" mode)" "dontAsk"
eq "worker session opens in a worktree named after its task" "$(session_field "loop EX-2" folder)" "$TMP/web-app/.claude/worktrees/EX-2"
case "$(session_field "loop EX-2" deny)" in *"loop-spec approve"*) ok ;; *) fail "worker may not approve a spec" ;; esac
case "$(session_field "loop EX-2" allow)" in *"Bash(~/loop/bin/loop-preview:*)"*) ok ;; *) fail "worker may open a preview of its task" ;; esac
case "$(session_field "loop EX-2" allow)" in *"Bash(~/loop/bin/loop-upload:*)"*) ok ;; *) fail "worker may upload its e2e screenshots" ;; esac
case "$(session_field "design EX-1" allow)" in *"loop-preview"*) fail "designer opens no preview" ;; *) ok ;; esac
case "$(session_field "loop EX-2" allow)" in *"mcp__claude-in-chrome"*) ok ;; *) fail "worker may drive the browser for e2e" ;; esac
case "$(session_field "design EX-1" allow)" in *"mcp__claude-in-chrome"*) fail "designer drives no browser" ;; *) ok ;; esac

eq "designer claims the design" "$(spec status EX-1)" "designing"
eq "designer session runs loop-design" "$(session_field "design EX-1" command)" "/loop-design EX-1 web-app low"
eq "designer session denies instead of asking" "$(session_field "design EX-1" mode)" "dontAsk"
eq "designer session may read the loop folder from the shell" "$(session_field "design EX-1" adddir)" "$LOOP"
eq "designer session opens in the main checkout" "$(session_field "design EX-1" folder)" "$TMP/web-app"
case "$(session_field "design EX-1" deny)" in *"loop-spec approve"*"git commit"*|*"git commit"*"loop-spec approve"*) ok ;; *) fail "designer may not approve or commit" ;; esac
case "$(session_field "design EX-1" allow)" in *"Write(~/loop/designs/**)"*) ok ;; *) fail "designer writes only its package" ;; esac
case "$(session_field "design EX-1" allow)" in *"Edit "*|*" Write "*) fail "designer has no blanket edit" ;; *) ok ;; esac
has "the run is logged" "$LOG" "designer started EX-1 (web-app, risk:low) — background session 'design EX-1' (claude attach abc12345)"
lacks "the report keeps no DESIGN line" "$LOOP/state/last-triage.md" "DESIGN:"
has "a new Designer is shown in a herdr space attached to its session" "$FAKE_HOME/spaces.json" '{"name": "design EX-1", "folder": "'"$TMP"'/web-app", "tab": "designer", "argv": ["claude", "attach", "abc12345"]}'
has "a new Worker is shown in a herdr space" "$FAKE_HOME/spaces.json" '"name": "loop EX-2", "folder": "'"$TMP"'/web-app/.claude/worktrees/EX-2", "tab": "worker"'
lacks "a session that did not open gets no space" "$FAKE_HOME/spaces.json" "UT-1"

eq "a second task of the same space waits" "$(spec status EX-5)" "none"
has "the waiting task is logged" "$LOG" "designer skipped — EX-5: no free Designer slot in EX"
eq "another space gets its own Designer" "$(spec status OT-1)" "designing"
eq "a design over several repos opens in the first repo" "$(session_field "design OT-1" folder)" "$TMP/web-app"
eq "a design over several repos keeps every repo key" "$(session_field "design OT-1" command)" "/loop-design OT-1 web-app,api high"
eq "the other repo is a working folder" "$(session_field "design OT-1" dirs)" "$LOOP $TMP/api"
case "$(session_field "design OT-1" allow)" in *"Bash(git -C $TMP/api show:*)"*) ok ;; *) fail "designer may read the other repo at its base" ;; esac
case "$(session_field "design EX-1" allow)" in *"git -C"*) fail "a one-repo designer gets no git -C rule" ;; *) ok ;; esac
case "$(session_field "design OT-1" deny)" in *"loop-spec part"*) ok ;; *) fail "designer may not hand out a part" ;; esac

eq "a session that cannot open blocks its design" "$(spec status UT-1)" "blocked"
has "the reason claude gave is logged" "$LOG" "designer FAILED — UT-1: could not open a background session: Workspace not trusted."

run_loop
has "a second run names the full spaces" "$FAKE_HOME/triage-prompt.txt" "Spaces with no free Designer slot: EX OT"
has "a second run lists the design" "$FAKE_HOME/triage-prompt.txt" "- EX-1 designing repo=web-app risk=low"
has "a busy Designer is not doubled" "$LOG" "designer skipped — EX-1: no free Designer slot in EX"
eq "one designer session only" "$(grep -c '"design EX-1"' "$FAKE_HOME/sessions.json")" "1"

state set EX-2 mr-open
run_loop
[ -d "$TMP/web-app/.claude/worktrees/EX-2" ] && ok || fail "a task's worktree stays after its MR opens"

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
