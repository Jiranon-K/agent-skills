---
name: "dev-challenge-generator"
description: "Generate original, real-product portfolio challenges in Frontend Mentor style: full-stack by default (or FE/BE only if asked), with brief, detailed spec, API, data model, brand kit, tokens, seed data, FAQ."
---

# Real-Product Challenge Generator (Full-Stack by default)

Generate original, portfolio-grade project challenges that feel like a real product a startup would ship, structured like premium challenges on sites such as Frontend Mentor (e.g. a group polling app, kanban board, e-commerce store, note-taking app, entertainment app). Copy the PATTERN only: the sections, depth, user-story style, expected-behaviour detail and asset list. Never copy names, copy text, designs, data or assets from Frontend Mentor or any other site. Every product, brand, persona and dataset is invented. No real company brands, no copyrighted images; for images use Unsplash/placeholder services or SVG shapes.

The output must be LONG and SPECIFIC. A short, generic output is a failure. Two developers reading the package should build the same product. Keep the tone encouraging and practical, aimed at a junior developer building a portfolio.

## Step 0: Pick the mode

- **Idea mode**: the user asks for ideas/options ("3 ideas", "give me some projects"). Produce rich idea cards in chat (format in Step 5), then offer to generate the full package for any of them.
- **Package mode**: the user names or picks an idea, or asks for a challenge. Generate the full file package (Steps 1-4).

## Step 1: Inputs and defaults

Ask at most ONE short question, only if something essential is missing; otherwise choose defaults and state them in one line, then proceed.

- **Scope (default: FULL-STACK)**
  - `fullstack` (default): frontend + backend + database + auth. Always also include a **frontend-only path** (mock API / JSON data / localStorage) so the challenge can be done in stages.
  - `frontend` / `FE`: only when the user says FE/frontend only. Backend is replaced by `data.json` + mock API (MSW or json-server) + localStorage. Keep the API contract as the mock's contract.
  - `backend` / `BE`: only when the user says BE/backend only. Deliver API, data model, auth, tests; the UI becomes optional (API collection for Bruno/Postman or a minimal admin page).
- **Difficulty** (default: Intermediate for full-stack, Junior for FE-only): Newbie (FE-only) / Junior / Intermediate / Advanced / Guru.
- **Default stacks** (all free-tier friendly; respect any stack the user names; alternatives include Vue, Svelte, Vanilla JS)
  - Full-stack: Next.js (App Router) + TypeScript + Tailwind CSS + PostgreSQL (Neon or Supabase free tier) + Prisma or Drizzle + Auth.js (or Better Auth) + Zod + Vitest/Playwright. Alternative split: React + Vite frontend with a Node API (Express/Fastify/NestJS).
  - FE-only: React + TypeScript + Vite + Tailwind + React Router + TanStack Query + MSW.
  - BE-only: Node + TypeScript + NestJS or Fastify + PostgreSQL + Prisma + JWT/session auth + Vitest/Jest + OpenAPI.
- **Domain**: avoid tutorial cliches (plain todo, weather, calculator, movie search). Prefer real-product categories: multi-user collaboration, marketplaces/booking, SaaS dashboards, community/voting, content/media libraries, commerce with checkout, scheduling, finance/expense, internal tools.
- **Language**: write prose in the user's language (Thai if they write Thai). Keep code, file names, identifiers, API paths and JSON keys in English.

## Step 2: Design the product before writing (internal)

Decide, then use consistently everywhere:
- Fictional company + product name, one-line value proposition, market context
- 2-3 personas (name, role, goal, frustration) and user roles (guest, member, owner/admin, ...)
- The core loop (what users do repeatedly) and the "wow" feature that makes it portfolio-worthy (realtime updates, drag-and-drop, sharing links without accounts, moderation, checkout, search + filters, analytics, etc.)
- Entities and relationships, permissions per role, every page/screen

## Step 3: Generate the package as files

Create `challenges/<challenge-slug>/`. Build in stages (outline first, then each file). Use Write for text files; use Bash only for things that must run. Meet the depth targets.

