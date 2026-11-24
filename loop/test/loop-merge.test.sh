#!/bin/bash
set -u
cd "$(dirname "$0")/../.."
REPO="$(pwd)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export LOOP_ORCA=off
export LOOP_DIR="$TMP/loop" LOOP_MERGE_WAIT=0
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
eq()   { [ "$2" = "$3" ] && ok || fail "$1: expected '$3', got '$2'"; }
has()  { case "$2" in *"$3"*) ok ;; *) fail "$1: '$3' not in '$2'" ;; esac; }

mkdir -p "$LOOP_DIR/bin" "$TMP/bin"
ln -s "$REPO/loop/bin/loop-state" "$LOOP_DIR/bin/loop-state"
ln -s "$REPO/loop/bin/loop-verdict" "$LOOP_DIR/bin/loop-verdict"
MERGE="$REPO/loop/bin/loop-merge"
ORIGIN="$TMP/origin.git"
MAIN="$TMP/web-app"
URL="https://gitlab.com/team/web-app/-/merge_requests/7"
export CALLS="$TMP/glab-calls" MR_JSON="$TMP/mr.json" THREADS="$TMP/threads.ndjson" ORIGIN

git init -q --bare "$ORIGIN"
git init -q "$MAIN"
git -C "$MAIN" remote add origin "$ORIGIN"
echo one > "$MAIN/a.txt"
git -C "$MAIN" add a.txt
git -C "$MAIN" commit -q -m init
git -C "$MAIN" branch -M staging
git -C "$MAIN" push -q origin staging
git -C "$MAIN" switch -q -c feat/ex-1
echo two > "$MAIN/b.txt"
git -C "$MAIN" add b.txt
git -C "$MAIN" commit -q -m "wip one"
echo three >> "$MAIN/b.txt"
git -C "$MAIN" commit -q -am "wip two"
git -C "$MAIN" push -q origin feat/ex-1
git -C "$MAIN" switch -q staging
HEAD_SHA=$(git -C "$MAIN" rev-parse feat/ex-1)

echo "web-app $MAIN staging repo:web-app" > "$LOOP_DIR/repos"
printf 'LOOP_MR_LABELS="owner:you,needs:human-verify"\nRELEASE_REPO="other"\n' > "$LOOP_DIR/config.sh"

cat > "$TMP/bin/glab" <<'GLAB'
#!/bin/bash
case "$1 $2" in
  "mr view")
    python3 -I -c '
import json, os, subprocess, sys
mr = json.load(open(sys.argv[1]))
if os.path.exists(sys.argv[1] + ".merged"):
    mr["state"] = "merged"
    mr["merge_commit_sha"] = "abc123"
head = subprocess.run(["git", "-C", sys.argv[2], "rev-parse", "-q", "--verify", "refs/heads/" + mr["source_branch"]], capture_output=True, text=True).stdout.strip()
if head and subprocess.run(["git", "-C", sys.argv[2], "merge-base", "--is-ancestor", head, "staging"]).returncode == 0:
    mr["state"] = "merged"
print(json.dumps(mr))' "$MR_JSON" "$ORIGIN" ;;
  "mr update")
    printf '%s\n' "$*" >> "$CALLS"
    python3 -I -c '
import json, sys
mr = json.load(open(sys.argv[1]))
mr["draft"] = False
mr["labels"] = [label for label in mr["labels"] if label != "needs:human-verify"]
json.dump(mr, open(sys.argv[1], "w"))' "$MR_JSON" ;;
  "api "*) cat "$THREADS" ;;
  "mr merge") printf '%s\n' "$*" >> "$CALLS"; touch "$MR_JSON.merged" ;;
  *) printf '%s\n' "$*" >> "$CALLS" ;;
esac
GLAB
chmod +x "$TMP/bin/glab"
export PATH="$TMP/bin:$PATH"

mr_json() {
  python3 -I -c '
import json, sys
print(json.dumps({"iid": 7, "project_id": 1, "state": "opened", "draft": True, "title": "Draft: feat(x): add b",
  "source_branch": "feat/ex-1", "target_branch": "staging", "sha": sys.argv[1], "web_url": sys.argv[3],
  "labels": sys.argv[2].split(","), "head_pipeline": {"status": sys.argv[4]}}))' "$HEAD_SHA" "$1" "$URL" "${2:-success}" > "$MR_JSON"
  : > "$THREADS"
  rm -f "$CALLS"
}
run() { "$MERGE" "$@" 2>/dev/null; }
verdict() {
  echo "checked by hand" > "$TMP/notes"
  "$LOOP_DIR/bin/loop-verdict" "$1" "$2" "$TMP/notes" >/dev/null 2>&1
}
refused() {
  local out
  out=$(run EX-1)
  [ $? -ne 0 ] && ok || fail "$1: expected a non-zero exit"
  out=$(printf '%s\n' "$out" | tail -n 1)
  eq "$1 starts with refused" "${out%%:*}" "refused"
  has "$1" "$out" "$2"
  [ -e "$CALLS" ] && fail "$1: glab changed something" || ok
}

