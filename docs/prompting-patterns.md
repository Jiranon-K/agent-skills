# Prompting Patterns That Work

> 11 copy-paste prompts from the Claude Code team and community. Use these directly in your Claude Code sessions.
> Sources: Boris Cherny's team tips (Jan 31, 2026), Matt Pocock, community best practices

---

## Planning

### 1. Start with a plan
```
I want to [your task]. Research the codebase and create a plan. Do NOT write any code yet.
```

### 2. Get a second opinion on the plan
```
Review this plan as a skeptical staff engineer. What's missing? What could go wrong? What would you push back on?
```

### 3. Surface unknowns before proceeding (Matt Pocock)
```
Make the plan extremely concise. At the end, give me a list of unresolved questions to answer before we start.
```
Forces Claude to tell you what it doesn't know. Two lines that prevent entire wrong directions.

### 4. Re-plan when stuck
```
This approach isn't working. Stop. Let's go back to plan mode. What went wrong and what's a better approach?
```

---

## Quality

### 5. Demand elegance
```
Knowing everything you know now, scrap this and implement the elegant solution.
```
Use after a mediocre first attempt. Claude has full context by then — the second try is usually much better.

### 6. Make Claude your reviewer
```
Grill me on these changes and don't make a PR until I pass your test.
```
Flips the dynamic — Claude reviews your decisions instead of you reviewing its code.

### 7. Prove it works
```
Prove to me this works. Diff the behavior between main and this branch.
```

---

## Verification

### 8. Verify before you ship
```
Now verify your changes work. Run the full test suite, check for type errors, and fix anything that fails.
```

### 9. Self-improvement after mistakes
```
Update CLAUDE.md so you don't make that mistake again.
```
Use this every time you correct Claude. Over time, CLAUDE.md becomes a living document that prevents repeat mistakes.

---

## Bug Fixing

### 10. Autonomous fix
```
Go fix the failing CI tests.
```
Don't micromanage how. Claude will read the logs, identify the issue, and fix it.

### 11. Context dump fix
```
Here's the bug report from [Slack/Jira/user]: [paste it]. Fix it.
```
Zero context switching. Paste the thread and let Claude figure it out.

---

## Tips

- **Voice dictation** (fn x2 on macOS): You speak 3x faster than you type. Your prompts get way more detailed.
- **Plan Mode** (Shift+Tab twice): Claude drafts a plan before acting. Use it for anything beyond a one-liner.
- **Subagents**: Append "use subagents" to any request where you want Claude to throw more compute at the problem.