### 1. `README.md` : the challenge page
- Title, product name, tagline, difficulty, estimated time per path (frontend-only / full-stack), scope badge (Full-Stack / FE / BE), tags (CRUD, auth, realtime, drag-and-drop, forms, a11y...)
- **Overview**: what the product is, who it is for, why it matters (real-product tone)
- **Design concept**: mood, visual style, layout approach, key screens
- **The challenge**: "Your users should be able to:" then 10-20 concrete user stories grouped by area, including responsive layout, hover/focus states, theme switching and accessibility
- **Choose your path**: frontend-only (what is mocked, which data file) vs full-stack (what must be real: DB, auth, API). Mark full-stack-only stories.
- **What you'll learn**: 6-10 skills mapped to features
- **Assets provided**: checklist linking every file below
- **Where to find everything**, **Building your project** (workflow), **Deploying** (Vercel/Netlify/GitHub Pages for FE; Vercel/Render/Railway/Fly.io for API; Neon/Supabase for DB; env vars), **Presenting it in your portfolio**, plus teasers linking to brief, ideas-to-test-yourself and FAQ
Target: 150+ lines.

### 2. `docs/brief.md` : client brief
From the fictional founder/PM: background, problem, target users and personas, goals, measurable success metrics, constraints (budget, timeline, devices), launch scope vs later. Target: 60+ lines.

### 3. `docs/product-spec.md` : detailed product specification (most important file)
- Roles and a **permissions matrix** table (action x role)
- **Guest experience**: exactly what an unauthenticated visitor can see and do, and what prompts sign-up
- **Route map** with URL patterns and access per role
- For EVERY feature (at least 8 for Intermediate+), grouped by page/screen:
  - User stories
  - **Expected behaviour**: step-by-step interactions, what happens after submit, redirects, toasts, optimistic updates
  - **Validation rules** with exact limits and exact error message text
  - **States**: loading, empty (with copy), error (with copy and retry), success, disabled, permission-denied
  - **Edge cases**: at least 3 (duplicates, long text, concurrent edits, expired items, deleted parents, slow network)
  - **Acceptance criteria** checklist ("User can ..." or Given/When/Then)
- Responsive behaviour at 375 / 768 / 1440 with the layout changes described
- Accessibility: keyboard paths for key flows, focus management in modals, aria-live for live updates, contrast, reduced motion
- Non-goals
Target: 300+ lines.

### 4. `docs/data-model.md` (full-stack/BE; for FE-only describe the JSON shape)
Mermaid `erDiagram`; every table with columns, types, nullability, defaults, unique/foreign keys, indexes, cascade rules; which rules are enforced in DB vs app.

### 5. `docs/api-spec.md` (full-stack/BE; for FE-only it is the mock API contract)
- Auth approach (session cookie or JWT, password rules, optional OAuth), rate limits
- Every endpoint: method, path, auth, role, query params, request JSON example, response JSON example, status codes, one consistent error shape
- Pagination/sorting/filtering conventions; realtime events and payloads if relevant (SSE/WebSocket, or polling interval)
- Also write `starter/openapi.yaml` for the same endpoints
Every data-touching user story maps to at least one endpoint.

### 6. `docs/architecture.md` (full-stack/BE)
Folder structure, request flow (Mermaid), where validation lives, how auth/authorization are checked, caching, env var list, security checklist (input validation, authorization on every route, CSRF/CORS, password hashing, no secrets in client).

### 7. `docs/brand-kit.md`
Logo concept (text/SVG placeholder only), personality, voice and tone with example microcopy (buttons, empty states, errors), palette (name, hex, role, usage, contrast notes) for light and dark themes, typography (free Google Fonts) with full type scale (size/line-height/weight/letter-spacing), spacing scale, radius, shadows, iconography (free set such as Lucide), imagery guidance, component guidance (buttons, inputs, cards, modals, toasts with all states), motion, do/don't list. Target: 120+ lines.

### 8. `design/wireframes.md`
ASCII/text wireframes for every key screen at mobile and desktop, plus modals and empty states. State that no Figma file is provided and suggest the user design their own in Figma (free) from the brand kit.

