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
lacks() { grep -qF -- "$3" "$2" 2>/dev/null && fail "$1: '$3' is in $2" || ok; }

mkdir -p "$LOOP_DIR/bin" "$LOOP_DIR/state" "$TMP/bin" "$TMP/shots"
ln -s "$REPO/loop/bin/loop-state" "$LOOP_DIR/bin/loop-state"
UPLOAD="$REPO/loop/bin/loop-upload"
export CALLS="$TMP/curl-calls" STDIN="$TMP/curl-stdin" TOKEN_FILE="$TMP/token" REPLY="$TMP/reply"

git init -q "$TMP/web-app"
git -C "$TMP/web-app" remote add origin git@git.example.com:team/web-app.git
git init -q "$TMP/project-b-web"
git -C "$TMP/project-b-web" remote add origin ssh://git@10.0.0.1:2222/project-b/project-b-web.git
printf '%s\n' "web-app $TMP/web-app staging repo:web-app" "project-b-web $TMP/project-b-web develop repo:project-b-web" > "$LOOP_DIR/repos"
echo 'LOOP_GLAB_REPO_project_b_web="git.other.example/project-b/project-b-web"' > "$LOOP_DIR/config.sh"
"$LOOP_DIR/bin/loop-state" set EX-1 working repo=web-app branch=loop/ex-1
"$LOOP_DIR/bin/loop-state" set EX-2 working repo=project-b-web branch=loop/ex-2

cat > "$TMP/bin/glab" <<'GLAB'
#!/bin/bash
[ "$1 $2 $3" = "config get token" ] && cat "$TOKEN_FILE" 2>/dev/null
GLAB
cat > "$TMP/bin/curl" <<'CURL'
#!/bin/bash
printf '%s\n' "$*" >> "$CALLS"
cat > "$STDIN"
name=""
for arg in "$@"; do
  case "$arg" in file=@*) name=$(basename "${arg#file=@}") ;; esac
done
if [ -f "$REPLY" ]; then cat "$REPLY"; else printf '{"markdown": "![%s](/uploads/abc/%s)"}' "${name%.*}" "$name"; fi
CURL
chmod +x "$TMP/bin/glab" "$TMP/bin/curl"
export PATH="$TMP/bin:$PATH"

echo secret-token > "$TOKEN_FILE"
touch "$TMP/shots/one.png" "$TMP/shots/two.png"
run() { (cd "$TMP" && "$UPLOAD" "$@" 2>&1); }

eq "each file prints its markdown line" "$(run EX-1 "$TMP/shots/one.png" "$TMP/shots/two.png")" "![one](/uploads/abc/one.png)
![two](/uploads/abc/two.png)"
has "the project comes from the origin remote" "$CALLS" "https://git.example.com/api/v4/projects/team%2Fweb-app/uploads"
has "the file goes as a multipart form" "$CALLS" "--form file=@$TMP/shots/one.png"
has "the token goes in on stdin" "$STDIN" "Authorization: Bearer secret-token"
lacks "the token stays out of the arguments" "$CALLS" "secret-token"

run EX-2 "$TMP/shots/one.png" >/dev/null
has "a configured host wins over the remote" "$CALLS" "https://git.other.example/api/v4/projects/project-b%2Fproject-b-web/uploads"

rm -f "$CALLS"
run EX-1 "$TMP/shots/missing.png" >/dev/null && fail "a missing file is refused" || ok
[ -e "$CALLS" ] && fail "a missing file reaches curl" || ok
run EX-9 "$TMP/shots/one.png" >/dev/null && fail "a task without loop-state is refused" || ok
run EX-1 >/dev/null && fail "a call without files is refused" || ok

echo '{"message": "401 Unauthorized"}' > "$REPLY"
OUT=$(run EX-1 "$TMP/shots/one.png") && fail "a refused upload fails" || ok
case "$OUT" in *"401 Unauthorized"*) ok ;; *) fail "a refused upload shows GitLab's answer: $OUT" ;; esac
rm -f "$REPLY"

: > "$TOKEN_FILE"
rm -f "$CALLS"
run EX-1 "$TMP/shots/one.png" >/dev/null && fail "a missing token is refused" || ok
[ -e "$CALLS" ] && fail "a missing token reaches curl" || ok

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
