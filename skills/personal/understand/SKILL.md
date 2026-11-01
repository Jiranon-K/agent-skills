---
name: understand
description: Explain a UI component, on-screen text, or a Jira ticket being picked up — what it does, how data flows through it, and for a ticket where the change lands — as a Thai HTML page with a diagram, opened in the browser. Use when the user asks to อธิบาย/understand/explain a component name or a UI label, or how data flows through it, wants to understand a Jira ticket before starting it, or invokes /understand <target>.
---

# Understand

The target is a **component name** (`OrderTable`), **text visible in the UI** ("ยืนยันคำสั่งซื้อ"), or a **Jira ticket** (`EX-123`, a bare ticket number, or a Jira URL). Read the code until the flow is traced, then write one HTML page and open it.

A ticket target follows [`TICKET.md`](TICKET.md) from start to finish: read it before step 1. It reuses the steps below and changes what each one produces.

The project is **read-only** for this skill. Env files stay unread (name the variable only), and unverified claims are labelled "ยังไม่ได้ตรวจ".

## 1. Locate the target

- Jira ticket → `TICKET.md`.
- Component name → search the repo for its definition.
- UI text → search the i18n/locale files first, then take the key to the components that use it. Search hardcoded strings next. Try close variants (spelling, key casing) before giving up.
- Several candidates → list them with `file:line` and let the user pick.
- No exact match → take the closest i18n key or component, say in the page's first lines that the exact text was not found and which one was used instead, and confirm with the user in the closing reply.

Done when exactly one component is chosen and its file is identified.

## 2. Trace the flow

Read the component, then **up** to the parent that passes its inputs, and **down** to the children it renders. When it fetches data itself, follow the call through services/hooks to the API client, ending at the endpoint (method + path).

Use the project's own framework vocabulary (Angular: `@Input`/`@Output`, signals, `BehaviorSubject`, injected services; React: props, state, hooks).

Done when every input, output, state, dependency, and API call in the component is accounted for with `file:line`. Stop at the endpoint; the backend repo stays closed until the user asks (step 4).

## 3. Write the page

Create one self-contained HTML file with the Write tool (shell heredocs stall in some environments) in the session scratchpad; the repo stays untouched. Open it with `open <file>`.

Whole page in Thai; technical terms stay English, with a short Thai gloss on first use. Tone: senior developer mentoring a junior. CSS inline.

Styling: when the repo root has `DESIGN.md`, read it and take its colors, typography, and radii. Keep the light theme it describes (dark page backgrounds hurt readability here), body text in its ink colors on its surface colors, and the diagram's text and fills in those same tokens. Without `DESIGN.md`: light background, dark text, Thai-capable font.

Sections in this order:

1. **📌 สรุปสั้นๆ** — 2–4 bullets: what the component does.
2. **Diagram** — directly under the summary. Pick Mermaid (CDN, with the Mermaid source in a `<details>` as offline fallback) or hand-drawn inline SVG, whichever shows this flow more clearly.
3. **🧠 อธิบายแบบเข้าใจง่าย** — everyday Thai analogy (7-Eleven, BTS, delivery app), why it matters, when it is used in real work. Short paragraphs.
4. **📖 คำศัพท์ที่ควรรู้** — table `| คำศัพท์ | ความหมายแบบง่ายๆ |` for terms from the code and the project's domain.
5. **🗺️ Data flow** — table of inputs/outputs, state, and dependencies; table of API calls (endpoint, method, loading/error handling); numbered steps from trigger to render; the few key code lines quoted unchanged. Every citation spells out the complete repo-relative path from the repo root, plus the line, in every table cell and list item, e.g. `src/app/modules/billing/components/point-card/point-card.component.ts:35`. The reader copies the citation straight into an editor's "go to file", so a bare file name, a path shortened with `...`, or a path relative to the previous row all fail that.
6. **✅ ทบทวนความเข้าใจ** — 1–2 short questions with brief answers.

When an endpoint is reached, state in section 5: "ฝั่ง API ยังไม่ได้ไล่".

Done when every cited path passes `test -f <repo-root>/<path>`; fix the citation or drop it before opening the page.

## 4. Close

Reply in Thai with the file path and a one-line summary. If an endpoint was reached, ask whether to trace the backend; on yes, update the same page.
