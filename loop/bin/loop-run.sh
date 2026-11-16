#!/bin/bash
# Loop Engineering runner. launchd (com.example.loop) calls this daily at 9:15.
# One run: Coordinator (triage + route + pick, headless) → for each picked task, while Worker slots are free:
#   prepare a worktree and open a visible herdr session running `/loop-work <task> <repo> <risk>`.
#   The Worker session claims the task, builds, gets an independent review, opens a Draft MR and records loop-state itself,
#   then calls loop-next so a freed slot is filled the same day. Worktrees live in fixed slots (.claude/worktrees/loop-<n>)
#   so Claude asks folder trust once per slot.
# Manual run outside working hours: FORCE=1 ~/loop/bin/loop-run.sh
# Triage only (no Worker):          TRIAGE_ONLY=1 ~/loop/bin/loop-run.sh
# Parallel Workers (default 2):     LOOP_MAX_WORKERS=3 ~/loop/bin/loop-run.sh
set -u

LOOP_DIR="$HOME/loop"
STATE="$LOOP_DIR/bin/loop-state"   # owns task state and worktree paths
MAX_WORKERS="${LOOP_MAX_WORKERS:-2}"
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

# One runner at a time. Workers run in their own sessions, so the runner itself is short.
if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +60)" ]; then
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

ใช้รูปแบบ Dashboard นี้เป๊ะ ๆ (ภาษาไทย ไม่เกิน 16 บรรทัด ไม่ต้องมีหัวข้ออื่นเพิ่ม):

☀️ Loop <DD/MM> · <HH:MM>
🚦 release web-app: <วัน DD/MM> · merge-back <✅ หรือ ⛔ รอ N commits>

✅ ทำแล้ว    <สรุปสั้น เช่น route 2 ใบ · comment คำถาม 1 ใบ — ลิงก์ task ที่ถูกแก้ทุกใบ> หรือ —
🔨 กำลังทำ   <task → Worker session ที่เปิด (risk) พร้อมลิงก์> หรือ —
⛔ หยุด      <task: เหตุผลสั้น> (แสดงเฉพาะเมื่อมี)
❓ ต้อง grill  <task → ถามใคร เรื่องอะไร> (แสดงเฉพาะเมื่อมี ห้ามยกตัวคำถามมาซ้ำ)
💤 ไม่ขยับ    <N ใบ>

