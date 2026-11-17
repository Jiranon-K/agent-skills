---
name: merge-approved
description: User-run. The user's "!<MR> ผ่าน" — after the user has verified a loop MR, marks it ready, removes needs:human-verify, squash-merges it into its base branch, moves the Workspace task on, and cleans up the loop worktree. Usage `/merge-approved <task key>`. Only run when the user invokes it.
disable-model-invocation: true
---

# Merge approved (user-run)

The user invoking this is the explicit merge request for this one MR. Never merge any other MR. Read `~/loop/workspace.md` first.

1. Run `~/loop/bin/loop-state get <task>`: it must show `status=mr-open`, and gives `repo`, `branch` and `mr` (the MR URL). `~/loop/bin/loop-state repo <repo>` gives the main checkout and the base branch.
2. `glab mr view` the MR (project-b repos: with `-R` from `workspace.md`). Stop and report if any of these fail:
   - label `owner:you` present; `needs:e2e` absent (or the user said to skip e2e);
   - pipeline not failed; no unresolved threads; target is the repo's base branch.
   - web-app only — **merge-back gate**: `git -C <main checkout> fetch origin master staging` then `git -C <main checkout> rev-list --count origin/staging..origin/master` must be `0`. Non-zero means the weekly release merged staging into master and master (with its `chore(release)` commit) is not merged back yet; merging now breaks the version and CHANGELOG. Stop and tell the user to wait for the merge-back.
3. `glab mr update <n> --ready --unlabel needs:human-verify`.
4. Merge:
   - **project-b repos**: `glab mr merge <n> --squash --remove-source-branch --yes` (the self-hosted GitLab maps the key to the user).
   - **project-a repos**: glab's gitlab.com account is shared, so a web or API merge shows another person. Squash locally instead: `git -C <main checkout> fetch origin <base>`, then in a temporary detached worktree of `origin/<base>` (remove it afterwards) run `git merge --squash origin/<branch>`, commit with the MR title (Conventional Commit) and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, and `git push origin HEAD:<base>`. After the push succeeds, `glab mr close <n>` with a note `Squash-merged locally as <sha>` and delete the remote branch with `git push origin --delete <branch>`. If the push is rejected because the base branch is protected, stop and tell the user the merge must be done on the web and will show the shared account's name.
5. Workspace: `transition_task <task>` to the space's "After merge" status from `workspace.md`, and `add_comment` `🤖 [loop-status] merged: <MR URL>`.
6. Remove the task's worktree if it still exists: `git -C <main checkout> worktree remove "$(~/loop/bin/loop-state path <repo> <task>)"` (stop and report if it has uncommitted changes). Run `~/loop/bin/loop-state set <task> merged`, then `~/loop/bin/loop-clean`, which archives the task's spec and design package and removes its leftover MR text; report its `cleanup:` line.