mr_json "owner:you,needs:human-verify"
eq "a task with no state is refused" "$(run EX-9)" "refused: EX-9 has no loop-state"
"$LOOP_DIR/bin/loop-state" set EX-1 working repo=web-app branch=feat/ex-1 mr="$URL"
refused "a task that is not mr-open" "EX-1 is working, not mr-open"
"$LOOP_DIR/bin/loop-state" set EX-1 mr-open
mr_json "owner:you,needs:human-verify,needs:e2e"
refused "an MR with needs:e2e" "still has needs:e2e"
mr_json "needs:human-verify"
refused "an MR without the owner label" "lacks the label owner:you"
mr_json "owner:you,needs:human-verify" failed
refused "an MR whose pipeline failed" "pipeline of MR !7 failed"
mr_json "owner:you,needs:human-verify"
echo '{"notes":[{"resolvable":true,"resolved":false}]}' > "$THREADS"
refused "an MR with an unresolved thread" "1 unresolved thread"
mr_json "owner:you,needs:human-verify"
python3 -I -c 'import json,sys; m=json.load(open(sys.argv[1])); m["has_conflicts"]=True; json.dump(m, open(sys.argv[1],"w"))' "$MR_JSON"
refused "an MR with a conflict" "conflicts with staging"
mr_json "owner:you,needs:human-verify"
refused "an MR with no verdict" "the verdict of EX-1 is none"
verdict EX-1 FAIL
has "a verdict is posted on the MR" "$(cat "$CALLS")" "mr note create 7 -R gitlab.com/team/web-app --resolvable=false -m **Loop verdict: FAIL**"
mr_json "owner:you,needs:human-verify"
refused "an MR whose verdict is FAIL" "the verdict of EX-1 is current FAIL"
verdict EX-1 PASS
eq "a verdict on the pushed patch is current" "$("$LOOP_DIR/bin/loop-verdict" EX-1 check)" "current PASS"
"$LOOP_DIR/bin/loop-verdict" EX-1 MAYBE "$TMP/notes" >/dev/null 2>&1 && fail "an unknown verdict is refused" || ok
: > "$TMP/empty"
"$LOOP_DIR/bin/loop-verdict" EX-1 PASS "$TMP/empty" >/dev/null 2>&1 && fail "a verdict without notes is refused" || ok
mr_json "owner:you,needs:human-verify"
eq "a dry run only checks the gates" "$(run --dry-run EX-1)" "would merge $URL into staging (pipeline success)"
eq "a dry run changes nothing" "$([ -e "$CALLS" ] && echo called || echo none)" "none"

OUT=$(run EX-1)
LAST=$(printf '%s\n' "$OUT" | tail -n 1)
MERGE_SHA=$(git -C "$ORIGIN" rev-parse staging)
eq "the last line names the merge commit" "$LAST" "merged $MERGE_SHA $URL"
has "the MR is marked ready" "$(cat "$CALLS")" "mr update 7 -R gitlab.com/team/web-app --ready --unlabel needs:human-verify"
eq "the base gets a merge commit" "$(git -C "$ORIGIN" rev-list --count --merges staging)" "1"
eq "the merge keeps the branch name" "$(git -C "$ORIGIN" log -1 --format=%s staging)" "Merge branch 'feat/ex-1' into 'staging'"
has "the merge links the MR" "$(git -C "$ORIGIN" log -1 --format=%B staging)" "See merge request team/web-app!7"
eq "the squash commit has the MR title" "$(git -C "$ORIGIN" log -1 --format=%s staging^2)" "feat(x): add b"
eq "the squash commit sits on the old base" "$(git -C "$ORIGIN" rev-parse staging^2^)" "$(git -C "$MAIN" rev-parse staging)"
eq "the merged branch is deleted on origin" "$(git -C "$ORIGIN" branch --list feat/ex-1)" ""
eq "no temporary worktree is left" "$(git -C "$MAIN" worktree list | wc -l | tr -d ' ')" "1"

