#!/bin/bash
# Loop Engineering runner. launchd (com.example.loop) calls this daily at 9:15.
# One run: Coordinator (triage + labels + pick) → if a ticket is picked and nothing is in progress:
#   Worker build → Reviewer (read-only) → Worker finish (fix findings + deliver).
# Manual run outside working hours: FORCE=1 ~/loop/bin/loop-run.sh
# Triage only (no Worker):          TRIAGE_ONLY=1 ~/loop/bin/loop-run.sh
set -u

LOOP_DIR="$HOME/loop"
STATE="$LOOP_DIR/bin/loop-state"   # owns ticket state and worktree paths
# launchd has no user PATH; claude is a native install, glab/git/node come from Homebrew.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

TODAY=$(date +%F)
NOW=$(date +%H:%M)
LOG="$LOOP_DIR/logs/$TODAY.md"
LAST="$LOOP_DIR/state/last-triage.md"
LOCK="$LOOP_DIR/state/run.lock"
mkdir -p "$LOOP_DIR/logs" "$LOOP_DIR/state"

notify() {
  osascript -e "display notification \"$1\" with title \"Loop\"" >/dev/null 2>&1
}
log() { printf '%s\n' "$@" >> "$LOG"; }

# launchd replays a missed run on wake, which may land outside working hours.
HOUR=$((10#$(date +%H)))
if [ "${FORCE:-0}" != "1" ] && { [ "$HOUR" -lt 9 ] || [ "$HOUR" -gt 18 ]; }; then
  exit 0
fi

# One run at a time. A Worker run can take a while, so a lock is stale only after 4 hours.
if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +240)" ]; then
  rmdir "$LOCK"
fi
if ! mkdir "$LOCK" 2>/dev/null; then
  log "## $NOW skipped — previous run still active"
  exit 0
fi

# This run's part of the log starts here; summarize() reads it back.
RUN_START=1
[ -f "$LOG" ] && RUN_START=$(( $(wc -l < "$LOG") + 1 ))
DID=0   # set to 1 when the run changed something or failed, so a summary is worth writing

# Summary session: turns this run's log into a short Thai digest with a link to every place acted on.
summarize() {
  local section summary
  section=$(tail -n +"$RUN_START" "$LOG")
  summary=$(cd "$LOOP_DIR" && claude -p "สรุปผลการรันรอบนี้ของ Loop Engineering ให้เจ้าของงานอ่าน โดยใช้เฉพาะข้อมูลจาก log ด้านล่าง ห้ามเดา ห้ามเรียก tool

ใช้รูปแบบ Dashboard นี้เป๊ะ ๆ (ภาษาไทย ไม่เกิน 14 บรรทัด ไม่ต้องมีหัวข้ออื่นเพิ่ม):

☀️ Loop <DD/MM> · <HH:MM>
🚦 release web-app: <วัน DD/MM> · merge-back <✅ หรือ ⛔ รอ N commits>

✅ ทำแล้ว    <สรุปสั้น เช่น ติด label 2 ใบ · อัปเดต comment 1 ใบ · โพสต์ comment ใหม่ 1 ใบ — ลิงก์ ticket ที่ถูกแก้ทุกใบ> หรือ —
🔨 กำลังทำ   <ticket → MR/branch พร้อมลิงก์> หรือ —
⛔ หยุด      <ticket: เหตุผลสั้น> (แสดงเฉพาะเมื่อมี)
⏳ รอคุณ     <N เรื่อง> หรือ ไม่มีเรื่องใหม่
💤 ไม่ขยับ    <N ใบ>

👉 ต้องทำ
1. <action สั้น> → [เปิด](<ลิงก์>)
(เฉพาะเรื่องใหม่รอบนี้: ตรวจ MR, สั่ง /loop-ship /loop-e2e /merge-approved, ตอบคำถามของ ticket ที่เพิ่งติด needs:human ห้ามยกคำถามเก่าที่ยังไม่ได้คำตอบมาซ้ำ ถ้าไม่มีให้เขียน \"ไม่มี\" แทนรายการ)

ถ้ารันพัง ให้บรรทัด ✅ เป็น \"รันไม่สำเร็จ: <สาเหตุสั้น>\" และ 👉 เป็นสิ่งที่ควรเช็ค

รูปแบบลิงก์:
- Jira: https://example.atlassian.net/browse/<KEY>
- GitLab issue project-b: https://gitlab.example.com/example-team/<repo>/-/issues/<n>
- MR: ใช้ URL ตามที่อยู่ใน log
- Notion Issues DB: https://www.notion.so/<issues-db-id>
- ไฟล์บนเครื่อง: เขียนเป็น path เต็ม

Log:
$section" --permission-mode default --max-turns 2 < /dev/null 2>&1) || return
  mkdir -p "$LOOP_DIR/summaries"
  printf '## %s\n\n%s\n\n' "$NOW" "$summary" >> "$LOOP_DIR/summaries/$TODAY.md"
}

on_exit() {
  [ "$DID" = "1" ] && summarize
  rmdir "$LOCK"
}
trap on_exit EXIT

# A run replayed on wake starts before Wi-Fi is back; wait up to 2 minutes for the API.
for _ in $(seq 1 12); do
  curl -s -o /dev/null --max-time 5 https://api.anthropic.com && break
  sleep 10
done

# Prints the value after "<KEY>: " on the first matching line of $1.
field() { printf '%s\n' "$1" | grep -m1 "^$2:" | sed "s/^$2: *//"; }

DENY_COMMON=(
  "Read(**/.env*)" "Edit(**/.env*)" "Write(**/.env*)"
  "Bash(git push --force:*)" "Bash(git push -f:*)" "Bash(git push --force-with-lease:*)"
  "Bash(git reset:*)" "Bash(git rebase:*)" "Bash(git merge:*)" "Bash(git clean:*)"
  "Bash(glab mr merge:*)" "Bash(glab mr approve:*)" "Bash(rm -rf:*)" "WebFetch"
)

# ---------- Coordinator ----------
PREV="(none)"
[ -f "$LAST" ] && PREV=$(cat "$LAST")
HANDLED=$("$STATE" list | sed 's/^/- /')

# web-app releases every Wednesday: staging → master, semantic-release commits
# "chore(release): x.y.z" on master, then master is merged back into staging.
# Until that merge-back lands, master has commits staging lacks; merging into
# staging in that window breaks the version and CHANGELOG.
WEBAPP_DIR="$HOME/Projects/project-a/web-app"
git -C "$WEBAPP_DIR" fetch -q origin master staging 2>/dev/null
MERGE_BACK_PENDING=$(git -C "$WEBAPP_DIR" rev-list --count origin/staging..origin/master 2>/dev/null || echo "?")
NEXT_WED=$(date -v+"$(( (3 - $(date +%u) + 7) % 7 ))"d +%F)
RELEASE_CTX="- web-app (project-a): release every Wednesday. Next release: $NEXT_WED. Cut-off for that release: the Monday before, 14:00.
- web-app merge-back pending (master commits not in staging): $MERGE_BACK_PENDING (0 = clear; >0 = do not merge anything into staging)
- project-b: no release cadence yet."

OUT=$(cd "$LOOP_DIR" && claude -p "/loop-triage

Release context:
$RELEASE_CTX

Handled tickets (do not pick):
${HANDLED:-(none)}

Previous report:
$PREV" \
  --permission-mode default \
  --max-turns 60 \
  --allowedTools \
    "Skill" \
    "mcp__claude_ai_Atlassian_Rovo__atlassianUserInfo" \
    "mcp__claude_ai_Atlassian_Rovo__getAccessibleAtlassianResources" \
    "mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql" \
    "mcp__claude_ai_Atlassian_Rovo__getJiraIssue" \
    "mcp__claude_ai_Atlassian_Rovo__editJiraIssue" \
    "mcp__claude_ai_Atlassian_Rovo__addCommentToJiraIssue" \
    "mcp__plugin_Notion_notion__notion-get-self" \
    "mcp__plugin_Notion_notion__notion-fetch" \
    "mcp__plugin_Notion_notion__notion-search" \
    "mcp__plugin_Notion_notion__notion-query-data-sources" \
    "mcp__plugin_Notion_notion__notion-query-database-view" \
    "Bash(glab issue list:*)" \
    "Bash(glab issue view:*)" \
    "Bash(glab issue update:*)" \
    "Bash(glab issue note:*)" \
    "Bash(glab api --hostname gitlab.example.com projects/:*)" \
    "Bash(glab api --hostname gitlab.example.com -X PUT projects/:*)" \
  --disallowedTools "Edit" "Write" "NotebookEdit" "Bash(glab api --hostname gitlab.example.com -X DELETE:*)" "${DENY_COMMON[@]}" 2>&1)
STATUS=$?

# The model sometimes prints a preamble line, so locate the first NOTIFY: line.
NLINE=$(printf '%s\n' "$OUT" | grep -n -m1 '^NOTIFY:' | cut -d: -f1)
if [ $STATUS -ne 0 ] || [ -z "$NLINE" ]; then
  DID=1
  log "## $NOW triage FAILED (exit $STATUS)" "" "$OUT" ""
  notify "triage พัง ดู logs/$TODAY.md"
  exit 1
fi

MSG=$(field "$OUT" NOTIFY)
PICK=$(field "$OUT" PICK)
REPORT=$(printf '%s\n' "$OUT" | tail -n +$((NLINE + 1)) | grep -v '^PICK:')
printf '%s\n' "$REPORT" > "$LAST"
log "## $NOW triage" "" "PICK: ${PICK:-none}" "RELEASE: web-app next $NEXT_WED · merge-back pending commits: $MERGE_BACK_PENDING" "$REPORT" ""
[ "$MSG" != "none" ] && { DID=1; notify "$MSG"; }

# ---------- Worker gate ----------
[ "${TRIAGE_ONLY:-0}" = "1" ] && exit 0
TICKET=$(echo "$PICK" | awk '{print $1}')
REPO=$(echo "$PICK" | awk '{print $2}')
{ [ -z "$TICKET" ] || [ "$TICKET" = "none" ]; } && exit 0

if ! read -r REPO_DIR BASE < <("$STATE" repo "$REPO" 2>/dev/null) || [ -z "$BASE" ]; then
  log "## $NOW worker skipped — unknown repo '$REPO' for $TICKET (add it to $LOOP_DIR/repos)"
  exit 0
fi

if [ "$REPO" = "web-app" ] && [ "$MERGE_BACK_PENDING" != "0" ]; then
  log "## $NOW worker skipped — web-app merge-back master → staging pending ($MERGE_BACK_PENDING commits)"
  exit 0
fi
if [ -n "$("$STATE" list working)" ]; then
  log "## $NOW worker skipped — another ticket is still working"
  exit 0
fi
if "$STATE" get "$TICKET" >/dev/null; then
  log "## $NOW worker skipped — $TICKET already handled ($("$STATE" get "$TICKET" status))"
  exit 0
fi

# 8 GB machine: test suites and builds need headroom.
FREE=$(memory_pressure -Q 2>/dev/null | grep -oE '[0-9]+%' | tr -d '%')
if [ -n "$FREE" ] && [ "$FREE" -lt 30 ]; then
  log "## $NOW worker skipped — free memory ${FREE}% < 30%"
  exit 0
fi

WT=$("$STATE" path "$REPO" "$TICKET")
mkdir -p "$(dirname "$WT")"
if ! { git -C "$REPO_DIR" fetch origin "$BASE" >/dev/null 2>&1 \
       && git -C "$REPO_DIR" worktree add --detach "$WT" "origin/$BASE" >/dev/null 2>&1; }; then
  log "## $NOW worker FAILED — could not create worktree $WT from origin/$BASE"
  notify "Worker สร้าง worktree ไม่ได้ ($TICKET)"
  exit 1
fi
"$HOME/.claude/hooks/wt-setup" "$WT" >/dev/null 2>&1 || log "## $NOW worker: wt-setup failed for $WT (local files not linked)"
"$STATE" set "$TICKET" working repo="$REPO"
DID=1
notify "Worker เริ่ม $TICKET ($REPO)"

WORKER_ALLOW=(
  "Skill" "Agent" "TodoWrite"
  "Bash(git status:*)" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)" "Bash(git add:*)"
  "Bash(git commit:*)" "Bash(git switch:*)" "Bash(git checkout -b:*)" "Bash(git branch:*)"
  "Bash(git rev-parse:*)" "Bash(git fetch:*)" "Bash(git stash:*)"
  "Bash(yarn:*)" "Bash(npm:*)" "Bash(npx:*)" "Bash(node:*)" "Bash(./init.sh:*)"
  "Bash(.harness/scripts/session-report.sh:*)" "Bash(.harness/scripts/check-tdd-order.sh:*)"
  "Bash(./scripts/check-commit-msg.sh:*)"
  "Bash(ls:*)" "Bash(cat:*)" "Bash(head:*)" "Bash(tail:*)" "Bash(grep:*)" "Bash(find:*)"
  "Bash(wc:*)" "Bash(mkdir:*)" "Bash(ps:*)" "Bash(pgrep:*)" "Bash(pkill -f karma:*)"
  "mcp__claude_ai_Atlassian_Rovo__getAccessibleAtlassianResources"
  "mcp__claude_ai_Atlassian_Rovo__getJiraIssue"
  "Bash(glab issue view:*)" "Bash(~/loop/bin/loop-state:*)"
)
WORKER_DENY=("${DENY_COMMON[@]}")
if [ "$REPO" = "web-app" ]; then
  WORKER_ALLOW+=(
    "Bash(git push -u origin:*)" "Bash(.harness/scripts/ship.sh --yes:*)"
    "Bash(glab mr view:*)" "Bash(glab mr update:*)" "Bash(glab mr note:*)"
    "mcp__claude_ai_Atlassian_Rovo__editJiraIssue" "mcp__claude_ai_Atlassian_Rovo__addCommentToJiraIssue"
  )
else
  # project-b-web CLAUDE.md: no agent reaches a remote.
  WORKER_DENY+=("Bash(git push:*)" "Bash(glab mr:*)" "Bash(glab issue note:*)" "Bash(glab issue update:*)"
                "mcp__claude_ai_Atlassian_Rovo__editJiraIssue" "mcp__claude_ai_Atlassian_Rovo__addCommentToJiraIssue")
fi

# Runs one claude phase in the worktree; $1 = prompt, $2 = max turns, rest = extra flags.
phase() {
  local prompt="$1" turns="$2"; shift 2
  (cd "$WT" && claude -p "$prompt" --max-turns "$turns" "$@" 2>&1)
}

fail_ticket() {
  "$STATE" set "$TICKET" blocked
  log "### $1" "" "$2" ""
  notify "Worker หยุด $TICKET: ต้องการคุณ"
  pkill -f karma >/dev/null 2>&1
  exit 0
}

# ---------- Worker build ----------
OUT=$(phase "/loop-work $TICKET $REPO" 200 --permission-mode acceptEdits \
  --allowedTools "${WORKER_ALLOW[@]}" --disallowedTools "${WORKER_DENY[@]}")
log "## $NOW worker $TICKET ($REPO)" ""
RESULT=$(field "$OUT" RESULT)
[ "$RESULT" = "ready-for-review" ] || fail_ticket "worker build: ${RESULT:-no RESULT line}" "$OUT"
UI=$(printf '%s\n' "$OUT" | sed -n '/^### UI change/{n;p;q;}' | tr -d ' ')
case "$UI" in yes|no) "$STATE" set "$TICKET" working ui="$UI" ;; esac
log "### build" "" "$(printf '%s\n' "$OUT" | sed -n '/^RESULT:/,$p')" ""

# ---------- Reviewer (read-only) ----------
REVIEW=$(phase "/loop-review origin/$BASE" 60 --permission-mode default \
  --allowedTools "Skill" "Read" "Grep" "Glob" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)" "Bash(git status:*)" \
  --disallowedTools "Edit" "Write" "NotebookEdit" "Agent" "${DENY_COMMON[@]}")
printf '%s\n' "$REVIEW" | grep -q '^RESULT: findings' || fail_ticket "reviewer: no RESULT line" "$REVIEW"
REVIEW=$(printf '%s\n' "$REVIEW" | sed -n '/^RESULT: findings/,$p')
log "### review" "" "$REVIEW" ""

# ---------- Worker finish ----------
OUT=$(phase "/loop-work $TICKET $REPO --finish

Reviewer findings:
$REVIEW" 200 --permission-mode acceptEdits \
  --allowedTools "${WORKER_ALLOW[@]}" --disallowedTools "${WORKER_DENY[@]}")
RESULT=$(field "$OUT" RESULT)
BRANCH=$(git -C "$WT" branch --show-current)
case "$RESULT" in
  mr-open*)
    URL=$(echo "$RESULT" | awk '{print $2}')
    "$STATE" set "$TICKET" mr-open branch="$BRANCH" mr="$URL"
    log "### finish" "" "$(printf '%s\n' "$OUT" | sed -n '/^RESULT:/,$p')" ""
    notify "MR พร้อมให้ตรวจ: $TICKET"
    ;;
  ready-to-ship*)
    "$STATE" set "$TICKET" ready-to-ship branch="$BRANCH"
    printf '%s\n' "$OUT" | sed -n '/^### MR title/,$p' > "$LOOP_DIR/state/mr-draft-$TICKET.md"
    log "### finish" "" "$(printf '%s\n' "$OUT" | sed -n '/^RESULT:/,$p')" ""
    notify "$TICKET พร้อม ship: สั่ง /loop-ship $TICKET"
    ;;
  *)
    fail_ticket "worker finish: ${RESULT:-no RESULT line}" "$OUT"
    ;;
esac
pkill -f karma >/dev/null 2>&1
exit 0
