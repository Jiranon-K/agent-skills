---
name: loop-explain
description: Explains one or more Loop Engineering tasks to the owner from the record (card, comments, approved spec, design package, decisions, commits, MR) in six plain Thai headings, ปัญหา / วิธีแก้ / เราแก้ / ผลลัพธ์ที่ได้ / ติดไรไหม / step ต่อไป, citing sources and marking inferences. Read-only. Usage `/loop-explain <task> [<task>...]`.
---

# Loop Explain

Tell the owner what one Loop task is about and where it stands, from what was written down, not from memory. Read-only: never write Workspace, GitLab, `loop-state`, `loop-spec` or any file.

No task key given → ask for one in one line. Several keys → one block per task, in the order given.

## pstack

The pstack skills live under `~/loop/pstack/skills/<name>/SKILL.md`. The `Skill` tool refuses them: `Read` the file and follow it. Read `~/loop/pstack/docs/harness/claude-code.md` once before the first one. Model roles come from `~/.claude/rules/pstack-models.md`.

This skill is pstack **why** (answer from the record, cite it, mark inferences, say what the record does not answer) written through **teach**, **bro** and **unslop**, in Thai per `~/.claude/rules/pstack-thai.md` and `~/.claude/rules/explanation-style.md`. Keep `why`'s confidence language when you reword.

## 1. Gather the record (one subagent per task)

Dispatch one `Agent` per task, all in one message: `subagent_type: "Explore"`, model and effort from the `why investigators` role. The brief names the task and these sources, in this order:

1. Loop state: `~/loop/bin/loop-state get <task>` (status, repo, branch, mr) and `~/loop/bin/loop-spec status <task>`.
2. The approved spec `~/loop/specs/<task>.md`.
3. The design package `$(~/loop/bin/loop-spec path <task>)`: `spec.md`, `design.md`, `grounding.md`, `decisions.tsv`, `feedback` if present. When the package is gone, look in `~/Home/docs/loop/archive/*/<task>/`.
4. Workspace: `get_work_context` and `list_comments` for the task (read tools only). The Worker's handoff comment starts with `🤖 [loop-status]`.
5. The MR from `mr=`: `glab mr view <n> -R <host>/<path> -F json` (from `https://<host>/<path>/-/merge_requests/<n>`) for state, Draft, labels, description; `glab mr view <n> -R <host>/<path> --comments` for discussion.
6. Commits: `git -C <main checkout> log --oneline origin/<base>..origin/<branch>` (checkout and base from `loop-state repo <repo>`); after a merge, `git -C <main checkout> log --oneline --grep <task> -20 origin/<base>`.
7. `~/loop/summaries/*.md` sections that name the task.

The brief also says: do not edit, create or delete any file; do not run any write command (`loop-state set`, `loop-spec` writes, `glab mr update`, `git` writes, Workspace writes); never read `.env*` or credentials. Return facts only, each with its source (`file:line`, comment date and author, MR note, commit sha), grouped under the six headings below, plus a list of sources that were missing or failed. Mark anything the subagent concluded rather than read as `inference`.

Afterwards check `git -C <main checkout> status --short` is unchanged.

## 2. Write the answer

One block per task, in Thai, in this exact shape:

```
### [<KEY> <title>](<card link>)
**ปัญหา:** <what was wrong or missing, from the user's side, 1–2 sentences>
**วิธีแก้:** <the approach the approved design chose, and the one alternative it rejected if the record says why>
**เราแก้:** <what the change actually does: files or parts touched, 2–4 bullets>
**ผลลัพธ์ที่ได้:** <what was proven: tests, e2e, review findings, numbers as run>
**ติดไรไหม:** <blockers, deviations from the design, open review findings, or "ไม่ติด">
**step ต่อไป:** <who acts next and the exact command or person>
```

- Card link: the task URL base in `~/loop/workspace.md`, as `<base>/tasks/<KEY>`.
- Cite inline and briefly: `(spec AC 2)`, `(design.md)`, `(decisions.tsv: review)`, `(MR !519)`, `(comment 19 พ.ย. owner)`, `(abc1234)`.
- An inference gets `น่าจะ` and `(อนุมาน)`. When the record does not answer a heading, write `record ไม่ได้บอก` and name what is missing, rather than filling it in.
- `step ต่อไป` follows the stage: design `proposed` → `/loop-design-review <task>`; MR with `needs:e2e` → `/loop-e2e <task>`; MR with `needs:human-verify` → verify, then `/merge-approved <task>`; `ready-to-ship` → the owner pushes; `blocked` → who to ask and the question from the comment; `merged` → `loop-clean` archives it.
- When the fix has three or more moving parts, add one short series of box diagrams after `เราแก้`, each redrawing the last and adding one part (box art, not mermaid).
- Smallest complete answer: no intro, no closing summary. Offer to go deeper in one line at the end only if there is more in the record worth reading.
