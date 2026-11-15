---
name: loop-e2e
description: User-run. Runs browser e2e for a loop MR with Claude in Chrome, uploads screenshots to the MR, and removes the needs:e2e label. Usage `/loop-e2e <task key>`. Only run when the user invokes it.
disable-model-invocation: true
---

# Loop e2e (user-run)

The user invoking this is the explicit request for browser automation. Claude in Chrome (`mcp__claude-in-chrome__*`) is the only browser tool; if it is not connected, report that and stop.

1. Run `~/loop/bin/loop-state get <task>` for repo, branch and MR URL (`mr`). Work in the path `~/loop/bin/loop-state path <repo> <task>` prints.
2. Read the task's acceptance criteria (`get_work_context <task>` on Workspace) and the handoff comment's "ขั้นตอนต่อไป" to know what to check.
3. Start the dev server the repo's way (see `~/Home/docs/repo-map.md`; web-app: `yarn start`; project-b-web: `npm run dev`, port 3000) in the background. Never print `.env*` values.
4. In a new Chrome tab, walk through each acceptance criterion. Respect repo test-data rules (web-app staging: full CRUD only on the test bot). Take one screenshot per criterion.
5. Upload the screenshots to the MR (`glab api projects/<id>/uploads -F file=@<png>`) and post one MR note "e2e evidence" listing each criterion → pass/fail with its image. Remove the `needs:e2e` label.
6. Stop the dev server, close the tabs you opened, confirm with `ps` that nothing is left running. Report pass/fail per criterion.
