---
name: open-mr
description: Pushes the current branch, waits for its CI pipeline to pass, then opens a merge or pull request into the target branch with a concise, emoji-signposted description that follows the repo's template and shows what changed, what got better and how it was tested. Use when work on a branch is finished and the user asks to open an MR or PR.
argument-hint: <target-branch>
---

# Open MR / PR

`$ARGUMENTS` is the target branch. Missing → ask. Works with GitLab (`glab`) or GitHub (`gh`), whichever the remote is.

## When to use

- The user asks to open an MR/PR, at the end of a work session, or as step 3 of `/ship-branch`.

## When not to use

- Reviewing the code first → `review-branch`.

## Rules

- Invoked by the user (directly or via `/ship-branch`) = permission to push this branch (never `--force`) and open one MR. Not to merge, rebase or touch other branches.
- Model-chosen without the user asking → confirm before pushing.
- The pipeline must pass before the MR opens. Always show the title and description and wait for an OK before creating.

## Workflow

1. **Preflight.** Uncommitted changes → stop and propose a commit split. Current branch must differ from the target and from protected names (`main`, `master`, `develop`, `staging`). `git fetch origin <target>`; no commits in `origin/<target>..HEAD` → stop. An MR/PR from this branch already open → show it and offer to update its description.
2. **Pipeline.** `git push -u origin <branch>`. Find the pipeline for HEAD (`glab ci status -b <branch>` / `gh run list -b <branch>`); none → start one (`glab ci run -b <branch>`). Wait until it ends (`--live` / `gh run watch`), in the background. Failed → show the failing jobs and log tail (`glab ci trace <job>` / `gh run view --log-failed`), the likely cause, and stop.
3. **Description.** Use the repo template (`.gitlab/merge_request_templates/`, `.github/pull_request_template.md`) when present — its sections and order win; fill every placeholder, drop its comments. Otherwise the layout below. Facts come from the commits, `git diff --stat origin/<target>...HEAD`, the work and tests done in this conversation, and the pipeline.
   - **Title:** Conventional Commit, imperative (`type(scope): subject`); validate with the repo's checker if any.
   - **Why before what**; the diff already shows the what. Link the ticket.
   - Bullets, one line each, fits on one screen. Evidence = numbers actually observed; never placeholders ("not run — why").
   - "What got better" only with claims you can back. Emoji as section signposts only.
4. **Open.** After the OK: `glab mr create --source-branch <b> --target-branch <t> --title … --description … --yes` (or `gh pr create --base <t> --title … --body …`), adding any labels or reviewers the user's own instructions require. Verify with `glab mr view` / `gh pr view` and report the URL.

## Fallback layout

```markdown
## 🎯 Why
<problem, 1-2 lines> · Refs: <ticket>
## ✨ What changed
- <change>
## 📈 What got better
- <concrete improvement>
## 🧪 Evidence
| Check | Result |
|---|---|
| Pipeline | ✅ passed — <url> |
## ⚠️ Risk
<one-way/two-way door, blast radius, rollback>
## 👀 How to review
<where to start, what to skim>
```

## Next Step

Approval gate: the user OKs the description before the MR opens.
- **If approved**, the MR goes to reviewers; nothing else to run.
- **If not approved**, revise the description in place; a failed pipeline routes back to the fix, then `open-mr` again.
