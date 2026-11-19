#!/bin/bash
set -u
cd "$(dirname "$0")/../.."
REPO="$(pwd)"

TMP=$(mktemp -d)
SERVER_PID=""
trap '[ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null; rm -rf "$TMP"' EXIT

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
eq()   { [ "$2" = "$3" ] && ok || fail "$1: expected '$3', got '$2'"; }
has()  { case "$2" in *"$3"*) ok ;; *) fail "$1: '$3' not in '$2'" ;; esac; }

LOOP="$TMP/loop"
mkdir -p "$LOOP/bin" "$LOOP/specs" "$LOOP/designs"
for script in loop-state loop-spec loop-paperclip; do ln -s "$REPO/loop/bin/$script" "$LOOP/bin/$script"; done
echo "web-app $TMP/web-app staging repo:web-app" > "$LOOP/repos"

cat > "$TMP/board.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

store = sys.argv[1]
issues, labels, counter = {}, {}, [0]

def save():
    json.dump({"issues": issues, "labels": labels}, open(store, "w"), ensure_ascii=False)

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def body(self):
        return json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")

    def do_GET(self):
        if self.path.endswith("/issues"):
            return self.reply(200, [issue for issue in issues.values() if not issue.get("hiddenAt")])
        if self.path.endswith("/labels"):
            return self.reply(200, list(labels.values()))
        key = self.path.rsplit("/", 1)[1]
        if key not in issues:
            return self.reply(404, {"error": "Issue not found"})
        self.reply(200, issues[key])

    def do_POST(self):
        body = self.body()
        counter[0] += 1
        key = "id-%d" % counter[0]
        if self.path.endswith("/labels"):
            labels[key] = {"id": key, **body}
        else:
            issues[key] = {"id": key, "comments": [], **body}
        save()
        self.reply(201, {"id": key})

    def do_PATCH(self):
        key = self.path.rsplit("/", 1)[1]
        body = self.body()
        if "comment" in body:
            issues[key]["comments"].append(body.pop("comment"))
        issues[key].update(body)
        issues[key]["patches"] = issues[key].get("patches", 0) + 1
        save()
        self.reply(200, issues[key])

    def do_DELETE(self):
        issues.pop(self.path.rsplit("/", 1)[1], None)
        save()
        self.reply(200, {})

server = HTTPServer(("127.0.0.1", 0), Handler)
print(server.server_address[1], flush=True)
server.serve_forever()
PY

python3 -I "$TMP/board.py" "$TMP/store.json" > "$TMP/port" &
SERVER_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$TMP/port" ] && break; sleep 0.3; done
PORT=$(cat "$TMP/port")

state() { LOOP_DIR="$LOOP" "$LOOP/bin/loop-state" "$@"; }
spec() { LOOP_DIR="$LOOP" "$LOOP/bin/loop-spec" "$@"; }
sync() { LOOP_DIR="$LOOP" "$LOOP/bin/loop-paperclip" sync; }
card() {
  python3 -I -c 'import json, sys
store = json.load(open(sys.argv[1]))
names = {label["id"]: label["name"] for label in store["labels"].values()}
for issue in store["issues"].values():
    if (issue["title"] + " ").startswith(sys.argv[2] + " "):
        print({"status": issue["status"], "title": issue["title"], "body": issue["description"],
               "labels": " ".join(sorted(names[i] for i in issue["labelIds"])),
               "comments": " | ".join(issue["comments"]), "patches": str(issue.get("patches", 0)),
               "owner": issue["assigneeUserId"]}[sys.argv[3]])' "$TMP/store.json" "$1" "$2"
}
count() { python3 -I -c 'import json, sys; print(len(json.load(open(sys.argv[1]))["issues"]))' "$TMP/store.json"; }

printf -- '---\ntask: EX-1\nrepo: web-app\nrisk: low\nstatus: ready\n---\n\n# Fix the login button\n' > "$LOOP/specs/EX-1.md"
state set EX-2 mr-open repo=web-app branch=fix/EX-2 mr=https://git.example.com/web-app/-/merge_requests/7 ui=yes

