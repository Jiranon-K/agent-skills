---
name: loop-work
description: Worker of the Loop Engineering system. Runs in its own herdr session inside a prepared git worktree, takes one Workspace task end to end — claim, implement with Sonnet subagents, verify, independent review, fix, Draft MR, handoff comment — and records state with loop-state. Started by ~/loop/bin/loop-run.sh; usage `/loop-work <task key> <repo key> <risk>`.
---

# Loop Worker

Arguments: `<task key> <repo key> <risk>`, e.g. `APP-39 web-app medium`.
You run in a visible session the owner may watch or steer, but do not wait for answers: when something is unclear, stop as **blocked** (step 9). Never guess.

Read first: `~/loop/workspace.md` (tracker facts), the repo's section in `~/Home/docs/repo-map.md`, then the repo's own `AGENTS.md` / `CLAUDE.md` and the docs they point to. The repo's rules win over this skill, except where this skill says the loop's MR is a Draft.

## Hard rules

- Work only in the current directory. It must be the path `~/loop/bin/loop-state path <repo> <task>` prints; if not, stop blocked: `not in a loop worktree`.
- Never read, print or edit `.env*`, `.npmrc` or any secret. Never touch production config or credentials. Write migrations as code if the task needs one, but never run a migration or backfill against a real database.
- Never force-push, merge, rebase or reset. Push only with `~/loop/bin/loop-push` (no arguments: it pushes the current feature branch and refuses protected branches); plain `git push` is denied.
- Stay in the task's scope. No unrelated refactors. Never touch another person's task or feature directory.
- Run every heavy command (test suite, build, `./init.sh`, e2e) through `~/loop/bin/loop-heavy <command>`: other Workers share this 8 GB machine. Before you finish, make sure no test runner, headless browser or dev server you started is still running.
- If the same verification fails after 2 fix attempts, stop blocked with the failing command and error summary.
- Workspace writes: only this task, through `start_work`, `update_work_state`, `transition_task`, `add_task_link`, `add_comment`, `finish_work`, and `update_task` for labels (replace-all: keep every existing label). Never write the description, title, assignee or priority.

## Models

You orchestrate (Opus). Delegate implementation to `Agent` subagents with `model: "sonnet"` and give each one a complete brief: task, acceptance criteria, files, repo rules, the TDD order, and the hard rules above (no `.env*`, no deletes outside the change, `loop-heavy` for heavy commands). Use `model: "haiku"` only for cheap lookups (finding files, summarizing a log). Review runs in the `loop-reviewer` agent (step 6).

## Steps

1. **Read the task**: `get_work_context <task>` (space guidance, epic, description, comments, links). Re-check it is clear: acceptance criteria stated, no open question, no unfinished blocker. If not, stop blocked with the question.
2. **Claim**: `start_work <task>` (note: "Loop Worker started"), then `transition_task` to the space's "Working" status from `workspace.md` (ids from `list_spaces`). If `start_work` fails because another session holds the task, stop without changes and run `~/loop/bin/loop-state set <task> blocked` with the reason in your final message.
3. **Branch**: the worktree is already on a branch `loop/<task-lowercase>` cut from the latest base. Rename it to the repo's convention with `git branch -m <name>` (e.g. web-app `<type>/<task>-<slug>`, project-b `feat/<task-lowercase>-<slug>`); use the Workspace key (`APP-39`, `PB-217`) wherever the repo asks for a ticket key. Then do the repo's start-of-work steps from its docs (web-app: the Feature Workflow `status.json` claim and progress file; run `./init.sh` first where the repo has one). Install dependencies only if missing, with the repo's package manager.
4. **Implement**: test first (failing test, red, implement, green) through Sonnet subagents. Use the repo's `tdd` skill and stack skill when it has them.
5. **Verify** with the repo's real verify commands from `repo-map.md` (wrapped in `loop-heavy`). Keep the exact commands and results. Commit per the repo's convention; end each commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. `update_work_state working` with a one-line note after each milestone.
6. **Review**: run the `loop-reviewer` agent (`Agent` with `subagent_type: "loop-reviewer"`) with the base ref `origin/<base>` and the task's acceptance criteria. It returns findings only.
7. **Fix** every `blocking` and `major` finding; for each one you decline, write one line why. Re-run step 5's verification and commit.
8. **Deliver**:
   - **Remote allowed?** If the repo's `AGENTS.md` / `CLAUDE.md` still says agents must not reach a remote (push or MR), do not push: go to "Local delivery" below.
   - Push: `~/loop/bin/loop-push` (web-app: `.harness/scripts/ship.sh --yes` does push and MR; follow its feature-record steps first).
   - Open the MR as a **Draft** into the base branch with the repo's MR template: `glab mr create --draft --target-branch <base> --title ... --description ... --label "owner:you,needs:human-verify"` (add `needs:e2e` when the change has UI; project-b repos take `-R` from `workspace.md`). If a script opened the MR, make it a Draft and add the labels with `glab mr update <n> --draft --label ...`. Confirm with `glab mr view <n>` that it is a Draft and the labels are there.
   - Workspace: `add_task_link <task> <MR URL>`, `transition_task` to the "MR open" status, then post the handoff comment (below), then `finish_work <task> done "<one line>"`.
   - `~/loop/bin/loop-state set <task> mr-open branch=<branch> mr=<MR URL> ui=<yes|no>`.
   - **Local delivery** (remote not allowed): commit everything, write the MR title and description to `~/loop/state/mr-draft-<task>.md`, post the handoff comment with "MR (Draft): ยังไม่เปิด — repo นี้ห้าม agent push" and the exact `git push` / `glab mr create --draft` commands for the owner, `finish_work <task> done`, leave the status at "Working", and run `~/loop/bin/loop-state set <task> ready-to-ship branch=<branch> ui=<yes|no>`.
9. **Blocked** at any point: `update_work_state awaiting_input` with the reason, post a question comment in the format of the `loop-triage` skill (mention only the assignee; name who to ask if known), add label `needs:human`, set `route=human`, `finish_work <task> error "<reason>"`, and `~/loop/bin/loop-state set <task> blocked`. Leave the status where it is.

## Handoff comment (Thai, for a human; mention only the assignee)

```
🤖 [loop-status] Loop ทำเสร็จ รอ human verify · [@<assignee name>](mention:member/<assignee id>)
**ผลลัพธ์** — <1–2 ประโยค มองจากมุมผู้ใช้>
**เปลี่ยนอะไร** — <2–4 bullet>
**ตรวจแล้ว** — <lint ✅ · test N/N ✅ · build ✅ ตามที่รันจริง>
**ปัญหาที่เจอ → แก้ยังไง** — <หรือ "ไม่มี">
**ความเสี่ยง / ควรระวัง** — risk:<x> · <สิ่งที่อาจกระทบ>
**ขอให้ช่วยดู** — <ไฟล์หรือการตัดสินใจที่ต้องใช้คนดู หรือ "ไม่มี">
**ขั้นตอนต่อไป**
☐ 1. <วิธีเช็คด้วยมือ ทำอะไร → ต้องเห็นอะไร>
☐ 2. ...
ผ่าน → สั่ง /merge-approved <task> (เอา Draft ออกให้เอง) · ไม่ผ่าน → ปิด MR แล้วรับงานต่อเอง (หรือสั่ง Loop ให้แก้)
MR (Draft): <url>
```

## Final message

End the session with one line: `RESULT: mr-open <url>` | `RESULT: ready-to-ship <branch>` | `RESULT: blocked: <reason>`.
