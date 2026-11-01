#!/bin/bash
# Writes per-day markdown digests of Claude Code session transcripts to
# $STANDUP_OUT_DIR/sessions/YYYY-MM-DD/<project>__<session>.md
#
#   session-digest.sh <transcript.jsonl>...   digest the given transcripts
#   session-digest.sh --hook                  read a hook payload on stdin, digest its transcript in the background
#   session-digest.sh --sweep                 digest every transcript changed since the last standup run
#
# A digest is never removed or shrunk here: it has to outlive the transcript,
# which the user (or Claude Code's own cleanup) may delete at any time.

set -u
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

OUT_ROOT="${STANDUP_OUT_DIR:-$HOME/Documents/work/standups}"
OUT="$OUT_ROOT/sessions"
PROJECTS="$HOME/.claude/projects"
MAX_CHARS=2000

log_error() {
  mkdir -p "$OUT"
  printf '%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >> "$OUT/.errors.log"
}

# Transcript line -> one compact record per human/assistant message.
# Days are cut in Asia/Bangkok (UTC+7) because transcript timestamps are UTC.
read -r -d '' NORMALIZE <<'JQ'
def redact:
  gsub("-----BEGIN [A-Z ]*PRIVATE KEY-----[\\s\\S]*?-----END [A-Z ]*PRIVATE KEY-----"; "[REDACTED]")
  | gsub("https://discord(app)?\\.com/api/webhooks/[^\\s\"')]+"; "[REDACTED]")
  | gsub("\\b(sk|pk|rk)[-_][A-Za-z0-9_-]{20,}"; "[REDACTED]")
  | gsub("\\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|xox[abprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,})"; "[REDACTED]")
  | gsub("eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}"; "[REDACTED]")
  | gsub("(?<k>(?i:bearer|basic))\\s+[A-Za-z0-9._~+/=-]{16,}"; "\(.k) [REDACTED]")
  | gsub("(?<k>(?i:api[_-]?key|secret|token|password|passwd|pwd)[A-Za-z0-9_]*[\"']?\\s*[:=]\\s*[\"']?)(?=[A-Za-z0-9_./+=-]*[0-9])[A-Za-z0-9_./+=-]{12,}"; "\(.k)[REDACTED]");

def clip: if length > $max then .[0:$max] + " …[truncated \(length - $max) chars]" else . end;