👉 ต้องทำ
1. <action สั้น> → [เปิด](<ลิงก์>)
(เฉพาะเรื่องใหม่รอบนี้: ดู Worker session ใน herdr, ไปถามข้อมูลของ task ที่เพิ่งติด needs:human ห้ามยกคำถามเก่าที่ยังไม่ได้คำตอบมาซ้ำ ถ้าไม่มีให้เขียน \"ไม่มี\" แทนรายการ)

ถ้ารันพัง ให้บรรทัด ✅ เป็น \"รันไม่สำเร็จ: <สาเหตุสั้น>\" และ 👉 เป็นสิ่งที่ควรเช็ค

รูปแบบลิงก์:
- Workspace task: ใช้ลิงก์ที่อยู่ในตารางของ log เท่านั้น (รูปแบบ [APP-39](https://.../tasks/<id>))
- MR: ใช้ URL ตามที่อยู่ใน log
- ไฟล์บนเครื่อง: เขียนเป็น path เต็ม

Log:
$section" --model haiku --effort medium --permission-mode default --max-turns 2 < /dev/null 2>&1) || return
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
  "Read(**/.env*)" "Edit(**/.env*)" "Write(**/.env*)" "Read(**/.npmrc)"
  "Bash(git push --force:*)" "Bash(git push -f:*)" "Bash(git push --force-with-lease:*)"
  "Bash(git reset:*)" "Bash(git rebase:*)" "Bash(git merge:*)" "Bash(git clean:*)"
  "Bash(glab mr merge:*)" "Bash(glab mr approve:*)" "Bash(rm -rf:*)" "WebFetch"
)
WORKSPACE_READ=(
  "mcp__workspace__list_spaces" "mcp__workspace__query_view"
  "mcp__workspace__get_task" "mcp__workspace__list_comments"
)
WORKSPACE_DENY=(
  "mcp__workspace__create_task" "mcp__workspace__send_task_to_space"
  "mcp__workspace__add_subtask" "mcp__workspace__add_dependency"
  "mcp__workspace__create_space_doc" "mcp__workspace__update_space_doc"
  "mcp__workspace__add_doc_image" "mcp__workspace__send_request"
  "mcp__workspace__decide_request"
)

# Free the slots of tasks whose Worker is done; their branches stay.
for T in $("$STATE" list | awk '$2 ~ /status=(mr-open|ready-to-ship|merged)/ && / wt=/ { print $1 }'); do
  "$STATE" release "$T" >/dev/null 2>&1 || log "## $NOW slot of $T not released (uncommitted changes)"
done

# ---------- Coordinator ----------
PREV="(none)"
[ -f "$LAST" ] && PREV=$(cat "$LAST")
HANDLED=$("$STATE" list | sed 's/^/- /')
WORKING=$("$STATE" list working | grep -c .)
SLOTS=$(( MAX_WORKERS - WORKING ))
[ "$SLOTS" -lt 0 ] && SLOTS=0
[ "${TRIAGE_ONLY:-0}" = "1" ] && SLOTS=0

# web-app releases every Wednesday: staging → master, semantic-release commits
# "chore(release): x.y.z" on master, then master is merged back into staging.
# Until that merge-back lands, master has commits staging lacks; merging into
# staging in that window breaks the version and CHANGELOG.
WEBAPP_DIR="$HOME/Home/project-a/web-app"
git -C "$WEBAPP_DIR" fetch -q origin master staging 2>/dev/null
MERGE_BACK_PENDING=$(git -C "$WEBAPP_DIR" rev-list --count origin/staging..origin/master 2>/dev/null || echo "?")
NEXT_WED=$(date -v+"$(( (3 - $(date +%u) + 7) % 7 ))"d +%F)
RELEASE_CTX="- web-app (project-a, space APP): release every Wednesday. Next release: $NEXT_WED. Cut-off for that release: the Monday before, 14:00.
- web-app merge-back pending (master commits not in staging): $MERGE_BACK_PENDING (0 = clear; >0 = do not merge anything into staging)
- project-b (space PB): no release cadence yet."

OUT=$(cd "$LOOP_DIR" && claude -p "/loop-triage

Worker slots: $SLOTS

Release context:
$RELEASE_CTX

Handled tickets (do not pick):
${HANDLED:-(none)}

Previous report:
$PREV" \
  --model opus --effort medium \
  --permission-mode default \
  --max-turns 80 \
  --allowedTools "Skill" "Read" "${WORKSPACE_READ[@]}" \
    "mcp__workspace__update_task" "mcp__workspace__add_comment" \
  --disallowedTools "Edit" "Write" "NotebookEdit" "Bash" "Agent" \
    "mcp__workspace__transition_task" "mcp__workspace__start_work" \
    "mcp__workspace__finish_work" "mcp__workspace__update_work_state" \
    "mcp__workspace__add_task_link" "${WORKSPACE_DENY[@]}" "${DENY_COMMON[@]}" 2>&1)
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
PICKS=$(printf '%s\n' "$OUT" | grep '^PICK:' | sed 's/^PICK: *//' | grep -v '^none$')
REPORT=$(printf '%s\n' "$OUT" | tail -n +$((NLINE + 1)) | grep -v '^PICK:')
printf '%s\n' "$REPORT" > "$LAST"
log "## $NOW triage" "" "PICK: ${PICKS:-none}" "WORKERS: $WORKING working · $SLOTS free of $MAX_WORKERS" \
  "RELEASE: web-app next $NEXT_WED · merge-back pending commits: $MERGE_BACK_PENDING" "$REPORT" ""
[ "$MSG" != "none" ] && { DID=1; notify "$MSG"; }

# ---------- Workers ----------
[ "${TRIAGE_ONLY:-0}" = "1" ] && exit 0
[ -z "$PICKS" ] && exit 0

WORKER_ALLOW=(
  "Skill" "Agent" "TodoWrite" "Read" "Edit" "Write" "Grep" "Glob"
  "Bash(git status:*)" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)" "Bash(git add:*)"
  "Bash(git commit:*)" "Bash(git branch:*)" "Bash(git rev-parse:*)" "Bash(git fetch:*)" "Bash(git rev-list:*)"
  "Bash(~/loop/bin/loop-push)" "Bash($HOME/loop/bin/loop-push)"
  "Bash(yarn:*)" "Bash(npm:*)" "Bash(npx:*)" "Bash(node:*)" "Bash(bun:*)" "Bash(go:*)" "Bash(make:*)"
  "Bash(uv:*)" "Bash(python3:*)" "Bash(./init.sh:*)" "Bash(./scripts/:*)" "Bash(.harness/scripts/:*)"
  "Bash(glab mr create:*)" "Bash(glab mr view:*)" "Bash(glab mr update:*)" "Bash(glab mr note:*)"
  "Bash(ls:*)" "Bash(cat:*)" "Bash(head:*)" "Bash(tail:*)" "Bash(grep:*)" "Bash(find:*)"
  "Bash(wc:*)" "Bash(mkdir:*)" "Bash(ps:*)" "Bash(pgrep:*)" "Bash(pkill -f karma:*)"
  "Bash(sed:*)" "Bash(which:*)" "Bash(docker:*)" "Bash(colima status:*)" "Bash(glab api projects/:*)"
  "Bash(~/loop/bin/loop-next)" "Bash($HOME/loop/bin/loop-next)"
  "Bash(~/loop/bin/loop-state:*)" "Bash($HOME/loop/bin/loop-state:*)"
  "Bash(~/loop/bin/loop-heavy:*)" "Bash($HOME/loop/bin/loop-heavy:*)"
  "${WORKSPACE_READ[@]}" "mcp__workspace__get_work_context"
  "mcp__workspace__start_work" "mcp__workspace__update_work_state"
  "mcp__workspace__finish_work" "mcp__workspace__transition_task"
  "mcp__workspace__add_task_link" "mcp__workspace__add_comment"
  "mcp__workspace__update_task"
)
WORKER_DENY=(
  "${DENY_COMMON[@]}" "${WORKSPACE_DENY[@]}"
  "Bash(git push:*)" "Bash(git -C:*)" "Bash(glab api -X:*)" "Bash(glab api --method:*)"
)

# Opens a visible Worker session: a herdr space when the window is up, else a background herdr-core terminal.
open_session() {
  local task="$1" repo="$2" risk="$3" wt="$4" json
  json=$(python3 -I - "$task" "$repo" "$risk" "$wt" <<'PY' "${WORKER_ALLOW[@]}" -- "${WORKER_DENY[@]}"
import json, sys
task, repo, risk, wt = sys.argv[1:5]
rest = sys.argv[5:]
cut = rest.index("--")
allow, deny = rest[:cut], rest[cut + 1:]
argv = ["claude", "--model", "opus", "--effort", "medium", "--permission-mode", "acceptEdits",
        "--allowedTools", *allow, "--disallowedTools", *deny, "--", f"/loop-work {task} {repo} {risk}"]
print(json.dumps({"name": f"loop {task}", "folder": wt, "tab": "worker", "argv": argv}))
PY
)
  if herdr-app status >/dev/null 2>&1 && herdr-app do space.new "$json" >/dev/null 2>&1; then
    sleep 3
    if "$HOME/.local/bin/herdr-core" ls 2>/dev/null | grep -q "loop $task"; then
      echo "herdr space 'loop $task'"
    else
      echo "herdr space 'loop $task' (not yet listed by herdr-core ls: check the app)"
    fi
    return 0
  fi
  local argv=()
  while IFS= read -r line; do argv+=("$line"); done < <(printf '%s' "$json" | python3 -I -c 'import json,sys; print("\n".join(json.load(sys.stdin)["argv"]))')
  hc run --bg --name "loop-$(echo "$task" | tr '[:upper:]' '[:lower:]')" --cwd "$wt" --no-parent -- "${argv[@]}" >/dev/null 2>&1 \
    && { echo "herdr-core terminal loop-$task (open the herdr app to see it)"; return 0; }
  return 1
}

start_worker() {
  local task="$1" repo="$2" risk="${3:-?}" repo_dir base wt branch free where
  if ! read -r repo_dir base < <("$STATE" repo "$repo" 2>/dev/null) || [ -z "$base" ]; then
    log "## $NOW worker skipped — unknown repo '$repo' for $task (add it to $LOOP_DIR/repos)"
    return
  fi
  if [ "$repo" = "web-app" ] && [ "$MERGE_BACK_PENDING" != "0" ]; then
    log "## $NOW worker skipped — $task: web-app merge-back master → staging pending ($MERGE_BACK_PENDING commits)"
    return
  fi
  if "$STATE" get "$task" >/dev/null; then
    log "## $NOW worker skipped — $task already handled ($("$STATE" get "$task" status))"
    return
  fi
  # 8 GB machine: test suites and builds need headroom.
  free=$(memory_pressure -Q 2>/dev/null | grep -oE '[0-9]+%' | tr -d '%')
  if [ -n "$free" ] && [ "$free" -lt 30 ]; then
    log "## $NOW worker skipped — $task: free memory ${free}% < 30%"
    return
  fi

  if ! wt=$("$STATE" slot "$repo" "$MAX_WORKERS"); then
    log "## $NOW worker skipped — $task: every $repo slot is in use (loop-state list; blocked tasks keep theirs)"
    return
  fi
  branch="loop/$(echo "$task" | tr '[:upper:]' '[:lower:]')"
  mkdir -p "$(dirname "$wt")"
  if ! { git -C "$repo_dir" fetch origin "$base" >/dev/null 2>&1 \
         && git -C "$repo_dir" worktree add --no-track -b "$branch" "$wt" "origin/$base" >/dev/null 2>&1; }; then
    log "## $NOW worker FAILED — $task: could not create worktree $wt on $branch from origin/$base"
    notify "Worker สร้าง worktree ไม่ได้ ($task)"
    DID=1
    return
  fi
  "$HOME/.claude/hooks/wt-setup" "$wt" >/dev/null 2>&1 || log "## $NOW worker: wt-setup failed for $wt (local files not linked)"
  "$STATE" set "$task" working repo="$repo" branch="$branch" wt="$wt"
  DID=1
  if where=$(open_session "$task" "$repo" "$risk" "$wt"); then
    log "## $NOW worker started $task ($repo, risk:$risk) — $where" "worktree: $wt" ""
    notify "Worker เริ่ม $task ($repo, risk:$risk)"
  else
    "$STATE" set "$task" blocked
    log "## $NOW worker FAILED — $task: could not open a herdr session (herdr-app and hc both failed)" ""
    notify "เปิด Worker session ไม่ได้ ($task)"
  fi
}

STARTED=0
while read -r TASK REPO RISK; do
  [ -z "$TASK" ] && continue
  [ "$STARTED" -ge "$SLOTS" ] && { log "## $NOW worker skipped — $TASK: no free Worker slot"; continue; }
  start_worker "$TASK" "$REPO" "$RISK"
  STARTED=$((STARTED + 1))
done <<< "$PICKS"
exit 0
