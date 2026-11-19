#!/bin/bash
# Loop Engineering runner. launchd (com.example.loop) calls this daily at 9:15.
# One run: Coordinator (triage + route + pick, headless) → for each picked task, while Worker slots are free:
#   prepare a worktree and open a Claude Code background session (claude --bg) running `/loop-work <task> <repo> <risk>`.
#   The Worker session claims the task, builds, gets an independent review, opens a Draft MR and records loop-state itself,
#   then calls loop-next so a freed slot is filled the same day. Each task gets its own worktree (.claude/worktrees/<task>),
#   kept until /merge-approved removes it; it inherits the main checkout's folder trust.
# Manual run outside working hours: FORCE=1 ~/loop/bin/loop-run.sh
# Triage only (no Worker):          TRIAGE_ONLY=1 ~/loop/bin/loop-run.sh
# Parallel Workers (default 2):     LOOP_MAX_WORKERS=3 ~/loop/bin/loop-run.sh
set -u

LOOP_DIR="$HOME/loop"
STATE="$LOOP_DIR/bin/loop-state"   # owns task state and worktree paths
SPEC="$LOOP_DIR/bin/loop-spec"
CONFIG="$LOOP_DIR/config.sh"
[ -f "$CONFIG" ] || { echo "loop-run: missing $CONFIG (copy loop/config.example.sh and fill it in)" >&2; exit 1; }
. "$CONFIG"
MAX_WORKERS="${LOOP_MAX_WORKERS:-2}"
MAX_DESIGNERS="${LOOP_MAX_DESIGNERS:-1}"
# launchd has no user PATH; claude is a native install, glab/git/node come from Homebrew.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

TODAY=$(date +%F)
NOW=$(date +%H:%M)
LOG="$LOOP_DIR/logs/$TODAY.md"
LAST="$LOOP_DIR/state/last-triage.md"
SPECS="$LOOP_DIR/specs"
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
🚦 release $RELEASE_REPO: <วัน DD/MM> · merge-back <✅ หรือ ⛔ รอ N commits>

✅ ทำแล้ว    <สรุปสั้น เช่น route 2 ใบ · comment คำถาม 1 ใบ — ลิงก์ task ที่ถูกแก้ทุกใบ> หรือ —
🔨 กำลังทำ   <task → Worker session ที่เปิด (risk) พร้อมลิงก์> หรือ —
🧩 design    <task → Designer session ที่เปิดรอบนี้> (แสดงเฉพาะเมื่อมี)
🧹 cleanup   <บรรทัด "cleanup: archived … removed … kept …" จาก log และของที่ kept พร้อมเหตุผล> (แสดงเฉพาะเมื่อมี)
👀 รอรีวิว   <task ที่ design เป็น proposed → สั่ง /loop-design-review <task>> (แสดงเฉพาะเมื่อมี)
⛔ หยุด      <task: เหตุผลสั้น> (แสดงเฉพาะเมื่อมี)
❓ ต้อง grill  <task → ถามใคร เรื่องอะไร> (แสดงเฉพาะเมื่อมี ห้ามยกตัวคำถามมาซ้ำ)
💤 ไม่ขยับ    <N ใบ>

👉 ต้องทำ
1. <action สั้น> → [เปิด](<ลิงก์>)
(เฉพาะเรื่องใหม่รอบนี้: ดู Worker session ด้วย claude attach, ไปถามข้อมูลของ task ที่เพิ่งติด needs:human ห้ามยกคำถามเก่าที่ยังไม่ได้คำตอบมาซ้ำ ถ้าไม่มีให้เขียน \"ไม่มี\" แทนรายการ)

ถ้ารันพัง ให้บรรทัด ✅ เป็น \"รันไม่สำเร็จ: <สาเหตุสั้น>\" และ 👉 เป็นสิ่งที่ควรเช็ค

รูปแบบลิงก์:
- Workspace task: ใช้ลิงก์ที่อยู่ในตารางของ log เท่านั้น (รูปแบบ $TASK_LINK_EXAMPLE)
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
  "mcp__${WORKSPACE_MCP}__list_spaces" "mcp__${WORKSPACE_MCP}__query_view"
  "mcp__${WORKSPACE_MCP}__get_task" "mcp__${WORKSPACE_MCP}__list_comments"
)
WORKSPACE_DENY=(
  "mcp__${WORKSPACE_MCP}__create_task" "mcp__${WORKSPACE_MCP}__send_task_to_space"
  "mcp__${WORKSPACE_MCP}__add_subtask" "mcp__${WORKSPACE_MCP}__add_dependency"
  "mcp__${WORKSPACE_MCP}__create_space_doc" "mcp__${WORKSPACE_MCP}__update_space_doc"
  "mcp__${WORKSPACE_MCP}__add_doc_image" "mcp__${WORKSPACE_MCP}__send_request"
  "mcp__${WORKSPACE_MCP}__decide_request"
)

