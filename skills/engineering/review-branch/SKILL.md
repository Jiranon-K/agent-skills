---
name: review-branch
description: Cleans up the current branch before a merge request by simplifying its diff, running a code review and fixing every finding, removing the comments the branch added, verifying with the repo's checks, and splitting the work into Conventional Commits. Use when a branch is functionally done and needs a final review pass before an MR.
argument-hint: <base-branch>
---

# Review branch

`$ARGUMENTS` is the base branch. Missing → ask.

## When to use

- After coding, before `e2e` and `open-mr`; step 1 of `/ship-branch`.

## When not to use

- Reviewing someone else's MR without editing → `mattpocock-skills:code-review`.

## Rules

- Invocation = permission to edit this branch and commit. Not to push, rebase, amend or force.
- Changes already uncommitted at the start are the user's: keep them out of your commits unless they belong to this branch's work (ask if unclear).
- Never suppress a failing check.

## Workflow

1. **Pin the diff.** `git fetch origin <base>`; fixed point `origin/<base>`. Empty diff or bad ref → stop.
2. **Simplify.** Run the `simplify` skill on that diff and apply its fixes.
3. **Review.** Run `mattpocock-skills:code-review` against `origin/<base>`. Fix every finding. A finding that is wrong or would change behaviour the ticket asked for → don't apply; list it with the reason. Unclear requirement → ask.
4. **Remove comments the branch added.** Only `+` lines in `git diff origin/<base>...HEAD` that are comments (`//`, `/* */`, `#`, `<!-- -->`, `{/* */}`); never comments that exist on the base. Remove all of them, trap warnings included. Before deleting one that warns of a real trap (invariant, workaround, external constraint), record it (`file:line` + gist) as a memory candidate for the report. Keep lint/type directives and license headers — they are code.
5. **Verify.** Run the repo's real checks (lint, typecheck, test, build) one at a time; fix what you broke. Confirm with `ps` that no runner or headless browser is left.
6. **Commit.** Group by intent (`refactor:` simplify, `fix:` findings, `chore:` comments, `test:`), stage per group, one Conventional Commit each, in English, following the user's commit conventions (suffixes, trailers). Do not push.

## Output

2-5 lines: findings fixed / rejected (why), comments removed, memory candidates, checks with results, `git log --oneline origin/<base>..HEAD`.

## Next Step

Approval gate: checks pass and the user accepts the commits.
- **If approved**, `e2e`, then `open-mr`.
- **If not approved**, revise the commits in place, or pause on the rejected finding with the user.
