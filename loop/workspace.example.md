# Loop tracker config (template: copy to ~/loop/workspace.md and fill in)

Every loop skill reads this file for tracker facts. The skills keep the logic; this file keeps the values.

## Tracker

- Tracker: your Workspace tracker, MCP server `workspace` (tools `mcp__workspace__*`).
- Task URL: `https://workspace.example.com/tasks/<task id>` (the cuid `id`, not the key).
- Mention: `[@<name>](mention:member/<member id>)`. Take name and id from the task's `assignee`; never hardcode them.
- Comments posted through MCP carry the owner's own name, so a loop comment is told apart only by its first line starting with `🤖 [loop-status]`.
- Comments cannot be edited through MCP yet (bug reported). Post a new loop comment only when something happens; never post the same state twice.

## Spaces

Status names per step. Look the ids up with `list_spaces` by name.

| Space | Product | Pick from | Working | MR open | After merge |
|---|---|---|---|---|---|
| APP | project-a | Ready | In Progress | In Review | Verifying |
| PB | project-b | Todo | In Progress | In Review | Done |

Tasks in the `Triage` status are not ready: never route or pick them.

## Current sprint (the Loop works only inside it)

Only tasks in the space's current sprint are routed, commented on or picked. Everything else is a status row.

| Space | Sprint id | Name | Ends |
|---|---|---|---|
| APP | `<sprint id>` | 1.2.0 · 25 Nov | the release date in the name |
| PB | `<sprint id>` | 2026-W46 | Sunday of that ISO week |

Read a sprint's tasks with `query_view` `space=<key>`, `sprint=<id>`, `assignee=me`, `open=true`. Always use the listed sprint; never switch on your own. When its end has passed (APP names carry the release date, PB names are ISO weeks), keep using it and add one line to the report: `sprint <name> จบแล้ว — อัปเดต ~/loop/workspace.md` (name the next sprint and its id if an open task carries one).

## Labels the loop writes

- `risk:low|medium|high`, and `type:<x>` only when the task has no `type:` label yet (APP uses `type:story`, `type:bug`, `type:feature`, `type:chore`, `type:docs`, `type:test`).
- `repo:<GitLab repo name>` when the task has none and the repo is certain (see `~/Home/docs/repo-map.md`).
- `needs:human` when a question blocks the work.
- Never write `release:`, `area:`, `cos:` or customer labels.

## GitLab

- project-a repos: `gitlab.com`, group `project-a`. glab's account there is shared, so every loop MR carries `owner:you`.
- project-b repos: `gitlab.example.com`, group `example-team` (pass `-R gitlab.example.com/example-team/<repo>`).
- Loop MR labels: `owner:you,needs:human-verify` (plus `needs:e2e` for UI changes). Loop MRs are always Drafts.

## Repos

`~/Home/docs/repo-map.md` (yours to write: one section per repo) holds each repo's purpose, docs, branch and commit rules, verify commands and guards. `~/loop/repos` maps the Loop's repo key to its checkout, base branch and `repo:` label.
