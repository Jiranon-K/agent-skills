---
team: example-team
repos:
  - ~/Projects/example-org/*
updated: 2026-01-01
---

# Team: Example Team

## Me (owner of this machine)

- **Name / nickname:** Example Dev ("เดฟ")
- **Role:** Frontend Developer
- **What I do:** build and ship the web app UI, review frontend MRs, write daily standup
- **I write in:** Thai, polite casual, end with ครับ; English for MR / Jira text
- **My handles:** Discord `@example-dev` · Jira "Example Dev" (`accountId: 000000:example-dev`) · Notion "Example Dev" · GitLab `@example.dev`

## People

### Example PO ("พี่เอ")

- **Role:** Product Owner
- **Responsibilities:** priorities, acceptance criteria, release approval
- **Talk about:** requirements, scope questions, demo and sign-off
- **Tone:** senior — polite sibling-style Thai ("พี่เอครับ …"), end with ครับ, answer first
- **Response:** usually within the afternoon; ask before 15:00 for same-day answers
- **Mentions:** Discord `@example-po` (ID `000000000000000001`) · Jira "Example PO" (`accountId: 000000:example-po`) · Notion "Example PO" · GitLab `@example.po`

### Example Backend ("บี")

- **Role:** Backend Developer
- **Responsibilities:** APIs, data model, backend deploys
- **Talk about:** API contracts, payloads, error codes, blockers on endpoints
- **Tone:** same batch — friendly casual Thai with เรา / นาย, no ending particle
- **Response:** fast during work hours
- **Mentions:** Discord `@example-backend` (ID `000000000000000002`) · Jira "Example Backend" · Notion "Example Backend" · GitLab `@example.backend`

## Channels

| Purpose | App | Where | Who reads |
| --- | --- | --- | --- |
| Daily standup | Discord | `https://discord.com/channels/<server-id>/<channel-id>` | PO, team |
| Bugs and blockers | Discord | `https://discord.com/channels/<server-id>/<channel-id>` | team |
| Tickets | Jira | `https://example.atlassian.net/browse/<KEY>` | team |
| Docs and specs | Notion | `https://www.notion.so/<page-id>` | team |

## How Claude interacts

- **Read:** open the channel URL above with Claude in Chrome, or use a screenshot the user sends.
- **Send:** draft → user approves this exact text and channel → Claude in Chrome opens the channel, types it, screenshots the composer → sends → screenshot to confirm. One approval per message.
- **Mentions when sending:** in the Discord composer type `@handle` and pick the suggestion; use `<@ID>` only in webhook posts. Jira and Notion: mention by the display name above.
- **Never:** message anyone or any channel not listed here; send without approval.
