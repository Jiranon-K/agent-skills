---
name: loop-work
description: Worker of the Loop Engineering system. Implements one risk:low ticket inside a prepared git worktree, verifies it, and (with --finish) applies Reviewer findings and delivers — web-app opens a staging MR via ship.sh, project-b-web stops at a local branch plus an MR draft. Called by ~/loop/bin/loop-run.sh; usage `/loop-work <ticket> <repo> [--finish]`.
---

# Loop Worker

Arguments: `<ticket> <repo> [--finish]`. `<repo>` is `web-app` or `project-b-web`.
You run headless. Nobody answers questions. When something is unclear, stop with `RESULT: blocked: <the question>` — never guess.

## Hard rules (all phases)

- Work only in the current directory. It must be under `~/Projects/.loop-worktrees/`; if not, stop with `RESULT: blocked: not in a loop worktree`.
- The repo's `CLAUDE.md` / `AGENTS.md` and the docs it points to win over this skill. Read them first.
- Never read, print, or edit `.env*`. Never force-push, merge, rebase, or reset. Never touch another person's ticket or feature directory.
- Stay in the ticket's scope. No unrelated refactors.
- Run heavy commands (test suites, builds) one at a time. Before you finish, make sure no karma, headless Chrome, or dev-server process you started is still running.
- No browser e2e. UI evidence is collected later by the user's `/loop-e2e`.
- If the same verification fails after 2 fix attempts, stop with `RESULT: blocked: <failing command and error summary>`.
- **project-b-web: no agent reaches a remote** (repo rule). No push, no MR, no issue comment or label. Everything stays local.

## Phase 1 — build (no `--finish`)

1. Read the ticket: Jira via `getJiraIssue` (project-a, and project-b `PB-*`), or `glab issue view <n> -R gitlab.example.com/example-team/project-b-web`.
2. Re-check it is really risk:low: docs/test/chore or a small bug, clear acceptance criteria, no auth/payment/migration/`.env`, likely ≤ ~5 files. If not, stop: `RESULT: blocked: <why it is not risk:low, or the question>`.
3. Project A only: on the Jira ticket replace label `agent:ready` with `agent:working` (`editJiraIssue`, keep other labels), and update the ticket's current loop status comment (newest comment starting with `🤖 [loop-status]` or the escaped `🤖 \[loop-status\]`, via `addCommentToJiraIssue` with its `commentId`) to `**Progress:** Agent working`. Never post a new comment for progress; if no loop comment exists, post one in the format from the `loop-triage` skill.
4. Start the change the repo's way:
   - **web-app**: follow CLAUDE.md "Feature Workflow" — feature id `feat-<TICKET>-<slug>`, branch `<type>/<description>`, `status.json` claim (owner `you`), commit and push that claim (plain `git push -u origin <branch>`), one progress file for this session. Run `./init.sh` first.
   - **project-b-web**: branch name per `docs/branching.md` (`feat/<ticket-lowercase>-<slug>` or `fix/...`). The worktree starts detached at `origin/develop`; create the branch with `git switch -c <name>` (do not run `new-feature.sh`, it checks out `develop`, which is busy in the main checkout). Run `./init.sh` first.
5. Install dependencies only if `node_modules` is missing, with the repo's package manager (web-app: yarn; project-b: `./init.sh` handles it).
6. TDD: write the failing test, run it red, implement, run it green (use the repo's `tdd` skill and its stack skill — `angular-engineer` / `next-engineer`).
7. Verify with the repo's real commands and keep the exact commands and results:
   - web-app: `yarn lint`, `yarn test --watch=false`, `yarn run build:production`, `.harness/scripts/check-tdd-order.sh` if present.
   - project-b-web: `./init.sh` (lint, test, `tsc --noEmit`, build).
8. Commit per the repo's commit convention (Conventional Commits; project-b needs `Refs:`/`Task:` footers and passes `./scripts/check-commit-msg.sh`). End each commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
9. Print, in this order:
   ```
   RESULT: ready-for-review
   BASE: <origin/staging | origin/develop>
   ### Evidence
   - `<command>` → <result>
   ### UI change
   yes | no
   ```

## Phase 2 — finish (`--finish`, Reviewer findings are in the prompt)

1. Fix every `blocking` and `major` finding. For any finding you decline, write one line on why. Re-run the verification from Phase 1 step 7 and commit.
2. Deliver:
   - **web-app**: complete the feature record the repo requires (progress entry ending with the Handoff block, post-mortem, `status.json` evidence). Run `.harness/scripts/ship.sh --yes`. Find the MR (`glab mr view <branch>`), then
     `glab mr update <n> --label "owner:you,needs:human-verify"` (add `needs:e2e` when the change is UI) and confirm with `glab mr view <n>` that the labels are there. Post one MR note (`glab mr note <n> -m ...`) titled "Loop evidence" with: verification commands and results, Reviewer findings and what was done with each, and either "e2e: pending — run /loop-e2e" (UI) or numbered manual verify steps (non-UI). Then on the Jira ticket: update the current loop status comment in place to `**Progress:** MR open: <MR URL> — waiting for review`, and replace label `agent:working` with `needs:human-verify`.
     Print `RESULT: mr-open <MR URL>`.
   - **project-b-web**: nothing remote. Check the MR title with `./scripts/check-commit-msg.sh - <<< "<title>"`. Print:
     ```
     RESULT: ready-to-ship <branch>
     ### MR title
     <title>
     ### MR description
     <body following .gitlab/merge_request_templates/Default.md, including verification evidence, Reviewer findings, and e2e pending or manual verify steps>
     ```
3. If blocked at any point: project-a — update the current loop status comment in place with the question (`**Question:**`) and `**Progress:** Blocked — waiting for an answer`, and replace `agent:working` with `needs:human`; project-b — local only. Print `RESULT: blocked: <reason>`.
