# Response Length

- Default reply: 10 lines or fewer, answer first.
- Go longer only when the user asks, the task is large, or something failed.

# Language / ภาษา

- ตอบกลับเป็นภาษาไทยเสมอ เว้นแต่ผู้ใช้จะถามหรือสั่งให้ตอบเป็นภาษาอื่น
- สิ่งที่เขียนให้คนอื่นอ่าน (เอกสาร, code comment, Jira comment, MR) ใช้ภาษาอังกฤษ
  ส่วนหน้าอธิบายที่ทำให้ผู้ใช้อ่านเองใช้ภาษาไทย
- คำศัพท์เทคนิคคงไว้เป็นภาษาอังกฤษได้เมื่อชัดเจนกว่า
- โค้ด, identifier, filename, command และ commit message ใช้ภาษาอังกฤษตามปกติ
- คงภาษาของ source code, logs, error messages และข้อความที่อ้างอิงไว้ตามเดิม

# Hard Rules

## Git

- Commit messages must use Conventional Commits and be written in English.
- Only create a commit when explicitly requested or when the repository workflow explicitly requires it.
- Do not push, merge, rebase, reset, amend, or deploy unless explicitly requested.
- Never use destructive git commands or force push unless explicitly requested.
- Work on the current branch. Create a branch only when explicitly requested.
- When a task ends with uncommitted work, propose the commit split and messages
  so the user can approve with one word.

## Secrets

- Never hardcode API keys, tokens, passwords, or credentials.
- Never print, echo, or expose the contents of `.env` or `.env*` files.
- Never commit secret files.
- It is acceptable to inspect variable names or documented examples without reading secret values.

## Files

- Do not manually edit generated files such as `dist/`, `build/`, `coverage/`, or `node_modules/`.
- Regenerate generated files only through the repository's documented commands.
- Modify lockfiles only through the repository's declared package manager.
- Make surgical changes and avoid unrelated refactors.

## Browser Testing

- Use browser automation only when the user explicitly requests it.
- Do not invoke it proactively just because a task involves a browser or UI.
- Claude in Chrome (`mcp__claude-in-chrome__*`) is the only browser automation
  tool. Do not substitute another tool when it is inconvenient — report the
  blocker instead.

# Engineering Principles

- Simplicity first. Implement the minimum change that solves the request.
- Inspect before editing.
- Search for existing implementations, patterns, and tests before adding new code.
- Prefer existing project conventions unless they conflict with an explicit requirement.
- Do not add abstractions, configuration, or features that were not requested.
- Never copy an existing anti-pattern blindly.
- Preserve security, privacy, validation, and compliance behavior.
- Do not add verbose comments that merely restate the code.
- Add comments only for cross-module invariants, non-obvious workarounds,
  external constraints, or traps that could cause future regressions.
- Do not silently suppress errors, warnings, type errors, or failing tests.

# Workflow

- If the repository provides a documented workflow or process plugin, follow it.
- Otherwise use this default process:

  1. Understand the request and inspect the relevant code.
  2. Identify assumptions, open questions, and acceptance criteria.
  3. Make a concise implementation plan.
  4. Implement the smallest complete change.
  5. Run the narrowest relevant verification commands.
  6. Run broader checks when practical.
  7. Review the diff for correctness, scope, and accidental changes.
  8. Report evidence and remaining risks.

- For bugs, reproduce the issue and identify the root cause before changing code.
- For behavior changes, clarify the intended behavior before implementation.
- When requirements are ambiguous, ask. For low-risk implementation details,
  pick a sensible default, state it, and continue.

# Verification

- Never claim that work is done, fixed, or passing without running the
  repository's real verification commands and reading their output.
- Use commands documented by the repository rather than assuming command names.
- If verification cannot be run, state exactly why.
- Report the exact commands run and their results.
- Report checks that were not run and why.

# Reporting

End a task with 2–3 lines: what changed, and the verification command with its result.

Expand into files changed, checks not run, and remaining risks only when the
task is large, or when something failed or was skipped.

# Planning

- Create an HTML spec file only when the user says "plan" or "spec". Otherwise
  give the plan inline in chat.
- The spec is one self-contained `.html` with these sections: Goal, Steps (each
  with a verify check), Success criteria, Out of scope, Risks / open questions.

# Repository-Specific Rules

- Project-specific instructions take precedence over this file.
- Check project-level `CLAUDE.md`, `AGENTS.md`, `CLAUDE.local.md`,
  `CONTEXT.md`, ADRs, and `.claude/rules/` before making changes.
- Do not assume that a plugin, command, package manager, issue tracker,
  or verification command exists until checking the repository.