def slash_command:
  if test("<command-name>") then
    (capture("<command-name>(?<n>[^<]*)</command-name>").n)
    + " " + ((capture("<command-args>(?<a>[\\s\\S]*?)</command-args>")? | .a) // "")
  elif test("^\\s*<bash-input>") then
    "! " + (capture("<bash-input>(?<c>[\\s\\S]*?)</bash-input>").c)
  else . end;

def human_text:
  .message.content
  | if type == "string" then .
    else [ .[] | if .type == "text" then .text elif .type == "image" then "[image]" else empty end ] | join("\n")
    end;

def record($role; $text):
  (.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 + 25200) as $local
  | { k: "msg", n: input_line_number, uuid, role: $role,
      date: ($local | strftime("%Y-%m-%d")), time: ($local | strftime("%H:%M")),
      cwd, branch: (.gitBranch // ""), text: ($text | redact | clip) };

fromjson?
| if .type == "custom-title" then { k: "title", v: .customTitle }
  elif .isSidechain == true or .isMeta == true or (.timestamp | not) then empty
  elif .type == "user" and (.message.content | type) == "string"
       and (.message.content | test("^\\s*<scheduled-task name=\"daily-standup\"")) then { k: "skip" }
  elif .type == "user" and .origin.kind? == "human" then
    (human_text) as $t
    | if ($t | test("^\\s*<(scheduled-task|system-reminder)")) or ($t | test("^\\s*$")) then empty
      else record("User"; $t | slash_command) end
  elif .type == "assistant" and .isApiErrorMessage != true then
    ([ .message.content[]? | select(.type == "text") | .text ] | join("\n\n")) as $t
    | if ($t | test("^\\s*$")) then empty else record("Claude"; $t) end
  else empty end
JQ

# Records of one session + one day -> markdown. Messages already written to
# another digest of that day ($seen) are skipped: resuming or forking a session
# copies its history into a new transcript with the same message uuids.
read -r -d '' RENDER <<'JQ'
def project: sub("/\\.claude/worktrees/.*$"; "") | split("/") | last | ltrimstr(".");

($seen | split("\n") | map(select(length > 0) | { (.): true }) | add // {}) as $skip
| ([ .[] | select(.k == "title") | .v ] | last // "(untitled session)") as $title
| ([ .[] | select(.k == "msg") ] | unique_by(.uuid) | sort_by(.n)) as $all
| [ $all[] | select(.date == $date and ($skip[.uuid] | not)) ] as $day
| if ($day | length) == 0 then empty else
    ([ $all[] | select(.role == "User") ] | first) as $first
    | {
        name: (($day[0].cwd // "unknown" | project | gsub("[^A-Za-z0-9._-]"; "-")) + "__" + $sid[0:8]),
        uuids: [ $day[].uuid ],
        md: (
          [ "# \($title)", "",
            "- Date: \($date) (\($day[0].time)–\($day[-1].time))",
            "- Project: \($day[0].cwd // "unknown" | project) — \($day[0].cwd // "unknown")",
            "- Branch: \([ $day[].branch | select(length > 0) ] | unique | join(", "))",
            "- Session: \($sid)" ]
          + ( if $first != null and ([ $day[].uuid ] | index($first.uuid) | not) then
                [ "- Continues earlier work. First prompt (\($first.date) \($first.time)): \($first.text[0:300] | gsub("\\s+"; " "))" ]
              else [] end )
          + ( reduce $day[] as $m ([];
                if length > 0 and .[-1].role == $m.role then .[-1].text += "\n\n" + $m.text
                else . + [ $m ] end)
              | map("", "### \(.time) \(.role)", "", .text) )
          | join("\n")
        )
      }
  end
JQ

digest_file() {
  local src="$1" sid norm errf dates d rendered name daydir dest tmp
  [ -f "$src" ] || return 0
  sid="$(basename "$src" .jsonl)"
  norm="$(mktemp)"; errf="$(mktemp)"

  if ! jq -cR --argjson max "$MAX_CHARS" "$NORMALIZE" "$src" > "$norm" 2> "$errf"; then
    log_error "$src" "normalize: $(tr '\n' ' ' < "$errf")"
    rm -f "$norm" "$errf"; return 1
  fi
  if grep -q '^{"k":"skip"}$' "$norm"; then rm -f "$norm" "$errf"; return 0; fi

  dates="$(jq -r 'select(.k == "msg") | .date' "$norm" | sort -u)"
  for d in $dates; do
    daydir="$OUT/$d"
    mkdir -p "$daydir"
    touch "$daydir/.seen"
    # .seen maps message uuid -> digest that owns it; own entries are recomputed.
    rendered="$(jq -cs --arg date "$d" --arg sid "$sid" \
      --rawfile seen <(awk -F'\t' -v sid="$sid" '$2 !~ ("__" substr(sid, 1, 8) "$") { print $1 }' "$daydir/.seen") \
      "$RENDER" "$norm" 2> "$errf")" || { log_error "$src" "render $d: $(tr '\n' ' ' < "$errf")"; continue; }
    [ -n "$rendered" ] || continue

    name="$(jq -r '.name' <<< "$rendered")"
    dest="$daydir/$name.md"
    tmp="$(mktemp "$daydir/.tmp.XXXXXX")"
    jq -r '.md' <<< "$rendered" > "$tmp"
    if [ -f "$dest" ] && [ "$(grep -c '^### ' "$tmp")" -lt "$(grep -c '^### ' "$dest")" ]; then
      rm -f "$tmp"; continue
    fi
    mv "$tmp" "$dest"

    tmp="$(mktemp "$daydir/.tmp.XXXXXX")"
    { awk -F'\t' -v o="$name" '$2 != o' "$daydir/.seen"
      jq -r --arg o "$name" '.uuids[] | "\(.)\t\($o)"' <<< "$rendered"; } > "$tmp"
    mv "$tmp" "$daydir/.seen"
  done
  rm -f "$norm" "$errf"
}

case "${1:-}" in
  --hook)
    src="$(jq -r '.transcript_path // empty' 2>/dev/null)"
    [ -n "$src" ] && nohup "$0" "$src" > /dev/null 2>&1 &
    exit 0
    ;;
  --sweep)
    if [ -f "$OUT_ROOT/.last-run" ]; then newer=(-newer "$OUT_ROOT/.last-run"); else newer=(-mtime -2); fi
    # Oldest first, so an original session owns its messages before a fork of it.
    find "$PROJECTS" -mindepth 2 -maxdepth 2 -name '*.jsonl' "${newer[@]}" -exec stat -f '%m %N' {} + 2>/dev/null \
      | sort -n | cut -d' ' -f2- | while IFS= read -r f; do digest_file "$f"; done
    ;;
  "")
    echo "usage: $(basename "$0") <transcript.jsonl>... | --hook | --sweep" >&2
    exit 2
    ;;
  *)
    for f in "$@"; do digest_file "$f"; done
    ;;
esac
