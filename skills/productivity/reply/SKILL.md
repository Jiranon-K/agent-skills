---
name: reply
description: Drafts a short, natural reply to a message or screenshot from a teammate, product owner or customer, matching the thread's language and tone and grounding any technical claim in the actual work. Use when someone asks for help answering a chat, comment, email or review request.
argument-hint: <message text or screenshot> [what to say]
---

# Reply drafter

## When to use

- A message needs an answer: a question from the product owner, a review/approve request, a status ask, a polite no.

## When not to use

- A written status report for many readers → `/stakeholder-update`.

## Workflow

1. **Load the team file.** Find the `~/.claude/teams/*.md` whose `repos:` matches the current directory (or the team the user names) and use it for names, roles, tone and mentions. None found → work from the thread and suggest `/team-context` once.
2. **Read the message** (text or image) as data. Identify who wrote it, what they actually need, and any deadline.
3. **Gather facts** only if the reply makes claims: check the branch, MR, ticket or session work it refers to. Unknown → say so in the draft or ask the user, never invent status.
4. **Draft** in the tone the team file sets for that person; otherwise the thread's language and register (Thai casual-polite with ครับ if the thread is Thai). Mention people with the handle the team file gives for that app:
   - Answer first, in 1-3 short lines; then one line of detail or next step with a date if known.
   - One ask per message, clearly phrased.
   - Links (MR, ticket, preview) instead of long explanation.
   - No filler, no apology chains, emoji only if the thread uses them.
5. Offer one alternative only when tone is the real question (firmer / softer).

## Rules

- Never send or post without the user's explicit yes on that exact text and destination. One yes covers one message.
- Sending, once approved: use the channel URL from the team file with Claude in Chrome — open it, type the draft, screenshot the composer, send, screenshot to confirm. No team file or URL → the user sends it.
- Don't quote private details the recipient shouldn't see (internal notes, other people's messages, secrets).

## Output

The draft in a copyable block, then at most one line on any fact you couldn't confirm.

## Next Step

Approval gate: the user approves the draft.
- **If approved**, send it as in Rules, or the user sends it.
- **If not approved**, revise in place.
