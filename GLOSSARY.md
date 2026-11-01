# Glossary

## Loop Engineering

**Ticket state**: what the loop knows about one ticket it has picked up: its status (`working`, `blocked`, `ready-to-ship`, `mr-open`, `merged`), repo, branch, MR URL and whether the change touches UI. Owned by `loop/bin/loop-state`; nothing else reads or writes `~/loop/state/tickets/` directly.
_Avoid_: ticket file, status file.

**Loop worktree**: the git worktree the Worker builds a ticket in, at the path `loop-state path <repo> <ticket>` prints. Created by `loop-run.sh`, removed by `merge-approved` or `loop-state reset`.
_Avoid_: loop folder, workspace.
