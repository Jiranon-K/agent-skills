---
name: loop-board
description: Shows where every Loop Engineering task stands right now, grouped by stage (needs a grill, designing, design waits for the owner, waits for a Worker, Worker running, blocked, MR open and waits for verify, merged), as box art in the terminal and as a Claude Artifact republished to one URL. Flags sources that disagree. Read-only. Usage `/loop-board`.
---

# Loop Board

One picture of the Loop now: every task it has touched, in the stage it is in, and what the owner must do next. Reply in Thai, per `~/.claude/rules/explanation-style.md`. Run inline; no subagents.

**Read-only.** Never write Workspace, GitLab, `loop-state`, `loop-spec` or the `loop-summary` marker. The only files written are `~/loop/state/board.json`, `~/loop/state/board.html` and `~/loop/state/board-artifact-url`. Never call Workspace: card links use the key.

## 1. Read the sources

Run these in one message:

- `~/loop/bin/loop-state list` → `<task> status=… repo=… [branch=…] [mr=…] [ui=…]`
- `~/loop/bin/loop-spec list` → `<task> <design status> repo=… risk=…`
- The table under `### ต้อง grill ก่อน Agent เริ่มได้` in `~/loop/state/last-triage.md` (its task cells are links already; keep them). "ไม่มี" means none.
- `~/.local/bin/herdr-core ls` → JSON; each terminal's `where` is `<role> <task> / <tab>` (`loop` = Worker, `design` = Designer, `e2e`), with `agent` and `status`.
- The task URL base in `~/loop/workspace.md`. Link a card as `<base>/tasks/<KEY>`.

Then, for each `loop-state` task with `mr=`, in one message: from `https://<host>/<path>/-/merge_requests/<n>` run `glab mr view <n> -R <host>/<path> -F json` and keep `state`, `draft`, `labels`, `title`. A failed call is a mismatch line (`อ่าน MR ไม่ได้: <error>`), never a guess.

## 2. Put each task in one stage

One source decides each stage. A task appears once, in the first stage that matches, in this order:

| # | stage | owner acts | source and rule |
|---|---|---|---|
| 1 | ต้อง grill | | a row of the triage grill table |
| 2 | Designer กำลังทำ | | `loop-spec` `designing` or `redo` |
| 3 | design ติด | | `loop-spec` `blocked` |
| 4 | รอ owner review design | ★ | `loop-spec` `proposed`; next `/loop-design-review <task>` |
| 5 | รอ Worker | | `loop-spec` `approved` and no `loop-state` entry |
| 6 | Worker กำลังทำ | | `loop-state` `working` |
| 7 | blocked | | `loop-state` `blocked` |
| 8 | เปิด MR แล้ว รอ verify | ★ | `loop-state` `mr-open` or `ready-to-ship`; see below |
| 9 | merge แล้ว รอ archive | | `loop-state` `merged` |

Where a task is in both `loop-spec` and `loop-state`, `loop-state` decides (stages 6 to 9 win over 2 to 5). `split` designs are not shown.

Stage 8 sub-state, in the card's `note`, from the MR:
- `ready-to-ship` → `repo นี้ห้าม agent push: owner push เอง` and next is `git -C <main checkout> push -u origin <branch>` (checkout from `loop-state repo <repo>`), then `~/loop/bin/loop-mr <task>`.
- label `needs:e2e` → `รอ e2e` and next `/loop-e2e <task>`.
- otherwise label `needs:human-verify` → `รอ human verify` and next `/merge-approved <task>`.

herdr never decides a stage. A live terminal whose `where` names the task becomes the card's `session`: `<role> <status>` (`worker done`, `designer working`), or `<role> shell` when `agent` is not `claude-code`.

## 3. Find disagreements

Add one mismatch line per case, saying what each source says and the command to look. Do not fix anything.

- MR `state` is `merged` or `closed` but `loop-state` is not `merged`.
- `loop-state` `merged` but the MR is `opened`.
- `mr-open` MR is not a Draft, or lacks `needs:human-verify`.
- A `loop` Worker terminal is `working` for a task whose `loop-state` is not `working`, or `loop-state` is `working` with no live Worker terminal.
- `loop-spec` `designing` with no live `design` terminal for the task.
- A grill-table task that is also in `loop-state` or `loop-spec` as `approved`.

## 4. Write the data and render

Write `~/loop/state/board.json` with the `Write` tool:

```json
{
  "generated": "<date '+%Y-%m-%d %H:%M'>",
  "stages": [
    {"id": "grill", "label": "ต้อง grill", "owner": false, "tasks": [
      {"key": "APP-12", "url": "<card link>", "title": "<MR or grill topic>", "repo": "web", "risk": "medium",
       "mr": "<MR URL>", "draft": true, "labels": ["needs:e2e"], "session": "worker done",
       "note": "รอ e2e", "next": "/loop-e2e APP-12"}
    ]}
  ],
  "mismatches": [{"task": "APP-12", "text": "loop-state: mr-open · MR: merged · ดู loop-state get APP-12"}]
}
```

All nine stages, in order, even when empty. Omit a task field that has no value. For a grill row, `title` is the topic and `note` is `ถาม <who>`.

Render the page next to this skill:

```bash
python3 -I -c 'import json,sys; t=open(sys.argv[1]).read(); d=json.load(open(sys.argv[2])); open(sys.argv[3],"w").write(t.replace("__BOARD_DATA__", json.dumps(d, ensure_ascii=False).replace("</","<\\/")))' ~/.claude/skills/loop-board/board.html ~/loop/state/board.json ~/loop/state/board.html
```

## 5. Publish

- `~/loop/state/board-artifact-url` exists → `Artifact` `read` that URL once (a publish to an artifact this session has not read is refused), then publish `~/loop/state/board.html` with that `url`.
- Missing → publish `~/loop/state/board.html` with `icon: "board"` and description `Where every Loop task stands now, by stage.`, then write the returned URL to `~/loop/state/board-artifact-url`.

A failed publish does not stop the reply: say so in one line.

## 6. Reply in the terminal

Box art, stages with tasks only, in stage order. ★ stages first line of the reply when not empty, so what the owner must do leads:

```
★ รอคุณ 3 task
┌ ★ เปิด MR แล้ว รอ verify (2) ─────────────────────────────
│ APP-12  web  !519 Draft  รอ e2e          /loop-e2e APP-12
│ APP-14  web  !517 Draft  รอ human verify /merge-approved APP-14
└───────────────────────────────────────────────────────────
┌ Worker กำลังทำ (1) ───────────────────────────────────────
│ APP-20  api  session worker working
└───────────────────────────────────────────────────────────
```

Then `⚠ ไม่ตรงกัน` lines when there are any, then the Artifact link on the last line. Keys stay plain inside the box art, since a code block shows links raw; the Artifact carries the links. Nothing else: no summary that repeats the board.
