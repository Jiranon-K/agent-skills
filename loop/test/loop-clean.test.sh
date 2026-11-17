#!/bin/bash
set -u
cd "$(dirname "$0")/../.."
BIN="$(pwd)/loop/bin"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export LOOP_DIR="$TMP/loop" LOOP_STATE="$BIN/loop-state" LOOP_SPEC="$BIN/loop-spec" WT_ROOT="$TMP/worktree"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
CLEAN="$BIN/loop-clean"
MONTH=$(date +%Y-%m)

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
eq()   { [ "$2" = "$3" ] && ok || fail "$1: expected '$3', got '$2'"; }
exists() { [ -e "$2" ] && ok || fail "$1: $2 is missing"; }
gone()   { [ -e "$2" ] && fail "$1: $2 still exists" || ok; }
old() { touch -t 202001010000 "$@"; }

mkdir -p "$LOOP_DIR/specs" "$LOOP_DIR/state" "$LOOP_DIR/logs" "$LOOP_DIR/summaries"
git init -q "$TMP/web-app"
git -C "$TMP/web-app" commit -q --allow-empty -m init
git -C "$TMP/web-app" branch -M staging
echo "web-app $TMP/web-app staging" > "$LOOP_DIR/repos"

package() {
  "$BIN/loop-spec" start "$1" web-app low
  mkdir -p "$LOOP_DIR/designs/$1/candidates/1"
  echo sketch > "$LOOP_DIR/designs/$1/design.md"
  printf -- '---\nstatus: proposed\n---\n\n## Acceptance criteria\n' > "$LOOP_DIR/designs/$1/spec.md"
  "$BIN/loop-spec" done "$1"
}

package EX-1
"$BIN/loop-spec" approve EX-1 >/dev/null
"$BIN/loop-state" set EX-1 merged repo=web-app branch=feat/ex-1
echo body > "$LOOP_DIR/state/mr-draft-EX-1.md"
echo body > "$LOOP_DIR/state/mr-body-EX-1.md"

package EX-2
"$BIN/loop-spec" approve EX-2 >/dev/null
"$BIN/loop-state" set EX-2 working repo=web-app
echo body > "$LOOP_DIR/state/mr-draft-EX-2.md"

package EX-3

"$CLEAN" --dry-run > "$TMP/dry.txt"
exists "a dry run removes nothing" "$LOOP_DIR/specs/EX-1.md"
eq "a dry run says what it would do" "$(grep -c '^would archive' "$TMP/dry.txt")" "2"

"$CLEAN" > "$TMP/out.txt"
gone "a merged task's spec leaves specs" "$LOOP_DIR/specs/EX-1.md"
gone "a merged task's package leaves designs" "$LOOP_DIR/designs/EX-1"
exists "the spec is archived" "$LOOP_DIR/archive/$MONTH/EX-1/EX-1.md"
exists "the design is archived" "$LOOP_DIR/archive/$MONTH/EX-1/EX-1/design.md"
gone "candidates are not archived" "$LOOP_DIR/archive/$MONTH/EX-1/EX-1/candidates"
gone "a merged task's MR draft is removed" "$LOOP_DIR/state/mr-draft-EX-1.md"
gone "a merged task's MR body is removed" "$LOOP_DIR/state/mr-body-EX-1.md"
exists "a fresh merged ticket keeps its state" "$LOOP_DIR/state/tickets/EX-1"

exists "a working task keeps its spec" "$LOOP_DIR/specs/EX-2.md"
exists "a working task keeps its design" "$LOOP_DIR/designs/EX-2/design.md"
exists "a working task keeps its MR draft" "$LOOP_DIR/state/mr-draft-EX-2.md"
gone "an approved design loses its candidates" "$LOOP_DIR/designs/EX-2/candidates"
exists "a proposed design keeps its candidates" "$LOOP_DIR/designs/EX-3/candidates"
eq "the sweep ends with one summary line" "$(tail -n 1 "$TMP/out.txt" | cut -d: -f1)" "cleanup"
eq "a second sweep has nothing to say" "$("$CLEAN")" ""

git -C "$TMP/web-app" branch feat/ex-1
git -C "$TMP/web-app" checkout -q -b feat/ex-4
git -C "$TMP/web-app" commit -q --allow-empty -m unmerged
git -C "$TMP/web-app" checkout -q staging
"$BIN/loop-state" set EX-4 merged repo=web-app branch=feat/ex-4
old "$LOOP_DIR/state/tickets/EX-1" "$LOOP_DIR/state/tickets/EX-4"
"$CLEAN" > "$TMP/out.txt"
gone "an old merged ticket is forgotten" "$LOOP_DIR/state/tickets/EX-1"
eq "its merged branch is deleted" "$(git -C "$TMP/web-app" branch --list feat/ex-1)" ""
eq "a branch git cannot show merged is kept" "$(git -C "$TMP/web-app" branch --list feat/ex-4 | tr -d ' ')" "feat/ex-4"
eq "the kept branch is reported" "$(grep -c '^kept branch feat/ex-4' "$TMP/out.txt")" "1"

"$CLEAN" archive EX-2 EX-3 ../x > "$TMP/out.txt"
exists "a task the Loop still works on is not archived" "$LOOP_DIR/specs/EX-2.md"
gone "a task closed outside the Loop is archived" "$LOOP_DIR/designs/EX-3"
exists "its package is in the archive" "$LOOP_DIR/archive/$MONTH/EX-3/EX-3/spec.md"
eq "a bad key is refused" "$(grep -c '^kept ../x' "$TMP/out.txt")" "1"
"$BIN/loop-spec" start EX-5 web-app low
"$CLEAN" archive EX-5 >/dev/null
exists "a design in progress is not archived" "$LOOP_DIR/designs/EX-5"

echo log > "$LOOP_DIR/logs/2020-01-01.md"
echo log > "$LOOP_DIR/logs/today.md"
echo log > "$LOOP_DIR/logs/launchd.log"
echo sum > "$LOOP_DIR/summaries/2020-01-01.md"
old "$LOOP_DIR/logs/2020-01-01.md" "$LOOP_DIR/logs/launchd.log" "$LOOP_DIR/summaries/2020-01-01.md" "$LOOP_DIR/archive/$MONTH/EX-3"
"$CLEAN" >/dev/null
gone "an old log is removed" "$LOOP_DIR/logs/2020-01-01.md"
gone "an old summary is removed" "$LOOP_DIR/summaries/2020-01-01.md"
exists "a recent log stays" "$LOOP_DIR/logs/today.md"
exists "the launchd log stays" "$LOOP_DIR/logs/launchd.log"
gone "an expired archive entry is removed" "$LOOP_DIR/archive/$MONTH/EX-3"
exists "a recent archive entry stays" "$LOOP_DIR/archive/$MONTH/EX-1"

old "$LOOP_DIR/archive/$MONTH/EX-1"
LOOP_ARCHIVE_DAYS=0 "$CLEAN" >/dev/null
exists "zero days keeps the archive forever" "$LOOP_DIR/archive/$MONTH/EX-1"

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
