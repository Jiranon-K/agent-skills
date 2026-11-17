# Glossary

## Loop Engineering

**Ticket state**: what the loop knows about one ticket it has picked up: its status (`working`, `blocked`, `ready-to-ship`, `mr-open`, `merged`), repo, branch, MR URL and whether the change touches UI. Owned by `loop/bin/loop-state`; nothing else reads or writes `~/loop/state/tickets/` directly.
_Avoid_: ticket file, status file.

**Loop worktree**: the git worktree the Worker builds a ticket in, at the path `loop-state path <repo> <ticket>` prints. Created by `loop-run.sh`, removed by `merge-approved` or `loop-state reset`.
_Avoid_: loop folder, workspace.

**Design package**: what the Designer writes for one task under `~/loop/designs/<task>/`: the proposed spec, the architect sketch and rationale, the grounding notes and the decision log. Its status (`designing`, `proposed`, `redo`, `blocked`, `approved`) is owned by `loop/bin/loop-spec`; nothing else decides it.
_Avoid_: design doc, plan.

**Ready spec**: `~/loop/specs/<task>.md` with the line `status: ready`. The only thing a Worker builds from. It exists only because the owner ran `loop-spec approve` through `/loop-design-review`, or wrote it by hand.
_Avoid_: approved design, grilled spec.

**Cross-vendor seat**: a review or judge seat filled by a model that is not Claude (GPT-6-Luna through codex, Gemini through agy), asked through `loop/bin/loop-ask`. It reads files and answers; a run by the caller decides whether its claim holds.
_Avoid_: second opinion, external reviewer.