sync
[ -e "$TMP/store.json" ] && fail "nothing is sent before Paperclip is configured" || ok

printf 'LOOP_PAPERCLIP_URL="http://127.0.0.1:%s"\nLOOP_PAPERCLIP_COMPANY="co-1"\nLOOP_TASK_URL="https://workspace.example.com/tasks"\n' "$PORT" > "$LOOP/config.sh"
sync
eq "each Loop task becomes one issue" "$(count)" "2"
eq "an approved spec waits for a Worker" "$(card EX-1 status)" "todo"
eq "the title is the task key and the spec heading" "$(card EX-1 title)" "EX-1 Fix the login button"
eq "labels carry stage, repo and risk" "$(card EX-1 labels)" "repo:web-app risk:low wait:worker"
eq "an open MR waits for the owner" "$(card EX-2 status)" "in_review"
has "the card says what the owner runs next" "$(card EX-2 body)" '/merge-approved EX-2'
has "the card links the Workspace task" "$(card EX-2 body)" "[EX-2](https://workspace.example.com/tasks/EX-2)"
has "the card links the MR" "$(card EX-2 body)" "merge_requests/7"
eq "every card belongs to the board owner" "$(card EX-2 owner)" "local-board"

sync
eq "a sync with nothing new sends no update" "$(card EX-2 patches)" "0"

state set EX-1 working repo=web-app branch=loop/ex-1
sync
eq "a started Worker moves the card" "$(card EX-1 status)" "in_progress"
eq "a stage change is one comment" "$(card EX-1 comments)" '`wait:worker` → `working`'
eq "the task keeps its one issue" "$(count)" "2"

python3 -I -c 'import json, sys, urllib.request
store = json.load(open(sys.argv[1]))
key = next(k for k, v in store["issues"].items() if (v["title"] + " ").startswith("EX-2 "))
urllib.request.urlopen(urllib.request.Request("http://127.0.0.1:%s/api/issues/%s" % (sys.argv[2], key), data=json.dumps({"status": "done"}).encode(), method="PATCH"))' "$TMP/store.json" "$PORT"
sync
eq "a card moved by hand is put back" "$(card EX-2 status)" "in_review"

python3 -I -c 'import json, sys, urllib.request
store = json.load(open(sys.argv[1]))
key = next(k for k, v in store["issues"].items() if (v["title"] + " ").startswith("EX-2 "))
urllib.request.urlopen(urllib.request.Request("http://127.0.0.1:%s/api/issues/%s" % (sys.argv[2], key), data=json.dumps({"hiddenAt": "2026-01-01T00:00:00Z"}).encode(), method="PATCH"))' "$TMP/store.json" "$PORT"
sync
eq "a card hidden by hand is shown again" "$(python3 -I -c 'import json, sys; print([v.get("hiddenAt") for v in json.load(open(sys.argv[1]))["issues"].values() if (v["title"] + " ").startswith("EX-2 ")])' "$TMP/store.json")" "[None]"
eq "a hidden card is not created twice" "$(count)" "2"

state set EX-2 merged
mkdir -p "$LOOP/archive/2026-01/EX-2"
printf -- '---\ntask: EX-2\nrepo: web-app\n---\n\n# EX-2: Warn before leaving the form\n' > "$LOOP/archive/2026-01/EX-2/EX-2.md"
sync
eq "a merged task is done" "$(card EX-2 status)" "done"
eq "an archived spec still names its card, key written once" "$(card EX-2 title)" "EX-2 Warn before leaving the form"
rm "$LOOP/state/tickets/EX-2"
sync
eq "an archived task leaves the board" "$(count)" "1"

kill "$SERVER_PID"; wait "$SERVER_PID" 2>/dev/null; SERVER_PID=""
state set EX-1 blocked
sync; eq "a sync that cannot reach Paperclip still succeeds" "$?" "0"
has "the failure is one line in the log" "$(cat "$LOOP"/logs/*.md)" "paperclip sync failed"

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
