---
name: loop-reflect
description: Weekly learning pass of the Loop Engineering system. Reads the week's Worker and Designer sessions, blocked reasons, design pushbacks and dropped review findings, and proposes concrete edits to the loop skills for the owner to approve. Never edits a skill without approval. Run by the owner, usually on Fridays: `/loop-reflect [<days>]`.
---

# Loop reflect

Find what made the Loop stop, redo or mislead this week, and turn each repeat into one proposed edit. Talk in Thai. Default window: the last 7 days.

## Gather (read-only)

1. `~/loop/logs/<date>.md` for each day in the window: every `FAILED`, `skipped` and `blocked` line.
2. `~/loop/bin/loop-state list` and `~/loop/bin/loop-spec list`: tasks that are `blocked`, designs that are `redo` or `blocked`.
3. Per design package touched in the window (`~/loop/designs/<task>/`, and `~/loop/archive/<month>/<task>/` for tasks that finished): `feedback.md` (what the owner or a Worker pushed back on), `blocked.md`, and `decisions.tsv` rows whose result is a revert, a scrap or `dropped`.
4. Session transcripts of the loop's sessions in the window: `~/.claude/projects/<slug>/*.jsonl`, where the slug is a Worker worktree path (`…-claude-worktrees-<task>`, or `…-claude-worktrees-loop-<n>` for older tasks) or a repo's main checkout running `/loop-design`. Read only sessions whose first user message starts with `/loop-work` or `/loop-design`. Never read any other session. From each, list every tool call that was denied for permission (the tool or command, and what the session did next), and every `needs permission:` block.
5. Merged loop MRs in the window (`loop-state list merged`): what the owner changed after the Draft opened, from `glab mr view <n> --comments` and the commits after the Worker's last one.

Give steps 3–5 to subagents, one per task, and keep only their findings: each finding is one line with the task key and a pointer (file, log line or transcript path).

## Judge

Follow the pstack **reflect** skill's stance (`~/loop/pstack/skills/reflect/SKILL.md`; the `Skill` tool refuses it, so `Read` it): one-offs are not learnings. Keep a finding only when it happened on two or more tasks, or once with a cost of a redo or a wrong MR. For each kept finding decide where the fix belongs, in this order:

1. A script or permission that makes the mistake impossible (`loop-spec`, `loop-state`, the deny lists in `loop-run.sh`).
   Sessions ask for no permission, so the lists are `WORKER_DENY` and `DESIGNER_DENY`. A session that did something it should not have (wrote outside its worktree, changed a shared file, ran a destructive command) on two or more tasks, or once with a cost, becomes a proposal: add the narrowest deny rule (name the rule and what it stops). A denied call that blocked a task becomes a skill line that names the allowed way, or a script with its own guard. Never propose a rule that lets a session push, merge, approve a spec or read a secret.
2. A line in one loop skill (`loop-triage`, `loop-design`, `loop-work`, `loop-review`).
3. A line in a repo's own docs or `~/Home/docs/repo-map.md` when the lesson is about that repo.

## Report and wait

Show one table: finding · evidence · seen on · proposed edit (file and the exact new text) · why this place. Then the numbers for the week: designs proposed, approved first time, redone; MRs opened, merged, reworked after review; tasks blocked and why.

Save the report as `~/loop/reflect/<ISO year>-W<week>.md` (`date +%G-W%V`), in English, with the owner's choices added once they are made.

Wait for the owner to pick which edits to apply. Apply only those, in `~/Home/agent-skills` and in the installed copy under `~/.claude/skills/`, then run `~/Home/agent-skills/loop/test/loop-spec.test.sh` and `loop-state.test.sh` when a script changed. Never commit or push.
