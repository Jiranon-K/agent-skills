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
for script in loop-run.sh loop-state loop-spec loop-clean loop-orca; do ln -s "$REPO/loop/bin/$script" "$LOOP/bin/$script"; done
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
fake orca 'case "$1 $2" in
  "open "*) echo "{\"ok\": true}" ;;
  "terminal create")
    if [ "$6" = "$(cat "$HOME/unopenable")" ]; then
      echo "{\"ok\": false, \"error\": {\"code\": \"selector_not_found\", \"message\": \"no such worktree\"}}"; exit 1
    fi
    number=$(($(cat "$HOME/terminal-count" 2>/dev/null || echo 0) + 1))
    echo "$number" > "$HOME/terminal-count"
    printf "%s\t%s\t%s\n" "$6" "${4#path:}" "$number" >> "$HOME/terminals.tsv"
    eval "$8" > /dev/null
    echo "{\"ok\": true, \"result\": {\"terminal\": {\"handle\": \"term_$number\", \"paneKey\": \"tab$number:leaf$number\"}}}" ;;
  "terminal list")
    python3 -I -c "import json, sys
rows = [line.rstrip(chr(10)).split(chr(9)) for line in open(sys.argv[1])] if len(sys.argv) > 1 else []
print(json.dumps({\"ok\": True, \"result\": {\"terminals\": [{\"handle\": \"term_\" + r[2], \"tabId\": \"tab\" + r[2], \"leafId\": \"leaf\" + r[2], \"worktreePath\": r[1], \"agentIdentity\": \"claude\"} for r in rows]}}))" $(ls "$HOME/terminals.tsv" 2>/dev/null) ;;
  "terminal close")
    : > "$HOME/terminals.tmp"
    while IFS="$(printf "\t")" read -r title workspace number; do
      if [ "term_$number" = "$4" ]; then echo "$title" >> "$HOME/closed"; continue; fi
      printf "%s\t%s\t%s\n" "$title" "$workspace" "$number" >> "$HOME/terminals.tmp"
    done < "$HOME/terminals.tsv"
    mv "$HOME/terminals.tmp" "$HOME/terminals.tsv"
    echo "{\"ok\": true}" ;;
  "agent list")
    python3 -I -c "import json, sys
rows = [line.rstrip(chr(10)).split(chr(9)) for line in open(sys.argv[1])] if len(sys.argv) > 1 else []
print(json.dumps({\"ok\": True, \"result\": {\"agents\": [{\"kind\": \"terminal\", \"paneKey\": \"tab\" + r[2] + \":leaf\" + r[2], \"updatedAt\": n} for n, r in enumerate(rows)]}}))" $(ls "$HOME/terminals.tsv" 2>/dev/null) ;;
  "terminal rename") printf "%s\t%s\n" "$4" "$6" >> "$HOME/marks"; echo "{\"ok\": true}" ;;
esac'
fake claude 'case "$*" in
  *"/jk-loop:triage"*)
    printf "%s\n" "$*" > "$HOME/triage-prompt.txt"
    if [ -f "$HOME/triage-out" ]; then cat "$HOME/triage-out"; exit 0; fi
    printf "NOTIFY: picked\nPICK: EX-2 web-app medium\nDESIGN: EX-1 web-app low\nDESIGN: EX-5 web-app low\nDESIGN: OT-1 web-app,api high\nDESIGN: UT-1 api low\nCLOSED: EX-9\n### report\n" ;;
  "--session-id "*|"--resume "*)
    python3 -I -c "import json, sys; print(json.dumps({\"folder\": sys.argv[1], \"argv\": sys.argv[2:]}))" "$PWD" "$@" >> "$HOME/sessions.json" ;;
  *) echo "summary" ;;
esac'

run_loop() { HOME="$FAKE_HOME" LOOP_ORCA="$BIN/orca" bash "$LOOP/bin/loop-run.sh"; }
spec() { LOOP_DIR="$LOOP" "$LOOP/bin/loop-spec" "$@"; }
state() { LOOP_DIR="$LOOP" LOOP_ORCA="$BIN/orca" HOME="$FAKE_HOME" "$LOOP/bin/loop-state" "$@"; }
session_field() {
  python3 -I -c 'import json,sys
for line in open(sys.argv[1]):
    session = json.loads(line)
    argv = session["argv"]
    if argv[argv.index("-n") + 1] == sys.argv[2]:
        print({"command": argv[-1], "mode": argv[argv.index("--permission-mode") + 1], "folder": session["folder"],
               "adddir": argv[argv.index("--add-dir") + 1],
               "dirs": " ".join(argv[argv.index("--add-dir") + 1:argv.index("--disallowedTools")]),
               "deny": " ".join(argv[argv.index("--disallowedTools") + 1:argv.index("--")]),
               "how": argv[0], "session": argv[1]}[sys.argv[3]])' \
    "$FAKE_HOME/sessions.json" "$1" "$2"
}

