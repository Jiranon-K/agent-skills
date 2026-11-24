#!/bin/bash
set -u
cd "$(dirname "$0")/../.."
SPEC="$(pwd)/loop/bin/loop-spec"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export LOOP_ORCA=off
export LOOP_DIR="$TMP/loop"

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
eq()   { [ "$2" = "$3" ] && ok || fail "$1: expected '$3', got '$2'"; }
errs() { "$SPEC" "${@:2}" >/dev/null 2>&1 && fail "$1: expected an error" || ok; }

write_package() {
  printf -- '---\ntask: %s\nstatus: proposed\n---\n\n## Acceptance criteria\n\n- it works\n' "$1" > "$LOOP_DIR/designs/$1/spec.md"
  echo "sketch" > "$LOOP_DIR/designs/$1/design.md"
}

eq "unknown task is none" "$("$SPEC" status EX-1)" "none"
errs "bad task key" status ../x
errs "done before start" done EX-1
errs "approve before a design" approve EX-1

"$SPEC" start EX-1 web-app low
eq "start claims the design" "$("$SPEC" status EX-1)" "designing"
errs "start twice" start EX-1 web-app low
eq "list shows meta" "$("$SPEC" list)" "EX-1 designing repo=web-app risk=low"
errs "done without files" done EX-1

write_package EX-1
sed -i '' 's/status: proposed/status: ready/' "$LOOP_DIR/designs/EX-1/spec.md"
errs "done refuses a spec the Designer marked ready" done EX-1
write_package EX-1
"$SPEC" done EX-1
eq "done proposes" "$("$SPEC" status EX-1)" "proposed"
eq "list filters by status" "$("$SPEC" list proposed)" "EX-1 proposed repo=web-app risk=low"
eq "list filters out" "$("$SPEC" list redo)" ""
errs "start a proposed design" start EX-1 web-app low

sleep 1
echo "split the module" | "$SPEC" feedback EX-1
eq "feedback asks for a redo" "$("$SPEC" status EX-1)" "redo"
errs "approve a redo" approve EX-1
errs "empty feedback" feedback EX-1 < /dev/null
"$SPEC" start EX-1 web-app low
sleep 1
"$SPEC" done EX-1
eq "redo done proposes again" "$("$SPEC" status EX-1)" "proposed"

"$SPEC" approve EX-1 >/dev/null
eq "approve marks ready" "$("$SPEC" status EX-1)" "approved"
eq "approved spec is ready" "$(grep -c '^status: ready$' "$LOOP_DIR/specs/EX-1.md")" "1"
eq "approved spec is dated" "$(grep -c "^approved: $(date +%F)\$" "$LOOP_DIR/specs/EX-1.md")" "1"
eq "package keeps proposed" "$(grep -c '^status: proposed$' "$LOOP_DIR/designs/EX-1/spec.md")" "1"
errs "start an approved design" start EX-1 web-app low

sleep 1
echo "the sketch cannot absorb the cache" | "$SPEC" feedback EX-1
eq "worker scrap demotes an approved spec" "$("$SPEC" status EX-1)" "redo"

"$SPEC" start EX-2 web-app high
"$SPEC" block EX-2 "needs the copy from product"
eq "block" "$("$SPEC" status EX-2)" "blocked"
"$SPEC" start EX-2 web-app high
eq "a blocked design can restart" "$("$SPEC" status EX-2)" "designing"

"$SPEC" start EX-3 web-app low
LOOP_DESIGN_STALE_MINUTES=0 "$SPEC" status EX-3 >/dev/null
touch -t 202001010000 "$LOOP_DIR/designs/EX-3/.designing"
eq "a stale claim is released" "$("$SPEC" status EX-3)" "none"
"$SPEC" start EX-3 web-app low
eq "a stale claim can restart" "$("$SPEC" status EX-3)" "designing"

"$SPEC" log EX-4 sketch "picked candidate B" "smaller	surface" "design.md" "=open"
eq "log writes a header" "$(head -n 1 "$LOOP_DIR/designs/EX-4/decisions.tsv")" "ts	phase	decision	why	evidence	result"
eq "log strips tabs and guards formulas" "$(tail -n 1 "$LOOP_DIR/designs/EX-4/decisions.tsv" | cut -f2-)" "sketch	picked candidate B	smaller surface	design.md	'=open"
errs "log needs six arguments" log EX-4 sketch only

"$SPEC" start EX-6 web-app,api high
write_package EX-6
errs "done needs a part per repo" done EX-6
mkdir -p "$LOOP_DIR/designs/EX-6/parts"
for repo in web-app api; do cp "$LOOP_DIR/designs/EX-6/spec.md" "$LOOP_DIR/designs/EX-6/parts/$repo.md"; done
"$SPEC" done EX-6
eq "a design over several repos is proposed" "$("$SPEC" status EX-6)" "proposed"
errs "a design over several repos is not approved whole" approve EX-6
errs "a part needs a repo of the design" part EX-6 other EX-7
errs "a part needs its own task" part EX-6 api EX-6
"$SPEC" part EX-6 api EX-7 >/dev/null
eq "a handed-out part is a ready spec" "$("$SPEC" status EX-7)" "approved"
eq "the part carries its own task key" "$(grep -c '^task: EX-7$' "$LOOP_DIR/specs/EX-7.md")" "1"
eq "the parent design is split" "$("$SPEC" status EX-6)" "split"
errs "a split design is not designed again" start EX-6 web-app,api high
"$SPEC" part EX-6 web-app EX-8 >/dev/null
eq "the second part is handed out from a split design" "$("$SPEC" status EX-8)" "approved"

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
