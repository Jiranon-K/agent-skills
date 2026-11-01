---
name: ship-branch
description: Takes the current branch from done-coding to an open merge request in three gated steps — review and clean up, end-to-end browser test, then pipeline check and MR — and stops only when a gate fails or a decision belongs to the user. Use when a branch is finished and the user wants it reviewed, tested and shipped in one run.
argument-hint: <base-branch> [ticket] [from:2|3]
disable-model-invocation: true
---

# Ship branch

`$ARGUMENTS`: base branch, optional ticket, optional `from:<step>` to resume. Missing base → ask.

Typing `/ship-branch` is the user's go-ahead for all three steps: editing and committing on this branch, browser automation, pushing this branch (never force), running its pipeline and opening one MR. Nothing else.

Run every step here in the main conversation, not a subagent — subagents can't ask the user. Keep a task list of the three steps; between steps print `✅ Step N — <result>` and continue.

## Standing rules

- Never skip a gate or mark a step done without its evidence.
- Retry a failing check at most twice, then stop.
- On any stop: say which step, why, and what is already done (commits, push), so `/ship-branch <base> from:<N>` can resume.

## Step 1 — Review

Run the `review-branch` skill with the base.
**Gate:** checks pass, work committed → continue.
**Stop** if a check still fails, a finding would change asked-for behaviour, or a requirement is unclear.

## Step 2 — E2E

Run the `e2e` skill with the ticket. Show its plan and continue without waiting.
**Gate:** no FAIL (MOCKED-PASS and explained BLOCKED are fine).
**Stop** if the browser tool is unavailable, the dev server won't start, or a scenario fails — show the bug and screenshot and offer: fix here and rerun from step 1, or ship anyway.

## Step 3 — MR

Run the `open-mr` skill with the base, adding the e2e table to the Evidence section.
**Gate:** pipeline passed. Stop once to confirm the title and description — the only question a fully passing run asks.

## Final report

```
🚢 <branch> → <base>
1 Review  ✅ <findings fixed, comments removed, commits>
2 E2E     ✅ <pass / fail / mocked>
3 MR      ✅ <url>
🧠 Memory candidates: <file:line — trap> (save which?)
```

## Next Step

Approval gate: the user confirms the MR description in step 3.
- **If approved**, the MR goes to review; save the memory candidates the user picks.
- **If not approved**, revise the description in place, or resume from the step that stopped with `/ship-branch <base> from:<N>`.