printf -- '---\ntask: EX-9\nstatus: ready\n---\n' > "$LOOP/specs/EX-9.md"
printf -- '---\ntask: EX-8\nstatus: ready\n---\n' > "$LOOP/specs/EX-8.md"
state set EX-8 merged repo=web-app

printf '%s' "design UT-1" > "$FAKE_HOME/unopenable"
RECORDS="$LOOP/state/orca-terminals.tsv"
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
eq "worker session runs jk-loop:work" "$(session_field "loop EX-2" command)" "/jk-loop:work EX-2 web-app medium"
eq "worker session asks for no permission" "$(session_field "loop EX-2" mode)" "bypassPermissions"
eq "worker session opens in a worktree named after its task" "$(session_field "loop EX-2" folder)" "$TMP/web-app/.claude/worktrees/EX-2"
case "$(session_field "loop EX-2" deny)" in *"loop-spec approve"*) ok ;; *) fail "worker may not approve a spec" ;; esac
case "$(session_field "loop EX-2" deny)" in *"Bash(git push:*)"*"Read(**/.env*)"*|*"Read(**/.env*)"*"Bash(git push:*)"*) ok ;; *) fail "worker may not push or read .env" ;; esac
eq "worker session starts under a new session id" "$(session_field "loop EX-2" how)" "--session-id"
eq "the Worker's session id is kept in its state" "$(state get EX-2 session)" "$(session_field "loop EX-2" session)"

eq "designer claims the design" "$(spec status EX-1)" "designing"
eq "designer session runs jk-loop:design" "$(session_field "design EX-1" command)" "/jk-loop:design EX-1 web-app low"
eq "designer session asks for no permission" "$(session_field "design EX-1" mode)" "bypassPermissions"
eq "designer session may read the loop folder from the shell" "$(session_field "design EX-1" adddir)" "$LOOP"
eq "designer session opens in the main checkout" "$(session_field "design EX-1" folder)" "$TMP/web-app"
case "$(session_field "design EX-1" deny)" in *"loop-spec approve"*"git commit"*|*"git commit"*"loop-spec approve"*) ok ;; *) fail "designer may not approve or commit" ;; esac
case "$(session_field "design EX-1" deny)" in *"Edit(/$TMP/web-app/**)"*"Write(/$TMP/web-app/**)"*) ok ;; *) fail "designer may not edit the repo" ;; esac
has "the run is logged" "$LOG" "designer started EX-1 (web-app, risk:low) — Orca session 'design EX-1' (claude --resume "
lacks "the report keeps no DESIGN line" "$LOOP/state/last-triage.md" "DESIGN:"
has "a new Designer opens in a terminal of the Orca workspace" "$FAKE_HOME/terminals.tsv" "design EX-1"$'\t'"$FAKE_HOME/Home"$'\t'
has "a new Worker opens in a terminal of the Orca workspace" "$FAKE_HOME/terminals.tsv" "loop EX-2"$'\t'"$FAKE_HOME/Home"$'\t'
has "the Worker's terminal is recorded for its worktree" "$RECORDS" "$TMP/web-app/.claude/worktrees/EX-2"$'\t'"tab1:leaf1"$'\t'"loop EX-2"
lacks "a session that did not open gets no terminal" "$FAKE_HOME/terminals.tsv" "UT-1"

eq "a second task of the same space waits" "$(spec status EX-5)" "none"
has "the waiting task is logged" "$LOG" "designer skipped — EX-5: no free Designer slot in EX"
eq "another space gets its own Designer" "$(spec status OT-1)" "designing"
eq "a design over several repos opens in the first repo" "$(session_field "design OT-1" folder)" "$TMP/web-app"
eq "a design over several repos keeps every repo key" "$(session_field "design OT-1" command)" "/jk-loop:design OT-1 web-app,api high"
eq "the other repo is a working folder" "$(session_field "design OT-1" dirs)" "$LOOP $TMP/api"
case "$(session_field "design OT-1" deny)" in *"Edit(/$TMP/api/**)"*) ok ;; *) fail "designer may not edit the other repo" ;; esac
case "$(session_field "design OT-1" deny)" in *"loop-spec part"*) ok ;; *) fail "designer may not hand out a part" ;; esac