CLEANED=$("$LOOP_DIR/bin/loop-clean" 2>&1)
[ -n "$CLEANED" ] && { DID=1; log "## $NOW cleanup" "" "$CLEANED" ""; }

# ---------- Coordinator ----------
PREV="(none)"
[ -f "$LAST" ] && PREV=$(cat "$LAST")
HANDLED=$("$STATE" list | sed 's/^/- /')
WORKING=$("$STATE" list working | grep -c .)
SLOTS=$(( MAX_WORKERS - WORKING ))
[ "$SLOTS" -lt 0 ] && SLOTS=0
[ "${TRIAGE_ONLY:-0}" = "1" ] && SLOTS=0
DESIGNING_KEYS=$("$SPEC" list designing | cut -d' ' -f1)
DESIGNING=$(printf '%s\n' "$DESIGNING_KEYS" | grep -c .)
[ "${TRIAGE_ONLY:-0}" = "1" ] && MAX_DESIGNERS=0
space_of() { echo "${1%%-*}"; }
designing_in() { printf '%s\n' "$DESIGNING_KEYS" | grep -c "^$1-"; }
FULL_SPACES=""
for DESIGN_SPACE in $(printf '%s\n' "$DESIGNING_KEYS" | grep . | sed 's/-.*//' | sort -u); do
  [ "$(designing_in "$DESIGN_SPACE")" -ge "$MAX_DESIGNERS" ] && FULL_SPACES="$FULL_SPACES $DESIGN_SPACE"
done
FULL_SPACES="${FULL_SPACES# }"
DESIGNS=$("$SPEC" list | sed 's/^/- /')
PSTACK=$(ls -dt "$HOME"/.claude/plugins/cache/*/pstack/*/ 2>/dev/null | head -n 1)
[ -n "$PSTACK" ] && ln -sfn "${PSTACK%/}" "$LOOP_DIR/pstack"

# web-app releases every Wednesday: staging → master, semantic-release commits
# "chore(release): x.y.z" on master, then master is merged back into staging.
# Until that merge-back lands, master has commits staging lacks; merging into
# staging in that window breaks the version and CHANGELOG.
RELEASE_DIR=$("$STATE" repo "$RELEASE_REPO" 2>/dev/null | cut -d' ' -f1)
git -C "$RELEASE_DIR" fetch -q origin master staging 2>/dev/null
MERGE_BACK_PENDING=$(git -C "$RELEASE_DIR" rev-list --count origin/staging..origin/master 2>/dev/null || echo "?")
NEXT_WED=$(date -v+"$(( (3 - $(date +%u) + 7) % 7 ))"d +%F)
RELEASE_CTX="- $RELEASE_REPO ($RELEASE_SPACE_NOTE): release every Wednesday. Next release: $NEXT_WED. Cut-off for that release: the Monday before, 14:00.
- $RELEASE_REPO merge-back pending (master commits not in staging): $MERGE_BACK_PENDING (0 = clear; >0 = do not merge anything into staging)
$OTHER_RELEASE_NOTE"

