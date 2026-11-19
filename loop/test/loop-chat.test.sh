#!/bin/bash
set -u
cd "$(dirname "$0")/../.."
REPO="$(pwd)"

TMP=$(mktemp -d)
SERVER_PID=""
trap '[ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null && wait "$SERVER_PID" 2>/dev/null; rm -rf "$TMP"' EXIT

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
eq()   { [ "$2" = "$3" ] && ok || fail "$1: expected '$3', got '$2'"; }
has()  { case "$2" in *"$3"*) ok ;; *) fail "$1: '$3' not in '$2'" ;; esac; }

LOOP="$TMP/loop"
BIN="$TMP/bin"
export CLAUDE_CONFIG_DIR="$TMP/claude"
mkdir -p "$LOOP/bin" "$LOOP/state" "$BIN" "$CLAUDE_CONFIG_DIR/projects/work" "$TMP/work"
for script in loop-paperclip loop-chat; do ln -s "$REPO/loop/bin/$script" "$LOOP/bin/$script"; done
echo '[]' > "$TMP/sessions.json"
: > "$TMP/calls"

cat > "$BIN/claude" <<SH
#!/bin/bash
echo "\$*" >> "$TMP/calls"
case "\$1" in
  agents) cat "$TMP/sessions.json" ;;
  stop) echo "stopped \$2" ;;
  --bg)
    python3 -I -c 'import json, sys
with open(sys.argv[1], "a") as transcript:
    transcript.write(json.dumps({"type": "user", "message": {"content": sys.argv[2]}}) + "\n")
    transcript.write(json.dumps({"type": "assistant", "message": {"content": [{"type": "text", "text": "answer to: " + sys.argv[2]}]}}) + "\n")' "$CLAUDE_CONFIG_DIR/projects/work/\$3.jsonl" "\$5"
    echo "backgrounded · s1 · loop EX-1" ;;
esac
SH
chmod +x "$BIN/claude"

cat > "$TMP/board.py" <<'PY'
import datetime, json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

store = sys.argv[1]
comments, counter = [], [0]

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, body):
        data = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        issue = self.path.split("/")[3]
        self.reply([one for one in comments if one["issueId"] == issue])

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
        counter[0] += 1
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % counter[0]
        comment = {"id": "c-%d" % counter[0], "issueId": self.path.split("/")[3], "authorType": "user", "createdAt": stamp, "body": body["body"]}
        comments.append(comment)
        json.dump(comments, open(store, "w"), ensure_ascii=False)
        self.reply(comment)

server = HTTPServer(("127.0.0.1", 0), Handler)
print(server.server_address[1], flush=True)
server.serve_forever()
PY

python3 -I "$TMP/board.py" "$TMP/comments.json" > "$TMP/port" &
SERVER_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$TMP/port" ] && break; sleep 0.3; done
PORT=$(cat "$TMP/port")

poll() { LOOP_DIR="$LOOP" PATH="$BIN:$PATH" "$LOOP/bin/loop-chat" poll; }
say() { curl -s -X POST -H "Content-Type: application/json" -d "{\"body\":\"$1\"}" "http://127.0.0.1:$PORT/api/issues/issue-1/comments" > /dev/null; }
bodies() { python3 -I -c 'import json, sys; print(" | ".join(one["body"].replace("\n", " ") for one in json.load(open(sys.argv[1]))))' "$TMP/comments.json"; }
session() { printf '[{"id":"s1","sessionId":"sid-1","name":"loop EX-1","kind":"background","cwd":"%s","startedAt":1,"pid":7,"status":"%s"}]\n' "$TMP/work" "$1" > "$TMP/sessions.json"; }

echo '{"EX-1": {"id": "issue-1", "stage": "working"}}' > "$LOOP/state/paperclip.json"
say "written before the channel existed"
poll
eq "nothing is read before Paperclip is configured" "$(cat "$TMP/calls")" ""

printf 'LOOP_PAPERCLIP_URL="http://127.0.0.1:%s"\nLOOP_PAPERCLIP_COMPANY="co-1"\n' "$PORT" > "$LOOP/config.sh"
poll
eq "a comment older than the channel is not sent" "$(grep -c -- --bg "$TMP/calls")" "0"

sleep 1.1
say "is anyone there"
poll
has "a comment on a task without a session gets told so" "$(bodies)" "ไม่มี session ของงานนี้"
poll
eq "the channel does not answer its own comment" "$(python3 -I -c 'import json, sys; print(len(json.load(open(sys.argv[1]))))' "$TMP/comments.json")" "3"

session busy
say "wait for me"
poll; poll
eq "a busy session is told about once" "$(bodies | grep -o "กำลังทำงานอยู่" | wc -l | tr -d ' ')" "1"
eq "a busy session is not interrupted" "$(grep -c -e stop -e --bg "$TMP/calls")" "0"

session idle
say '`working` → `blocked`'
poll
has "an idle session is stopped before it is woken" "$(cat "$TMP/calls")" "stop s1"
has "the comment reaches the session it belongs to" "$(cat "$TMP/calls")" "--bg --resume sid-1 -- wait for me"
eq "a stage comment from the mirror is not a message" "$(grep -c "working" "$TMP/calls")" "0"
poll
has "the session's answer comes back as a comment" "$(bodies)" "**loop EX-1**  answer to: wait for me"
poll
eq "an answer is posted once" "$(bodies | grep -o "answer to" | wc -l | tr -d ' ')" "1"
eq "a comment is sent once" "$(grep -c -- --bg "$TMP/calls")" "1"

echo "pass $PASS fail $FAIL"
[ "$FAIL" -eq 0 ]
