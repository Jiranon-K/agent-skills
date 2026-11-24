---
name: loop-board
description: Shows where every Loop Engineering task stands right now, grouped by stage (in the sprint but not in the Loop yet, needs a grill, designing, design waits for the owner, waits for a Worker, Worker running, blocked, MR open and waits for verify, merged), as left-to-right box art in the chat. Flags sources that disagree. Read-only. Usage `/loop-board`.
---

# Loop Board

One picture of the Loop now: every task it has touched, in the stage it is in, and what the owner must do next. Reply in Thai, per `~/.claude/rules/explanation-style.md`. Run inline; no subagents.

**Read-only.** Writes nothing: no files, no Artifact, no Workspace, GitLab, `loop-state`, `loop-spec` or `loop-summary` marker. The only Workspace call is the read-only `query_view` for the sprint below; card links use the key.

**Current sprint only.** The board shows a task only when it is in its space's current sprint, or its key is in the `workspace.md` list "Out-of-sprint tasks the owner asked for". Every other task is left out: no card, no mismatch line, no count.

## 1. Read the sources

Run these in one message:

- `~/loop/bin/loop-state list` → `<task> status=… repo=… [branch=…] [mr=…] [ui=…]`
- `~/loop/bin/loop-spec list` → `<task> <design status> repo=… risk=…`
- The table under `### ต้อง grill ก่อน Agent เริ่มได้` in `~/loop/state/last-triage.md` (its task cells are links already; keep them). "ไม่มี" means none.
- `/Applications/Orca.app/Contents/Resources/bin/orca agent list --json` → `result.agents`, the live sessions; a session's `title` starts with `<role> <task>` (`loop` = Worker, `design` = Designer), followed by ` · <note>` once its status changed, and `state` is `working`, `waiting`, `blocked` or `done`. Match a session by that start of its title: every session shares one `worktreeId`, the Orca workspace.
- The task URL base, the "Current sprint" table and the list "Out-of-sprint tasks the owner asked for" in `~/loop/workspace.md`. Link a card as `<base>/tasks/<KEY>`.
- Per space in that table: `query_view` `space=<key>`, `sprint=<id>`, `assignee=me`, `view_type=table`, `group=none`. The keys it returns, plus the owner's list, are the sprint keys. The same call with `open=true` added gives the open sprint tasks; keep each one's `status` and `route`. A failed call means the board cannot be filtered: say so in one line above the board and show every task.

Then, for each `loop-state` task with `mr=`, in one message: from `https://<host>/<path>/-/merge_requests/<n>` run `glab mr view <n> -R <host>/<path> -F json` and keep `state`, `draft`, `labels`, `title`. A failed call is a mismatch line (`อ่าน MR ไม่ได้: <error>`), never a guess.

## 2. Put each task in one stage

Drop every task whose key is not a sprint key before placing it. One source decides each stage. A task appears once, in the first stage that matches, in this order:

| # | stage | owner acts | source and rule |
|---|---|---|---|
| 0 | ใน sprint ยังไม่เข้า loop | | an open sprint task that matches no stage below and is not a `split` design |
| 1 | ต้อง grill | | a row of the triage grill table |
| 2 | Designer กำลังทำ | | `loop-spec` `designing` or `redo` |
| 3 | design ติด | | `loop-spec` `blocked` |
| 4 | รอ owner review design | ★ | `loop-spec` `proposed`; next `/loop-design-review <task>` |
| 5 | รอ Worker | | `loop-spec` `approved` and no `loop-state` entry |
| 6 | Worker กำลังทำ | | `loop-state` `working` |
| 7 | blocked | | `loop-state` `blocked` |
| 8 | เปิด MR แล้ว รอ verify | ★ | `loop-state` `mr-open` or `ready-to-ship`; see below |
| 9 | merge แล้ว รอ archive | | `loop-state` `merged` |

Where a task is in both `loop-spec` and `loop-state`, `loop-state` decides (stages 6 to 9 win over 2 to 5). `split` designs are not shown. A stage 0 task's `note` says why the Loop has not taken it, from its route and status: `route human`, `ยังไม่ triage` (no route), `อยู่ Triage`, `route agent แต่อยู่ <status>` when its status is not the space's "Pick from" status in `workspace.md`, or `route agent รอ Designer slot`. It has no `next`.

Stage 8 sub-state, in the card's `note`, from the MR:
- `ready-to-ship` → `repo นี้ห้าม agent push: owner push เอง` and next is `git -C <main checkout> push -u origin <branch>` (checkout from `loop-state repo <repo>`), then `~/loop/bin/loop-mr <task>`.
- label `needs:e2e` → `รอ e2e` and next `/loop-e2e <task>`.
- otherwise label `needs:human-verify` → `รอ human verify` and next `/merge-approved <task>`.

A session never decides a stage. A live session whose `name` names the task becomes the card's `session`: `<role> <state>` (`worker done`), opened from the Orca sidebar.

## 3. Find disagreements

Add one mismatch line per case, saying what each source says and the command to look. Do not fix anything.

- MR `state` is `merged` or `closed` but `loop-state` is not `merged`.
- `loop-state` `merged` but the MR is `opened`.
- `mr-open` MR lacks `needs:human-verify`, or `~/loop/bin/loop-verdict <task> check` does not print `current PASS` or `current PASS+NOTES`.
- A `loop` Worker terminal is `working` for a task whose `loop-state` is not `working`, or `loop-state` is `working` with no live Worker terminal.
- `loop-spec` `designing` with no live `design` terminal for the task.
- A grill-table task that is also in `loop-state` or `loop-spec` as `approved`.

## 4. Reply in the chat

The board is the reply. Stages with tasks only, as columns read left to right in stage order, so the flow from not-yet-in-the-Loop to merged runs across the screen. At most 3 columns per row; a fourth non-empty stage starts a new row of columns below. Each column is 30 cells wide; pad by display width (Thai vowel and tone marks take no cell). One task is one block of lines in its column with no blank line between tasks: the key and repo on the first line, then MR and note, next and session as lines indented by two spaces, skipping lines with no value. Shorten a long topic or title to fit, never widen the column.

A `★` stage marks its header. When any ★ stage has tasks, the first line of the reply, above the board, is `★ รอคุณ <n> task`.

```
★ รอคุณ 2 task
┌ Worker กำลังทำ (1) ──────────┐┌ ★ เปิด MR รอ verify (2) ─────┐┌ merge แล้ว (1) ──────────────┐
│ APP-20  api                  ││ APP-12  web                  ││ APP-9   web  !510            │
│   session worker working     ││   !519  รอ e2e               ││                              │
│                              ││   /loop-e2e APP-12           ││                              │
│                              ││ APP-14  web                  ││                              │
│                              ││   !517  human verify         ││                              │
│                              ││   /merge-approved APP-14     ││                              │
└──────────────────────────────┘└──────────────────────────────┘└──────────────────────────────┘
```

Column labels may be shortened to fit (`เปิด MR รอ verify`, `merge แล้ว`). For a grill task the first line is the key and `ถาม <who>`, the second the topic. A merged task is one line: key, repo, MR number.

Keys stay plain inside the box art, since a code block shows links raw. Below the board, `⚠ ไม่ตรงกัน` lines when there are any, with each task key as a card link. Nothing else: no summary that repeats the board.