git -C "$MAIN" fetch -q origin
git -C "$MAIN" switch -q -c feat/ex-2 origin/staging
echo conflict > "$MAIN/a.txt"
git -C "$MAIN" commit -q -am "change a"
git -C "$MAIN" push -q origin feat/ex-2
git -C "$MAIN" switch -q staging
git -C "$MAIN" reset -q --hard origin/staging
echo other > "$MAIN/a.txt"
git -C "$MAIN" commit -q -am "other a"
git -C "$MAIN" push -q origin staging
HEAD_SHA=$(git -C "$MAIN" rev-parse feat/ex-2)
"$LOOP_DIR/bin/loop-state" set EX-2 mr-open repo=web-app branch=feat/ex-2 mr="$URL"
verdict EX-2 PASS
git -C "$MAIN" switch -q feat/ex-2
echo more >> "$MAIN/a.txt"
git -C "$MAIN" commit -q -am "change a again"
git -C "$MAIN" push -q origin feat/ex-2
git -C "$MAIN" switch -q staging
HEAD_SHA=$(git -C "$MAIN" rev-parse feat/ex-2)
eq "a verdict on an older patch is stale" "$("$LOOP_DIR/bin/loop-verdict" EX-2 check)" "stale PASS"
verdict EX-2 PASS
mr_json "owner:you,needs:human-verify"
python3 -I -c 'import json,sys; m=json.load(open(sys.argv[1])); m["source_branch"]="feat/ex-2"; json.dump(m, open(sys.argv[1],"w"))' "$MR_JSON"
OUT=$(run EX-2)
eq "a squash conflict exits non-zero" "$?" "1"
eq "a squash conflict names the files" "$(printf '%s\n' "$OUT" | tail -n 1)" "refused: squash conflicts in: a.txt; resolve them on feat/ex-2 first"
eq "a conflict leaves no temporary worktree" "$(git -C "$MAIN" worktree list | wc -l | tr -d ' ')" "1"
eq "a conflict leaves the branch on origin as it was" "$(git -C "$ORIGIN" rev-parse feat/ex-2)" "$HEAD_SHA"

git -C "$MAIN" switch -q -c feat/ex-3 origin/staging
echo four > "$MAIN/c.txt"
git -C "$MAIN" add c.txt
git -C "$MAIN" commit -q -m "add c"
git -C "$MAIN" push -q origin feat/ex-3
git -C "$MAIN" switch -q staging
printf '#!/bin/sh\nwhile read old new ref; do [ "$ref" = refs/heads/staging ] && { echo "You are not allowed to push code to protected branches on this project." >&2; exit 1; }; done\nexit 0\n' > "$ORIGIN/hooks/pre-receive"
chmod +x "$ORIGIN/hooks/pre-receive"
HEAD_SHA=$(git -C "$MAIN" rev-parse feat/ex-3)
BASE_SHA=$(git -C "$ORIGIN" rev-parse staging)
"$LOOP_DIR/bin/loop-state" set EX-3 mr-open repo=web-app branch=feat/ex-3 mr="$URL"
verdict EX-3 PASS
mr_json "owner:you,needs:human-verify"
python3 -I -c 'import json,sys; m=json.load(open(sys.argv[1])); m["source_branch"]="feat/ex-3"; json.dump(m, open(sys.argv[1],"w"))' "$MR_JSON"
OUT=$(run EX-3)
eq "a protected base exits non-zero" "$?" "1"
has "a protected base sends the owner to the web" "$(printf '%s\n' "$OUT" | tail -n 1)" "refused: GitLab rejected the push to refs/heads/staging as protected"
eq "a protected base leaves the base as it was" "$(git -C "$ORIGIN" rev-parse staging)" "$BASE_SHA"

SELF_URL="https://git.example.com/team/web-app/-/merge_requests/7"
"$LOOP_DIR/bin/loop-state" set EX-4 mr-open repo=web-app branch=feat/ex-3 mr="$SELF_URL"
verdict EX-4 PASS
mr_json "owner:you,needs:human-verify"
python3 -I -c 'import json,sys; m=json.load(open(sys.argv[1])); m["source_branch"]="feat/ex-3"; json.dump(m, open(sys.argv[1],"w"))' "$MR_JSON"
OUT=$(run EX-4)
eq "a self-hosted merge names the merge commit" "$(printf '%s\n' "$OUT" | tail -n 1)" "merged abc123 $SELF_URL"
has "a self-hosted merge sends the head sha" "$(cat "$CALLS")" "--sha $HEAD_SHA"

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
