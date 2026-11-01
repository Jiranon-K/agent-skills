---
name: loop-ship
description: User-run. Pushes a project-b-web branch the loop Worker prepared locally and opens its MR to develop with the drafted title/description and labels owner:you + needs:human-verify. Usage `/loop-ship <ticket>`. Only run when the user invokes it.
disable-model-invocation: true
---

# Loop Ship (project-b, user-run)

The project-b repo forbids agents from reaching a remote, so the Worker stops locally. The user invoking this skill is the explicit request to push and open the MR.

1. Read `~/loop/state/tickets/<ticket>`: it must say `ready-to-ship project-b-web <branch>`. Otherwise stop and say what it says.
2. Show the user the draft `~/loop/state/mr-draft-<ticket>.md` title and the commit list (`git -C ~/Projects/worktree/project-b-web-<ticket> log --oneline origin/develop..HEAD`), then continue.
3. In the worktree: `git push -u origin <branch>` (never force).
4. Open the MR on the hostname glab is logged in to (the git remote uses a bare IP):
   `glab mr create -R gitlab.example.com/example-team/project-b-web --source-branch <branch> --target-branch develop --title "<title>" --description "<body>" --label "owner:you,needs:human-verify" --yes` (add `needs:e2e` when the draft says e2e pending). Confirm the labels with `glab mr view`.
5. Comment the MR link on the ticket (GitLab issue: `glab issue note`; Jira `PB-*`: `addCommentToJiraIssue`).
6. Write `mr-open project-b-web <branch> <MR URL>` to `~/loop/state/tickets/<ticket>`. Report the MR URL.