spec_ready() { grep -qx 'status: ready' "$SPECS/$1.md" 2>/dev/null; }
READY_SPECS=$(grep -lx 'status: ready' "$SPECS"/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.md$//')

OUT=$(cd "$LOOP_DIR" && claude -p "/loop-triage

Worker slots: $SLOTS

Release context:
$RELEASE_CTX

Handled tickets (do not pick):
${HANDLED:-(none)}

Ready specs (only these may be picked):
${READY_SPECS:-(none)}

Designer slots: $MAX_DESIGNERS per space
Spaces with no free Designer slot: ${FULL_SPACES:-(none)}

Designs (do not send to design again unless the status is redo):
${DESIGNS:-(none)}

Previous report:
$PREV" \
  --model opus --effort medium \
  --permission-mode default \
  --max-turns 80 \
  --allowedTools "Skill" "Read" "Grep" "Glob" "${WORKSPACE_READ[@]}" \
    "mcp__${WORKSPACE_MCP}__update_task" "mcp__${WORKSPACE_MCP}__add_comment" \
  --disallowedTools "Edit" "Write" "NotebookEdit" "Bash" "Agent" \
    "mcp__${WORKSPACE_MCP}__transition_task" "mcp__${WORKSPACE_MCP}__start_work" \
    "mcp__${WORKSPACE_MCP}__finish_work" "mcp__${WORKSPACE_MCP}__update_work_state" \
    "mcp__${WORKSPACE_MCP}__add_task_link" "${WORKSPACE_DENY[@]}" "${DENY_COMMON[@]}" 2>&1)
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
DESIGN_PICKS=$(printf '%s\n' "$OUT" | grep '^DESIGN:' | sed 's/^DESIGN: *//' | grep -v '^none$')
CLOSED=$(printf '%s\n' "$OUT" | grep '^CLOSED:' | sed 's/^CLOSED: *//' | grep -v '^none$' | tr '\n' ' ')
REPORT=$(printf '%s\n' "$OUT" | tail -n +$((NLINE + 1)) | grep -v -e '^PICK:' -e '^DESIGN:' -e '^CLOSED:')
printf '%s\n' "$REPORT" > "$LAST"
log "## $NOW triage" "" "PICK: ${PICKS:-none}" "WORKERS: $WORKING working · $SLOTS free of $MAX_WORKERS" \
  "DESIGN: ${DESIGN_PICKS:-none}" "DESIGNERS: $DESIGNING designing · $MAX_DESIGNERS per space · full: ${FULL_SPACES:-none}" \
  "RELEASE: $RELEASE_REPO next $NEXT_WED · merge-back pending commits: $MERGE_BACK_PENDING" "$REPORT" ""
[ "$MSG" != "none" ] && { DID=1; notify "$MSG"; }
if [ -n "${CLOSED// /}" ]; then
  CLEANED=$("$LOOP_DIR/bin/loop-clean" archive $CLOSED 2>&1)
  [ -n "$CLEANED" ] && { DID=1; log "## $NOW cleanup (closed outside the Loop)" "" "$CLEANED" ""; }
fi

# ---------- Workers ----------
[ "${TRIAGE_ONLY:-0}" = "1" ] && exit 0
[ -z "$PICKS" ] && [ -z "$DESIGN_PICKS" ] && exit 0

WORKER_ALLOW=(
  "Skill" "Agent" "TodoWrite" "Read" "Edit" "Write" "Grep" "Glob"
  "Bash(git status:*)" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)" "Bash(git add:*)"
  "Bash(git commit:*)" "Bash(git branch:*)" "Bash(git rev-parse:*)" "Bash(git fetch:*)" "Bash(git rev-list:*)"
  "Bash(~/loop/bin/loop-push)" "Bash($HOME/loop/bin/loop-push)"
  "Bash(~/loop/bin/loop-mr:*)" "Bash($HOME/loop/bin/loop-mr:*)"
  "Bash(~/loop/bin/loop-upload:*)" "Bash($HOME/loop/bin/loop-upload:*)"
  "Bash(yarn:*)" "Bash(npm:*)" "Bash(npx:*)" "Bash(node:*)" "Bash(bun:*)" "Bash(go:*)" "Bash(make:*)"
  "Bash(uv:*)" "Bash(python3:*)" "Bash(./init.sh:*)" "Bash(./scripts/:*)" "Bash(.harness/scripts/:*)"
  "Bash(glab mr view:*)" "Bash(glab mr note:*)"
  "Bash(ls:*)" "Bash(cat:*)" "Bash(head:*)" "Bash(tail:*)" "Bash(grep:*)" "Bash(find:*)"
  "Bash(wc:*)" "Bash(mkdir:*)" "Bash(ps:*)" "Bash(pgrep:*)" "Bash(pkill -f karma:*)"
  "Bash(sed:*)" "Bash(which:*)" "Bash(docker:*)" "Bash(colima status:*)" "Bash(glab api projects/:*)"
  "Bash(~/loop/bin/loop-next)" "Bash($HOME/loop/bin/loop-next)"
  "Bash(~/loop/bin/loop-state:*)" "Bash($HOME/loop/bin/loop-state:*)"
  "Bash(~/loop/bin/loop-heavy:*)" "Bash($HOME/loop/bin/loop-heavy:*)"
  "Bash(~/loop/bin/loop-preview:*)" "Bash($HOME/loop/bin/loop-preview:*)"
  "Bash(~/loop/bin/loop-ask:*)" "Bash($HOME/loop/bin/loop-ask:*)"
  "Bash(~/loop/bin/loop-spec log:*)" "Bash($HOME/loop/bin/loop-spec log:*)"
  "Bash(~/loop/bin/loop-spec path:*)" "Bash($HOME/loop/bin/loop-spec path:*)"
  "Bash(~/loop/bin/loop-spec feedback:*)" "Bash($HOME/loop/bin/loop-spec feedback:*)"
  "Edit(~/loop/designs/**)" "Write(~/loop/designs/**)"
  "${WORKSPACE_READ[@]}" "mcp__${WORKSPACE_MCP}__get_work_context"
  "mcp__${WORKSPACE_MCP}__start_work" "mcp__${WORKSPACE_MCP}__update_work_state"
  "mcp__${WORKSPACE_MCP}__finish_work" "mcp__${WORKSPACE_MCP}__transition_task"
  "mcp__${WORKSPACE_MCP}__add_task_link" "mcp__${WORKSPACE_MCP}__add_comment"
  "mcp__${WORKSPACE_MCP}__update_task"
  "mcp__claude-in-chrome"
)
WORKER_DENY=(
  "${DENY_COMMON[@]}" "${WORKSPACE_DENY[@]}"
  "Bash(git push:*)" "Bash(git -C:*)" "Bash(glab mr create:*)" "Bash(glab mr update:*)" "Bash(glab api -X:*)" "Bash(glab api --method:*)"
  "Bash(~/loop/bin/loop-spec approve:*)" "Bash($HOME/loop/bin/loop-spec approve:*)"
  "Bash(~/loop/bin/loop-spec part:*)" "Bash($HOME/loop/bin/loop-spec part:*)"
)
DESIGNER_ALLOW=(
  "Skill" "Agent" "TodoWrite" "Read" "Grep" "Glob"
  "Edit(~/loop/designs/**)" "Write(~/loop/designs/**)"
  "Bash(git status:*)" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)" "Bash(git fetch:*)"
  "Bash(git rev-parse:*)" "Bash(git ls-files:*)" "Bash(git ls-tree:*)" "Bash(git grep:*)"
  "Bash(ls:*)" "Bash(cat:*)" "Bash(head:*)" "Bash(tail:*)" "Bash(grep:*)" "Bash(find:*)" "Bash(wc:*)"
  "Bash(~/loop/bin/loop-next)" "Bash($HOME/loop/bin/loop-next)"
  "Bash(~/loop/bin/loop-ask:*)" "Bash($HOME/loop/bin/loop-ask:*)"
  "Bash(~/loop/bin/loop-spec done:*)" "Bash($HOME/loop/bin/loop-spec done:*)"
  "Bash(~/loop/bin/loop-spec block:*)" "Bash($HOME/loop/bin/loop-spec block:*)"
  "Bash(~/loop/bin/loop-spec status:*)" "Bash($HOME/loop/bin/loop-spec status:*)"
  "Bash(~/loop/bin/loop-spec path:*)" "Bash($HOME/loop/bin/loop-spec path:*)"
  "Bash(~/loop/bin/loop-spec log:*)" "Bash($HOME/loop/bin/loop-spec log:*)"
  "${WORKSPACE_READ[@]}" "mcp__${WORKSPACE_MCP}__get_work_context"
  "mcp__${WORKSPACE_MCP}__add_comment" "mcp__${WORKSPACE_MCP}__update_task"
  "mcp__claude_ai_gitlab__get_repository_file" "mcp__claude_ai_gitlab__list_repository_tree"
  "mcp__claude_ai_gitlab__get_merge_request" "mcp__claude_ai_gitlab__list_merge_requests"
  "mcp__claude_ai_gitlab__get_commit" "mcp__claude_ai_gitlab__list_commits" "mcp__claude_ai_gitlab__search"
)
DESIGNER_DENY=(
  "${DENY_COMMON[@]}" "${WORKSPACE_DENY[@]}" "NotebookEdit"
  "Bash(git push:*)" "Bash(git commit:*)" "Bash(git add:*)" "Bash(git checkout:*)" "Bash(git switch:*)"
  "Bash(~/loop/bin/loop-spec approve:*)" "Bash($HOME/loop/bin/loop-spec approve:*)"
  "Bash(~/loop/bin/loop-spec part:*)" "Bash($HOME/loop/bin/loop-spec part:*)"
  "Bash(~/loop/bin/loop-spec feedback:*)" "Bash($HOME/loop/bin/loop-spec feedback:*)"
  "mcp__${WORKSPACE_MCP}__transition_task" "mcp__${WORKSPACE_MCP}__start_work"
  "mcp__${WORKSPACE_MCP}__finish_work" "mcp__${WORKSPACE_MCP}__update_work_state"
  "mcp__${WORKSPACE_MCP}__add_task_link"
)

