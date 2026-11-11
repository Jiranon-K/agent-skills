#!/bin/bash
# Tests for loop/bin/loop-state. Run: loop/test/loop-state.test.sh
set -u
cd "$(dirname "$0")/../.."
LS="$(pwd)/loop/bin/loop-state"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export LOOP_DIR="$TMP/loop" WT_ROOT="$TMP/worktree"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
eq()   { [ "$2" = "$3" ] && ok || fail "$1: expected '$3', got '$2'"; }
errs() { "$LS" "${@:2}" >/dev/null 2>&1 && fail "$1: expected an error" || ok; }

# repo / path
mkdir -p "$LOOP_DIR"
printf 'web-app %s staging\nproject-b-web %s develop\nmain-repo %s main\n' "$TMP/web-app" "$TMP/project-b-web" "$TMP/main" > "$LOOP_DIR/repos"
eq "repo" "$("$LS" repo web-app)" "$TMP/web-app staging"
errs "repo unknown" repo nope
eq "path" "$("$LS" path web-app EX-1)" "$TMP/web-app/.claude/worktrees/EX-1"
errs "path unknown repo" path nope EX-1
errs "path needs two args" path web-app
mkdir -p "$WT_ROOT/web-app-EX-9"
eq "path keeps a legacy worktree" "$("$LS" path web-app EX-9)" "$WT_ROOT/web-app-EX-9"

# set / get
"$LS" set EX-1 working repo=web-app
eq "get status" "$("$LS" get EX-1 status)" "working"
eq "get repo" "$("$LS" get EX-1 repo)" "web-app"
eq "get whole file" "$("$LS" get EX-1)" "status=working
repo=web-app"
"$LS" set EX-1 working ui=yes
"$LS" set EX-1 mr-open branch=feat/x mr=https://example.com/mr/1
eq "set keeps earlier keys" "$("$LS" get EX-1 repo)" "web-app"
eq "set keeps ui" "$("$LS" get EX-1 ui)" "yes"
eq "set adds mr" "$("$LS" get EX-1 mr)" "https://example.com/mr/1"
eq "missing key is empty" "$("$LS" get EX-2 repo 2>/dev/null)" ""
errs "get unknown ticket" get EX-2
errs "unknown status" set EX-1 done
errs "unknown key" set EX-1 working foo=bar
errs "first set needs repo" set EX-3 working
errs "ui must be yes or no" set EX-1 working ui=maybe

# list
"$LS" set EX-4 blocked repo=project-b-web
eq "list all" "$("$LS" list)" "EX-1 status=mr-open repo=web-app branch=feat/x mr=https://example.com/mr/1 ui=yes
EX-4 status=blocked repo=project-b-web"
eq "list by status" "$("$LS" list blocked)" "EX-4 status=blocked repo=project-b-web"
eq "list none" "$("$LS" list working)" ""
errs "list unknown status" list done

# reset: no worktree → only state goes
"$LS" reset EX-4
errs "reset removes state" get EX-4
errs "reset unknown ticket" reset EX-4

# reset with a worktree
git init -q --bare "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/main" 2>/dev/null
git -C "$TMP/main" commit -q --allow-empty -m init
git -C "$TMP/main" push -q origin HEAD 2>/dev/null
mkworktree() {  # $1 = ticket
  "$LS" set "$1" blocked repo=main-repo
  git -C "$TMP/main" worktree add -q --detach "$("$LS" path main-repo "$1")" HEAD
}

mkworktree EX-5
"$LS" reset EX-5
[ -d "$TMP/main/.claude/worktrees/EX-5" ] && fail "reset removes a clean worktree" || ok
errs "reset removes state with worktree" get EX-5

mkworktree EX-6
touch "$TMP/main/.claude/worktrees/EX-6/dirty"
errs "reset refuses uncommitted changes" reset EX-6
[ -d "$TMP/main/.claude/worktrees/EX-6" ] && ok || fail "dirty worktree kept"
eq "dirty keeps state" "$("$LS" get EX-6 status)" "blocked"

mkworktree EX-7
git -C "$TMP/main/.claude/worktrees/EX-7" commit -q --allow-empty -m local
errs "reset refuses unpushed commits" reset EX-7
[ -d "$TMP/main/.claude/worktrees/EX-7" ] && ok || fail "unpushed worktree kept"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
