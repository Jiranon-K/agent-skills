#!/bin/bash
# Tests for scripts/wt-setup. Run: scripts/wt-setup.test.sh
set -u
WS="$(cd "$(dirname "$0")" && pwd)/wt-setup"

TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
eq()   { [ "$2" = "$3" ] && ok || fail "$1: expected '$3', got '$2'"; }

M="$TMP/main"
git init -q "$M"
printf 'tracked\n' > "$M/README"
printf 'lock-1\n' > "$M/yarn.lock"
printf '.env\nnode_modules\n' > "$M/.gitignore"
git -C "$M" add . && git -C "$M" commit -q -m init

mkdir -p "$M/.claude/hooks" "$M/node_modules/pkg" "$M/docs/specs"
printf 'SECRET=1\n' > "$M/.env"
printf '{"hooks":{}}\n' > "$M/.claude/settings.local.json"
printf 'guard\n' > "$M/.claude/hooks/guard.mjs"
printf '# links\n.env\n/.claude/hooks/\ndocs/specs\nmissing-in-main\nREADME\n../escape\n' > "$M/.worktreelinks"
printf '.claude/settings.local.json\n**/*.glob\n' > "$M/.worktreeinclude"
printf '.claude/hooks/\n' >> "$M/.git/info/exclude"

W="$TMP/wt"
git -C "$M" worktree add -q --detach "$W" HEAD

# main checkout is refused; hook mode stays silent there
"$WS" "$M" >/dev/null 2>&1 && fail "main checkout should be refused" || ok
eq "hook silent in main" "$(cd "$M" && "$WS" --hook)" ""
eq "hook silent outside git" "$(cd "$TMP" && "$WS" --hook)" ""

# dry run changes nothing
"$WS" --dry-run "$W" >/dev/null
[ -e "$W/.env" ] && fail "dry run created .env" || ok

out=$("$WS" "$W")
[ -L "$W/.env" ] && [ "$(readlink "$W/.env")" = "$M/.env" ] && ok || fail ".env linked to main"
[ -L "$W/.claude/hooks" ] && ok || fail ".claude/hooks linked"
[ -L "$W/docs/specs" ] && ok || fail "docs/specs linked"
[ -f "$W/.claude/settings.local.json" ] && [ ! -L "$W/.claude/settings.local.json" ] && ok || fail "settings.local.json copied"
[ -L "$W/node_modules" ] && ok || fail "node_modules linked when yarn.lock matches"
[ -L "$W/README" ] && fail "tracked file replaced" || ok
[ -e "$TMP/escape" ] && fail "../ entry followed" || ok
eq "tracked README untouched" "$(cat "$W/README")" "tracked"

# every link is ignored in the worktree
eq "git status clean" "$(git -C "$W" status --porcelain)" ""

# second run is a no-op
eq "idempotent" "$("$WS" "$W")" "nothing to do: $W"

# repair: an identical copy becomes a link, a different one is kept
W2="$TMP/wt2"
git -C "$M" worktree add -q --detach "$W2" HEAD
mkdir -p "$W2/docs"
cp "$M/.env" "$W2/.env"
printf 'mine\n' > "$W2/docs/specs"
printf 'lock-2\n' > "$W2/yarn.lock"
out=$("$WS" "$W2")
[ -L "$W2/.env" ] && ok || fail "identical copy relinked"
eq "different file kept" "$(cat "$W2/docs/specs")" "mine"
case "$out" in *"kept    docs/specs"*) ok ;; *) fail "kept file reported" ;; esac
[ -e "$W2/node_modules" ] && fail "node_modules linked despite different yarn.lock" || ok

# hook mode reports once, then stays silent
W3="$TMP/wt3"
git -C "$M" worktree add -q --detach "$W3" HEAD
case "$(cd "$W3" && "$WS" --hook)" in *"restart this session"*) ok ;; *) fail "hook reports changes" ;; esac
eq "hook silent when complete" "$(cd "$W3" && "$WS" --hook)" ""

echo "wt-setup: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