# Opens a Claude Code background session in $folder; `claude agents` lists it and `claude attach` opens it.
# The caller sets SESSION_ALLOW and SESSION_DENY first.
open_session() {
  local name="$1" folder="$2" mode="$3" command="$4" dirs=("$LOOP_DIR") line out id
  while IFS= read -r line; do [ -n "$line" ] && dirs+=("$line"); done <<< "${SESSION_DIRS:-}"
  out=$(cd "$folder" && claude --bg -n "$name" --model opus --effort medium --permission-mode "$mode" \
    --add-dir "${dirs[@]}" --allowedTools "${SESSION_ALLOW[@]}" --disallowedTools "${SESSION_DENY[@]}" \
    -- "$command" < /dev/null 2>&1)
  id=$(printf '%s\n' "$out" | sed -n 's/^backgrounded · \([^ ]*\) · .*/\1/p' | head -n 1)
  if [ -z "$id" ]; then
    printf '%s\n' "$out" | grep . | tail -n 1
    return 1
  fi
  if show_session "$name" "$folder" "$id"; then
    echo "background session '$name' (claude attach $id), shown in herdr space '$name'"
  else
    echo "background session '$name' (claude attach $id)"
  fi
}

show_session() {
  local name="$1" folder="$2" id="$3" tab="worker" json
  case "$name" in design\ *) tab="designer" ;; esac
  command -v herdr-app >/dev/null 2>&1 || return 1
  herdr-app status >/dev/null 2>&1 || return 1
  json=$(python3 -I -c 'import json, sys
print(json.dumps({"name": sys.argv[1], "folder": sys.argv[2], "tab": sys.argv[3], "argv": ["claude", "attach", sys.argv[4]]}))' "$name" "$folder" "$tab" "$id")
  herdr-app do space.new "$json" >/dev/null 2>&1
}

