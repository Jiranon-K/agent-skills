---
name: loop-e2e
description: User-run. Runs browser e2e for a loop MR with Claude in Chrome, uploads screenshots to the MR, and removes the needs:e2e label. Usage `/loop-e2e <task key>`. Only run when the user invokes it.
disable-model-invocation: true
---

# Loop e2e (user-run)

The user invoking this is the explicit request for browser automation. It runs in a normal session or in the task's Worker session: every step below uses a command the Worker is allowed. Claude in Chrome (`mcp__claude-in-chrome__*`) is the only browser tool; if it is not connected, report that and stop.

1. Run `~/loop/bin/loop-state get <task>` for repo, branch and MR URL (`mr`).
2. Read the task's acceptance criteria (`get_work_context <task>` on Workspace) and the handoff comment's "ขั้นตอนต่อไป" to know what to check.
3. Run `~/loop/bin/loop-preview here <task>` as a background command of this session (`run_in_background`), exactly that command with nothing joined to it. It uses the task's worktree (recreated only if it was removed) and runs the repo's dev server inside this session: no second session. Never build the worktree with `git -C` or start the dev server any other way: a Worker's session is denied both. If it refuses (no dev command), report its message and stop. The local URL is in `~/Home/docs/repo-map.md` (project-b-web: port 3000). While the first build runs the page does not answer: wait and reload, never start a second server. Never print `.env*` values.
4. In a new Chrome tab, walk through each acceptance criterion. Respect repo test-data rules (web-app staging: full CRUD only on the test bot). Take one screenshot per criterion.
5. Upload the screenshots with `~/loop/bin/loop-upload <task> <png>...` (it prints one markdown image line per file; `glab api` answers HTTP 400 for a file) and post one MR note "e2e evidence" listing each criterion → pass/fail with its image (`glab mr note <iid> -R <project path> -m …`: a Worker's folder may be gone, so always name the project). Remove the `needs:e2e` label with `~/loop/bin/loop-mr <task> e2e-done`, never with `glab mr update`.
6. Run `~/loop/bin/loop-preview stop <task>`, close the tabs you opened, confirm with `ps` that nothing is left running. Report pass/fail per criterion.