### 9. `starter/`
- `tokens.css`: CSS custom properties for colours (light + dark), typography, spacing, radius, shadows, breakpoints, z-index, motion; identical to the brand kit
- `tailwind.config.js`: theme extension mapped to the same tokens (colors via CSS variables, fontFamily, fontSize, spacing, borderRadius, boxShadow, screens), `darkMode: 'class'`
- `data/data.json` (plus extra files if useful): realistic seed data for guest and signed-in experiences, 20-40 records per main entity, with edge cases (very long titles, missing optional fields, empty collections, expired items, many children in one parent, Thai/unicode text). Fake people with example.com emails. Demo accounts per role (passwords marked demo-only).
- `data/README.md`: explains each file and field
- Full-stack/BE: `.env.example`, `prisma/schema.prisma` or `db/schema.sql`, seed instructions

### 10. `docs/ideas-to-test-yourself.md`
8-12 stretch goals ordered by difficulty, each with why it matters and a hint (realtime via SSE, optimistic UI with rollback, PWA/offline, i18n TH/EN, keyboard shortcuts, virtualised list, admin dashboard, audit log, Playwright E2E, GitHub Actions CI, Lighthouse 95+, rate limiting, file uploads, email notifications).

### 11. `docs/milestones.md`
4-6 milestones (static UI with tokens, frontend with mock data, database + API, auth + permissions, polish/a11y/tests, deploy), each with a checklist and a "done when" line.

### 12. `docs/testing.md`
Unit (validation, calculations), integration (endpoints incl. auth/permission cases), E2E (3-5 critical journeys), manual a11y checklist.

### 13. `docs/faq.md`
12+ questions: other framework/DB, frontend-only first, is auth required, free hosting, images, changing the design, seeding, secrets, expected time, how to submit/share, using AI tools, what if stuck.

### 14. `docs/portfolio-guide.md`
Case-study README template for the user's repo (problem, solution, stack and why, architecture diagram, screenshots/GIF, live demo + demo accounts, challenges and learnings, next steps), what recruiters look for, how to talk about it in interviews.

Scope adjustments:
- FE-only: skip `architecture.md`, `.env.example`, schema; keep `api-spec.md` as the mock contract and `data-model.md` as the JSON shape.
- BE-only: keep brief, spec (behaviour and rules, less UI), data model, API spec, OpenAPI, architecture, testing, milestones, FAQ, portfolio guide; brand kit, tokens, Tailwind and wireframes are optional.

## Step 4: Quality gate and delivery

Check and fix before finishing:
- Tokens identical across `brand-kit.md`, `tokens.css`, `tailwind.config.js`
- Every user story appears in the spec with expected behaviour, validation, states, edge cases, acceptance criteria
- Every data-touching story maps to an endpoint; every endpoint uses data-model entities
- Seed data matches data-model field names/types; JSON validates (`python -m json.tool` or `node -e`)
- Difficulty matches scope: Newbie = 1-2 static pages (FE-only); Junior = 3-5 screens, local state/mock API or simple auth; Intermediate = 5-8 screens, auth + roles + CRUD + one wow feature; Advanced = realtime or complex state, permissions matrix, tests, CI; Guru = teams/multi-tenant, payments mock, audit log, performance budget
- Original content only; depth targets met

Then zip the folder (`zip -r <slug>.zip challenges/<slug>`) and send the zip with SendUserFile, plus `README.md` on its own so it previews. Reply briefly: product name, scope, stack and defaults used, path options, and offer (a) another challenge in a different domain or difficulty or (b) scaffolding the starter project (Next.js or Vite) with tokens, schema and seed data wired in.

## Step 5: Idea mode format

For each idea (default 3, mixed difficulty), write a rich card in chat, not a one-liner:
- Product name + tagline, difficulty, scope, estimated time
- Problem and target users (2-3 sentences, real-product framing)
- Core features (6-10 bullets) including the guest experience
- The wow feature and why recruiters will notice it
- Full-stack parts: main entities, auth/roles, notable API or realtime needs
- Skills practised
- Frontend-only path in one line
End with which to build first and why, then offer to generate the full package.