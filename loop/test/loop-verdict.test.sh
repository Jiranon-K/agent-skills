#!/bin/bash
set -u
cd "$(dirname "$0")/../.."
REPO="$(pwd)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export LOOP_ORCA=off
export LOOP_DIR="$TMP/loop"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
eq()   { [ "$2" = "$3" ] && ok || fail "$1: expected '$3', got '$2'"; }
has()  { case "$2" in *"$3"*) ok ;; *) fail "$1: '$3' not in '$2'" ;; esac; }

mkdir -p "$LOOP_DIR/bin" "$TMP/bin"
ln -s "$REPO/loop/bin/loop-state" "$LOOP_DIR/bin/loop-state"
VERDICT="$REPO/loop/bin/loop-verdict"
STATE="$LOOP_DIR/bin/loop-state"
ORIGIN="$TMP/origin.git"
MAIN="$TMP/web-app"
WORKTREE="$MAIN/.claude/worktrees/EX-1"
URL="https://gitlab.com/team/web-app/-/merge_requests/7"
export CALLS="$TMP/glab-calls"

cat > "$TMP/bin/glab" <<'GLAB'
#!/bin/bash
echo "$*" >> "$CALLS"
GLAB
chmod +x "$TMP/bin/glab"
export PATH="$TMP/bin:$PATH"

git init -q --bare "$ORIGIN"
git init -q "$MAIN"
git -C "$MAIN" remote add origin "$ORIGIN"
echo one > "$MAIN/a.txt"
git -C "$MAIN" add a.txt
git -C "$MAIN" commit -q -m init
git -C "$MAIN" branch -M staging
git -C "$MAIN" push -q origin staging
git -C "$MAIN" worktree add -q -b feat/ex-1 "$WORKTREE" staging
echo two > "$WORKTREE/b.txt"
git -C "$WORKTREE" add b.txt
git -C "$WORKTREE" commit -q -m "wip one"

echo "web-app $MAIN staging repo:web-app" > "$LOOP_DIR/repos"
echo "checked" > "$TMP/notes"
"$STATE" set EX-1 working repo=web-app branch=feat/ex-1

calls() { [ -f "$CALLS" ] && cat "$CALLS"; }
push() { git -C "$WORKTREE" push -q origin feat/ex-1; }

echo dirty > "$WORKTREE/c.txt"
"$VERDICT" EX-1 PASS "$TMP/notes" >/dev/null 2>&1 && fail "uncommitted changes are refused" || ok
rm "$WORKTREE/c.txt"

OUT=$("$VERDICT" EX-1 FAIL "$TMP/notes" 2>"$TMP/err")
eq "a verdict is recorded on an unpushed worktree" "${OUT%% *}" "FAIL"
has "it says how to post it later" "$(cat "$TMP/err")" "loop-verdict EX-1 post"
eq "nothing is posted without an MR" "$(calls)" ""
eq "nothing was pushed" "$(git -C "$ORIGIN" branch --list feat/ex-1)" ""
"$VERDICT" EX-1 check >/dev/null 2>&1 && fail "check needs the pushed branch" || ok

echo three >> "$WORKTREE/b.txt"
git -C "$WORKTREE" commit -q -am "fix"
"$VERDICT" EX-1 PASS "$TMP/notes" >/dev/null 2>&1
"$VERDICT" EX-1 post "$TMP/notes" >/dev/null 2>&1 && fail "post needs the pushed branch" || ok
push
eq "the push of the judged commits keeps the verdict" "$("$VERDICT" EX-1 check)" "current PASS"

"$VERDICT" EX-1 post "$TMP/notes" >/dev/null 2>&1 && fail "post needs an MR" || ok
"$STATE" set EX-1 mr-open "mr=$URL"
has "post puts the recorded verdict on the MR" "$("$VERDICT" EX-1 post "$TMP/notes")" "posted PASS"
has "the note names the verdict" "$(calls)" "mr note create 7 -R gitlab.com/team/web-app --resolvable=false -m **Loop verdict: PASS**"

echo four >> "$WORKTREE/b.txt"
git -C "$WORKTREE" commit -q -am "follow-up"
rm -f "$CALLS"
"$VERDICT" EX-1 PASS "$TMP/notes" >/dev/null 2>&1
has "with an MR the verdict is posted when recorded" "$(calls)" "**Loop verdict: PASS**"
eq "an unpushed follow-up leaves the pushed patch stale" "$("$VERDICT" EX-1 check)" "stale PASS"
"$VERDICT" EX-1 post "$TMP/notes" >/dev/null 2>&1 && fail "post refuses a pushed patch the verdict does not cover" || ok
push
eq "pushing the follow-up makes it current" "$("$VERDICT" EX-1 check)" "current PASS"

git -C "$MAIN" worktree remove --force "$WORKTREE"
echo five >> "$MAIN/a.txt"
git -C "$MAIN" commit -q -am "base moves"
git -C "$MAIN" push -q origin staging
OUT=$("$VERDICT" EX-1 PASS+NOTES "$TMP/notes" 2>/dev/null)
eq "without a worktree the pushed branch is judged" "${OUT%% *}" "PASS+NOTES"
eq "and it is current" "$("$VERDICT" EX-1 check)" "current PASS+NOTES"

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
