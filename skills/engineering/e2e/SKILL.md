---
name: e2e
description: Tests the current branch's changes end to end in a real browser by deriving acceptance criteria and real user scenarios, walking success, edge and error cases and every UI state, mocking only unreachable states with a clear label, and returning a screenshot-backed report. Use when a branch needs a browser check of what it changed before review or an MR.
argument-hint: [ticket or focus area]
---

# E2E for the current branch

## When to use

- Before opening an MR, or as step 2 of `/ship-branch`.

## When not to use

- Writing a permanent automated suite → `playwright-cli` or the repo's test setup.

## Rules

- Use the browser automation tool the user's instructions name; not available → say so and stop, don't substitute another.
- Open a new tab; leave the user's tabs alone. No real payments, messages or deletes of real data; follow the repo's test-data rules.
- Mock only a state that can't be reached honestly; label every mocked result 🧪 MOCKED with how. Never edit committed source for a mock; revert any temporary edit and confirm `git status` is clean.
- Judge only what the user can see; never print `.env*` values.

## Workflow

1. **Understand the change.** `git log --oneline origin/<base>..HEAD`, `git diff --stat origin/<base>...HEAD`; read the changed UI enough to know routes, API calls and the states each screen renders. Read the ticket's AC if one is given or named in the branch.
2. **Plan, then show it** (continue unless the user objects):
   - **AC** in Given/When/Then: one action and one observable outcome each; marked "derived" when not from the ticket.
   - **Scenarios**: ✅ success; 🔶 edge — boundaries (empty, 1, max, max+1), long or non-Latin text, double submit, back/refresh mid-flow, slow network, mobile width; ❌ error — invalid input, 4xx/5xx, timeout/offline, no permission, expired session.
   - **State checklist** per changed screen: ideal, empty, loading, partial, error, disabled, success, validation.
   - Proportional: a copy change gets 2-3 cases.
3. **Run.** Start the dev server the repo's documented way, in the background. Per scenario: clean start (reload, reset data it created), do the steps, wait until the expected element shows, screenshot before/after each state change as `S<NN>_<step>_<before|after>_<state>.png`, check the console. Bugs found → record repro steps and continue; don't fix unless asked.
4. **Report**: send the screenshots to the user, then the table below, failures first. Result is PASS, FAIL, BLOCKED or MOCKED-PASS.
5. **Clean up**: stop the dev server, close your tabs, confirm with `ps` nothing is left running.

```markdown
## E2E — <branch> @ <sha> · <url> · <browser> · <date>
**Result:** ✅ x · ❌ y · 🧪 z mocked · ⛔ blocked
| ID | Type | Scenario (AC) | Expected | Actual | Result | Evidence |
|---|---|---|---|---|---|---|
**States:** ideal ✅ · empty ✅ · error 🧪 …
**Bugs:** … **Not covered:** … (why)
```

## Next Step

Approval gate: the user reviews the screenshots.
- **If approved**, `open-mr` (or continue `/ship-branch`) with the table as MR evidence.
- **If not approved**, fix the failing scenario, then run `e2e` again.
