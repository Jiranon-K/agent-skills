#!/bin/bash
set -u
cd "$(dirname "$0")/../.."
REPO="$(pwd)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export LOOP_DIR="$TMP/loop" LOOP_WATCH_INTERVAL=0 LOOP_WATCH_TIMEOUT=3
export GATES="$TMP/gates" ASKED="$TMP/asked"

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
eq()   { [ "$2" = "$3" ] && ok || fail "$1: expected '$3', got '$2'"; }

mkdir -p "$LOOP_DIR/bin"
WATCH="$REPO/loop/bin/loop-watch"
cat > "$LOOP_DIR/bin/loop-merge" <<'MERGE'
#!/bin/bash
echo "$*" >> "$ASKED"
echo "loop-merge: a line on stderr" >&2
head -n 1 "$GATES"
[ "$(wc -l < "$GATES")" -gt 1 ] && sed -i '' '1d' "$GATES"
exit 0
MERGE
chmod +x "$LOOP_DIR/bin/loop-merge"

gates() { printf '%s\n' "$@" > "$GATES"; rm -f "$ASKED"; }
asked() { wc -l < "$ASKED" | tr -d ' '; }

gates "would merge https://x/-/merge_requests/7 into staging (pipeline success)"
eq "every gate passing with a green pipeline is READY" "$("$WATCH" EX-1)" "READY"
eq "it asks loop-merge for a dry run only" "$(cat "$ASKED")" "--dry-run EX-1"
gates "would merge https://x/-/merge_requests/7 into staging (pipeline )"
eq "a repo with no pipeline is READY" "$("$WATCH" EX-1)" "READY"
gates "would merge https://x/-/merge_requests/7 into staging (pipeline running)"
eq "a running pipeline is WAITING" "$("$WATCH" EX-1)" "WAITING pipeline running"
eq "one pass asks once" "$(asked)" "1"
gates "refused: MR !7 still has needs:e2e: run /jk-loop:e2e EX-1 first"
eq "needs:e2e waits for the owner" "$("$WATCH" EX-1)" "WAITING MR !7 still has needs:e2e: run /jk-loop:e2e EX-1 first"
gates "refused: merge-back pending: master has 2 commit(s) not in staging; wait for the merge-back"
eq "a pending merge-back is WAITING" "$("$WATCH" EX-1 | cut -d' ' -f1)" "WAITING"
gates "refused: the head pipeline of MR !7 failed"
eq "a failed pipeline is BLOCKED" "$("$WATCH" EX-1)" "BLOCKED the head pipeline of MR !7 failed"
gates "refused: the verdict of EX-1 is stale PASS: a PASS on the current patch is needed"
eq "a stale verdict is BLOCKED" "$("$WATCH" EX-1 | cut -d' ' -f1-7)" "BLOCKED the verdict of EX-1 is stale"
gates ""
eq "no answer from loop-merge is BLOCKED" "$("$WATCH" EX-1)" "BLOCKED loop-merge gave no answer for EX-1"

gates "would merge u into staging (pipeline pending)" "would merge u into staging (pipeline running)" "would merge u into staging (pipeline success)"
eq "--wait polls until the pipeline ends" "$("$WATCH" --wait EX-1)" "READY"
eq "--wait asked once per pass" "$(asked)" "3"
gates "would merge u into staging (pipeline running)" "refused: the head pipeline of MR !7 failed"
eq "--wait stops on a blocker" "$("$WATCH" --wait EX-1)" "BLOCKED the head pipeline of MR !7 failed"
gates "would merge u into staging (pipeline running)"
LOOP_WATCH_INTERVAL=1 LOOP_WATCH_TIMEOUT=2 "$WATCH" --wait EX-1 > "$TMP/out"
eq "--wait gives up after the timeout" "$(cat "$TMP/out")" "WAITING pipeline running"
"$WATCH" >/dev/null 2>&1 && fail "a missing task is refused" || ok

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
