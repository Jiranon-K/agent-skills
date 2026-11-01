---
name: blocker-ping
description: Finds blockers that have stayed open across recent standups or tickets and drafts one short follow-up per owner, with what is waiting, since when, and the exact thing needed to unblock it. Use when blocked work keeps rolling over day to day and needs a nudge to backend, product or another team.
argument-hint: [standup folder or ticket list] [min days, default 2]
---

# Blocker follow-up

## When to use

- The same 🚧 Blockers keep appearing in daily standups or ticket comments.

## When not to use

- Writing the standup itself → `/stakeholder-update`.

## Workflow

1. **Load the team file.** Find the `~/.claude/teams/*.md` whose `repos:` matches the current directory (or the team the user names) and use it for names, roles, tone and mentions. None found → work from the thread and suggest `/team-context` once.
2. **Collect.** Read the recent standup notes (path from the user or the project's context file; otherwise ask once) and any tickets they name. Extract each blocker: item, owner (team or person), what is needed, first seen date.
3. **Filter** to blockers open at least the minimum days (default 2) and still unresolved — check the ticket or MR for a newer answer before nudging.
4. **Group by owner.** One follow-up per owner, listing their items oldest first.
5. **Draft** each follow-up in the tone the team file sets for that owner, mentioning them with its handle for that app: greeting, one line per item (`<ticket> — need <exact thing> — waiting since <date>`), one clear ask with a by-when if the user gave one. Thread language, short, friendly, no blame.
6. Suggest where each goes (a channel from the team file when it lists one) (ticket comment vs chat) based on where the question was first asked.

## Rules

- Never post a comment or send a message without the user's explicit yes on that exact draft.
- Facts only from the notes and tickets; mark anything uncertain.

## Output

```markdown
## Open blockers (≥ N days)
| Item | Owner | Needs | Since |
|---|---|---|---|
### Draft — @<owner> (<where>)
<ready to paste>
```

## Next Step

Approval gate: the user approves each draft.
- **If approved**, post it where suggested (only then): with Claude in Chrome open the channel URL from the team file, type the draft, screenshot the composer, send, screenshot to confirm. Note the date for the next standup.
- **If not approved**, revise that draft in place.