eq "a session that cannot open blocks its design" "$(spec status UT-1)" "blocked"
has "the reason is logged" "$LOG" "designer FAILED — UT-1: could not open a session: loop-orca: Orca could not open a terminal in $TMP/api: no such worktree"

run_loop
has "a second run names the full spaces" "$FAKE_HOME/triage-prompt.txt" "Spaces with no free Designer slot: EX OT"
has "a second run lists the design" "$FAKE_HOME/triage-prompt.txt" "- EX-1 designing repo=web-app risk=low"
has "a busy Designer is not doubled" "$LOG" "designer skipped — EX-1: no free Designer slot in EX"
eq "one designer session only" "$(grep -c '"design EX-1"' "$FAKE_HOME/sessions.json")" "1"

eq "a live Worker is not opened twice" "$(grep -c '"loop EX-2"' "$FAKE_HOME/sessions.json")" "1"

grep -v "loop EX-2" "$FAKE_HOME/terminals.tsv" > "$FAKE_HOME/terminals.tmp"; mv "$FAKE_HOME/terminals.tmp" "$FAKE_HOME/terminals.tsv"
run_loop
eq "a Worker whose session is gone is opened again" "$(grep -c '"loop EX-2"' "$FAKE_HOME/sessions.json")" "2"
has "the Worker is resumed under its session id" "$FAKE_HOME/sessions.json" "[\"--resume\", \"$(state get EX-2 session)\""
has "the resume is logged" "$LOG" "worker resumed EX-2"

state set EX-2 mr-open
has "a task's status is shown in the title of its terminal" "$FAKE_HOME/marks" "$(printf 'term_%s\tloop EX-2 · รอ verify' "$(grep "loop EX-2" "$FAKE_HOME/terminals.tsv" | cut -f3)")"
run_loop
[ -d "$TMP/web-app/.claude/worktrees/EX-2" ] && ok || fail "a task's worktree stays after its MR opens"

for task in EX-20 EX-21 EX-22; do printf -- '---\ntask: %s\nstatus: ready\n---\n' "$task" > "$LOOP/specs/$task.md"; done
printf 'NOTIFY: none\nPICK: EX-20 web-app low after=EX-2\nPICK: EX-21 web-app low after=EX-22\nPICK: EX-22 web-app low\nDESIGN: none\nCLOSED: none\n' > "$FAKE_HOME/triage-out"
ONLY_TASK=EX-20 LOOP_MAX_WORKERS=3 run_loop
has "the run names its only task to triage" "$FAKE_HOME/triage-prompt.txt" "Only task: EX-20"
has "a task waits for a blocker that is not merged" "$LOG" "worker skipped — EX-20: its blocker EX-2 is not merged"
errs_state() { state get "$2" >/dev/null 2>&1 && fail "$1" || ok; }
errs_state "a run for one task starts no other task" EX-22

LOOP_MAX_WORKERS=1 run_loop
has "a task waits for a blocker picked in the same run" "$LOG" "worker skipped — EX-21: its blocker EX-22 is not merged"
eq "the free slot goes to the task with no blocker" "$(state get EX-22 status)" "working"
eq "only the idle session of a task with an open MR is closed when sessions exceed the Worker limit" "$(sort -u "$FAKE_HOME/closed")" "loop EX-2"
lacks "a closed session leaves no record" "$RECORDS" "$TMP/web-app/.claude/worktrees/EX-2"$'\t'
has "a working session keeps its record" "$RECORDS" "$TMP/web-app/.claude/worktrees/EX-22"$'\t'

printf 'true\n' > "$TMP/probe.sh"
orca() { HOME="$FAKE_HOME" LOOP_ORCA="$BIN/orca" "$LOOP/bin/loop-orca" "$@"; }
LOOP_ORCA_WORKSPACE="$TMP/elsewhere" orca launch "probe" "$TMP/outside" "$TMP/probe.sh"
has "LOOP_ORCA_WORKSPACE names the Orca workspace" "$FAKE_HOME/terminals.tsv" "probe"$'\t'"$TMP/elsewhere"$'\t'
orca alive "$TMP/outside" > /dev/null && ok || fail "a launched folder is alive"
orca alive "$TMP/outside-other" > /dev/null && fail "a folder with no terminal is not alive" || ok
orca close "$TMP/outside"
orca alive "$TMP/outside" > /dev/null && fail "a closed folder is not alive" || ok
lacks "closing one folder closes no other terminal" "$FAKE_HOME/closed" "EX-22"

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