start_designer() {
  local task="$1" repos="$2" risk="${3:-?}" repo repo_dir base where first_dir="" other_dirs="" verb
  SESSION_ALLOW=("${DESIGNER_ALLOW[@]}")
  for repo in ${repos//,/ }; do
    if ! read -r repo_dir base < <("$STATE" repo "$repo" 2>/dev/null) || [ -z "$base" ]; then
      log "## $NOW designer skipped — unknown repo '$repo' for $task (add it to $LOOP_DIR/repos)"
      return
    fi
    git -C "$repo_dir" fetch -q origin "$base" 2>/dev/null
    if [ -z "$first_dir" ]; then first_dir="$repo_dir"; continue; fi
    other_dirs="$other_dirs$repo_dir"$'\n'
    for verb in show diff log status rev-parse ls-files ls-tree grep; do
      SESSION_ALLOW+=("Bash(git -C $repo_dir $verb:*)")
    done
  done
  if ! "$SPEC" start "$task" "$repos" "$risk" 2>/dev/null; then
    log "## $NOW designer skipped — $task: design is $("$SPEC" status "$task")"
    return
  fi
  DID=1
  SESSION_DENY=("${DESIGNER_DENY[@]}")
  SESSION_DIRS="$other_dirs"
  if where=$(open_session "design $task" "$first_dir" "dontAsk" "/loop-design $task $repos $risk"); then
    log "## $NOW designer started $task ($repos, risk:$risk) — $where" "package: $("$SPEC" path "$task")" ""
    notify "Designer เริ่ม $task ($repos, risk:$risk)"
  else
    "$SPEC" block "$task" "could not open a background session: $where"
    log "## $NOW designer FAILED — $task: could not open a background session: $where" ""
    notify "เปิด Designer session ไม่ได้ ($task)"
  fi
  SESSION_DIRS=""
}

start_worker() {
  local task="$1" repo="$2" risk="${3:-?}" repo_dir base wt branch where
  if ! read -r repo_dir base < <("$STATE" repo "$repo" 2>/dev/null) || [ -z "$base" ]; then
    log "## $NOW worker skipped — unknown repo '$repo' for $task (add it to $LOOP_DIR/repos)"
    return
  fi
  if [ "$repo" = "$RELEASE_REPO" ] && [ "$MERGE_BACK_PENDING" != "0" ]; then
    log "## $NOW worker skipped — $task: $RELEASE_REPO merge-back master → staging pending ($MERGE_BACK_PENDING commits)"
    return
  fi
  if "$STATE" get "$task" >/dev/null; then
    log "## $NOW worker skipped — $task already handled ($("$STATE" get "$task" status))"
    return
  fi

  wt=$("$STATE" path "$repo" "$task")
  if [ -e "$wt" ]; then
    log "## $NOW worker skipped — $task: $wt already exists (remove it, or finish the task by hand)"
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
  "$STATE" set "$task" working repo="$repo" branch="$branch"
  DID=1
  SESSION_ALLOW=("${WORKER_ALLOW[@]}")
  SESSION_DENY=("${WORKER_DENY[@]}")
  if where=$(open_session "loop $task" "$wt" "dontAsk" "/loop-work $task $repo $risk"); then
    log "## $NOW worker started $task ($repo, risk:$risk) — $where" "worktree: $wt" ""
    notify "Worker เริ่ม $task ($repo, risk:$risk)"
  else
    "$STATE" set "$task" blocked
    log "## $NOW worker FAILED — $task: could not open a background session: $where" ""
    notify "เปิด Worker session ไม่ได้ ($task)"
  fi
}

STARTED=0
while read -r TASK REPO RISK; do
  [ -z "$TASK" ] && continue
  spec_ready "$TASK" || { log "## $NOW worker skipped — $TASK: no ready spec in $SPECS"; continue; }
  [ "$STARTED" -ge "$SLOTS" ] && { log "## $NOW worker skipped — $TASK: no free Worker slot"; continue; }
  start_worker "$TASK" "$REPO" "$RISK"
  STARTED=$((STARTED + 1))
done <<< "$PICKS"

while read -r TASK REPO RISK; do
  [ -z "$TASK" ] && continue
  [ "$(designing_in "$(space_of "$TASK")")" -ge "$MAX_DESIGNERS" ] && { log "## $NOW designer skipped — $TASK: no free Designer slot in $(space_of "$TASK")"; continue; }
  start_designer "$TASK" "$REPO" "$RISK"
  DESIGNING_KEYS=$("$SPEC" list designing | cut -d' ' -f1)
done <<< "$DESIGN_PICKS"
exit 0
