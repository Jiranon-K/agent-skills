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
   - **project-a repos**: glab's gitlab.com account is shared, so a web or API merge shows another person. Merge locally the way GitLab's web "squash + merge commit" does, so the base branch keeps the branch name (with the card key) and the MR link, the MR shows Merged, and CHANGELOG gets one entry: (a) `git -C <main checkout> fetch origin <base> <branch>` and note the branch head `<old>`; (b) in a temporary detached worktree of `origin/<base>` (remove it afterwards) run `git merge --squash origin/<branch>`, resolve conflicts if any (then run the repo's typecheck, lint and the touched area's specs; stop if they fail), and commit with the MR title without `Draft:` (Conventional Commit) and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`: this is `<squash>`; (c) `git push --force-with-lease=<branch>:<old> origin <squash>:refs/heads/<branch>` so the MR head is the squash commit; (d) `git checkout --detach origin/<base>` and `git merge --no-ff <squash> -m "Merge branch '<branch>' into '<base>'" -m "<MR title>" -m "See merge request <group>/<repo>!<n>"`, then `git push origin HEAD:<base>`; (e) GitLab marks the MR Merged by itself once its head is in `<base>`: check `glab mr view <n>` shows merged (wait up to a minute; if still open, `glab mr close <n>` with a note `Merged locally as <merge sha>`), then delete the remote branch with `git push origin --delete <branch>`. If a push is rejected because the branch is protected, stop and tell the user the merge must be done on the web and will show the shared account's name.
5. Workspace: `transition_task <task>` to the space's "After merge" status from `workspace.md`, and `add_comment` `🤖 [loop-status] merged: <MR URL>`.
6. If a herdr space `preview <task>` is open (`~/.local/bin/herdr-core ls`), ask the user to close it first: its dev server writes into the worktree. Remove the task's worktree if it still exists: `git -C <main checkout> worktree remove "$(~/loop/bin/loop-state path <repo> <task>)"` (stop and report if it has uncommitted changes). Run `~/loop/bin/loop-state set <task> merged`, then `~/loop/bin/loop-clean`, which archives the task's spec and design package and removes its leftover MR text; report its `cleanup:` line.
