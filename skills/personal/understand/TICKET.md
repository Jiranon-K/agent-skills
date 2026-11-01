# Ticket target

The ticket branch of [`understand`](SKILL.md): the target is a Jira card the user is about to pick up. The page answers three things — what the card asks, where in the code it lands, what is still unclear — so the user starts the work with the flow already in their head.

The skill stays read-only here too: the page explains today's code and points at where the change goes. Implementation starts in a later turn, when the user asks.

## 1. Fetch the card

- Atlassian MCP: `getAccessibleAtlassianResources` for the `cloudId`, then `getJiraIssue` with summary, description, status, assignee, priority, labels, issuelinks, subtasks, comment.
- A bare number takes its project key from the repo's instructions or memory; ask the user when they name none.
- Subtasks and linked issues: fetch the summary of the ones the requirement depends on.
- Design or doc links in the card (Figma, Confluence): list them on the page as links; open them when the user asks.
- Card unreachable (MCP down, key not found, no permission) → tell the user and ask them to paste the card text; continue from the pasted text and say so in the page's first lines.

Acceptance criteria come from the card and its comments, quoted. A card without them gets the line "การ์ดไม่ได้ระบุ acceptance criteria" on the page, and the gap goes to the open questions.

Done when the requirement and every acceptance criterion can be quoted from the card.

## 2. Locate the change points

A **change point** is a place in the code where the card's change will land.

Collect every anchor the card names — component names, UI text, routes, endpoints, field names, text in screenshots — and resolve each one with step 1 of `SKILL.md`. A card with no usable anchor → ask the user which screen it is about.

Done when every acceptance criterion maps to at least one change point with `path:line`, or is listed as "ยังหาจุดแก้ไม่เจอ".

## 3. Trace

Trace the component that owns the most change points in full, per step 2 of `SKILL.md`. Trace each remaining change point far enough to connect it to that component: who calls it and what data reaches it.

While tracing, check every statement the card makes about current behaviour against the code. A mismatch is a finding: record it as "การ์ดกับโค้ดไม่ตรงกัน" with the card's sentence and the `path:line` side by side, and leave the resolution to the user and the card's owner.

Done when every change point is connected to the traced flow and every behaviour claim in the card is marked ตรง / ไม่ตรง / ยังไม่ได้ตรวจ.

## 4. Page

The page from step 3 of `SKILL.md`, with these changes:

- **Title** — card key + summary, linking to the card; one line of status / assignee / priority under it.
- **📌 สรุปสั้นๆ** — what the card asks, and what the code does today.
- **Diagram** — today's flow, with the change points marked.
- **🎫 การ์ดขอให้ทำอะไร** (new, after the diagram) — the requirement condensed, then a table `| Acceptance criteria (ตามการ์ด) | จุดที่ต้องแก้ | ตอนนี้โค้ดทำอะไร |`.
- **🗺️ Data flow** — describes the code as it is today.
- **🧭 จุดเริ่มงาน** (new, after Data flow) — change points in the order to touch them, the sibling code whose pattern each one should follow, and the spec files that already cover them.
- **❓ คำถามเปิด** (new, before ทบทวนความเข้าใจ) — ambiguous wording, card-versus-code mismatches, unlocated criteria. Each one phrased as a question the user can paste to the card's owner.

## 5. Close

Reply in Thai with the file path, a one-line summary, and the open questions listed in the reply itself. Ask about the backend trace as in step 4 of `SKILL.md`.
