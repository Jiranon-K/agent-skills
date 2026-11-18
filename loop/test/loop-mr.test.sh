#!/bin/bash
set -u
cd "$(dirname "$0")/../.."
REPO="$(pwd)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export LOOP_DIR="$TMP/loop"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
eq()   { [ "$2" = "$3" ] && ok || fail "$1: expected '$3', got '$2'"; }
has()  { grep -qF -- "$3" "$2" 2>/dev/null && ok || fail "$1: '$3' not in $2"; }

mkdir -p "$LOOP_DIR/bin" "$LOOP_DIR/state" "$TMP/bin"
ln -s "$REPO/loop/bin/loop-state" "$LOOP_DIR/bin/loop-state"
MR="$REPO/loop/bin/loop-mr"
BODY="$LOOP_DIR/state/mr-body-EX-1.md"
CALLS="$TMP/glab-calls"
export CALLS MR_JSON="$TMP/mr.json"

git init -q "$TMP/web-app"
git -C "$TMP/web-app" commit -q --allow-empty -m init
git -C "$TMP/web-app" branch -M staging
git -C "$TMP/web-app" switch -q -c loop/ex-1
echo "web-app $TMP/web-app staging repo:web-app" > "$LOOP_DIR/repos"
printf 'LOOP_MR_LABELS="owner:you,needs:human-verify"\nLOOP_GLAB_REPO_web_app="git.example.com/team/web-app"\n' > "$LOOP_DIR/config.sh"
"$LOOP_DIR/bin/loop-state" set EX-1 working repo=web-app branch=loop/ex-1

cat > "$TMP/bin/glab" <<'GLAB'
#!/bin/bash
case "$1 $2" in
  "mr view") cat "$MR_JSON" 2>/dev/null || exit 1 ;;
  "mr create"|"mr update")
    printf '%s\n' "$*" >> "$CALLS"
    labels=""
    while [ $# -gt 0 ]; do [ "$1" = "--label" ] && labels="$2"; shift; done
    python3 -I -c 'import json,sys; print(json.dumps({"iid": 7, "state": "opened", "draft": True, "labels": sys.argv[1].split(","), "web_url": "https://git.example.com/mr/7"}))' "$labels" > "$MR_JSON" ;;
esac
GLAB
chmod +x "$TMP/bin/glab"
export PATH="$TMP/bin:$PATH"

run() { (cd "$TMP/web-app" && "$MR" "$@" 2>&1); }
write_body() {
  printf '%s\n' '# feat(x): add the thing' '' '## Summary' '' 'Adds the thing.' '' '```diff' '+ thing' '```' '' \
    '## Evidence' '' '- **Before:** 1 failed' '  **After:** 9 passed' '' \
    '## Merge Danger' '' '**Door:** two-way' '' '**Blast Radius:** small' > "$BODY"
}
refused() {
  run EX-1 >/dev/null && fail "$1: expected a refusal" || ok
  [ -e "$CALLS" ] && fail "$1: glab was called" || ok
}

run EX-1 >/dev/null && fail "a missing body is refused" || ok
echo 'Full description follows in the next update.' > "$BODY"
refused "a one-line body"
write_body; sed -i '' '/^```/d' "$BODY"
refused "a summary without a diagram"
write_body; sed -i '' '/Before/d' "$BODY"
refused "evidence without a before"
write_body; sed -i '' 's/two-way/maybe/' "$BODY"
refused "a door that is neither one-way nor two-way"
write_body; sed -i '' 's/^## Evidence$/## Verification/' "$BODY"
refused "a renamed section"

write_body
eq "a full body opens the MR and prints its link" "$(run EX-1)" "https://git.example.com/mr/7"
has "the MR is created as a Draft" "$CALLS" "mr create -R git.example.com/team/web-app --draft"
has "the MR targets the repo's base branch" "$CALLS" "--source-branch loop/ex-1 --target-branch staging"
has "the title comes from line 1" "$CALLS" "--title feat(x): add the thing"
has "the labels come from the config" "$CALLS" "--label owner:you,needs:human-verify"
grep -q '^# feat' "$CALLS" && fail "the title line stays out of the description" || ok

run EX-1 e2e >/dev/null
has "a second run updates the same MR" "$CALLS" "mr update 7 -R git.example.com/team/web-app --draft"
has "e2e adds its label" "$CALLS" "--label owner:you,needs:human-verify,needs:e2e"

git -C "$TMP/web-app" switch -q staging
run EX-1 >/dev/null && fail "the base branch is refused" || ok

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
