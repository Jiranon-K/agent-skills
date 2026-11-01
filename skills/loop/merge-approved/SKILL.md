---
name: merge-approved
description: User-run. The user's "!<MR> ผ่าน" — after the user has reviewed a loop MR, removes needs:human-verify and merges it with squash + delete source branch, then cleans up the loop worktree. Usage `/merge-approved <ticket>`. Only run when the user invokes it.
disable-model-invocation: true
---

# Merge approved (user-run)

The user invoking this is the explicit merge request for this one MR. Never merge any other MR.

1. Read `~/loop/state/tickets/<ticket>`: it must say `mr-open <repo> <branch> <MR URL>`.
2. `glab mr view` the MR (web-app: in the repo; project-b: `-R gitlab.example.com/example-team/project-b-web`). Stop and report if any of these fail:
   - label `owner:you` present; `needs:e2e` absent (or the user said to skip e2e);
   - pipeline not failed; no unresolved threads; target is `staging` (web-app) or `develop` (project-b).
   - web-app only — **merge-back gate**: `git -C ~/Projects/project-a/web-app fetch origin master staging` then `git ... rev-list --count origin/staging..origin/master` must be `0`. Non-zero means the weekly release merged staging into master and master (with its `chore(release)` commit) is not merged back yet; merging now breaks the version and CHANGELOG. Stop and tell the user to wait for the merge-back.
3. Remove `needs:human-verify`, then `glab mr merge <n> --squash --remove-source-branch --yes`.
4. Comment "merged" with the MR link on the ticket; for Jira remove `needs:human-verify`.
5. Remove the worktree: `git -C <main repo> worktree remove ~/Projects/worktree/<repo>-<ticket>` (stop and report if it has uncommitted changes). Write `merged <repo> <branch> <MR URL>` to the ticket state file.
