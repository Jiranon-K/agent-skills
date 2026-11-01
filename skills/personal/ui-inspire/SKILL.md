---
name: ui-inspire
description: Research UI patterns from curated component/design reference sites, then design an original UI from those patterns. Use when designing or redesigning a page, section, or component and the user wants inspiration from the web, or when the user types /ui-inspire.
---

# UI Inspire: research references, then redesign from scratch

The user wants a UI designed for: $ARGUMENTS

## Goal
Look at real, high-quality references on the web, pull out the *patterns* that make them good,
then design something new for this project. Never copy a reference's code, copy, branding,
or exact visual layout. The output must be original and fit this project's stack and brand.

## Reference sources (pick the ones that fit the request)

**Animated / landing-page effects**
- https://21st.dev
- https://ui.aceternity.com
- https://magicui.design
- https://reactbits.dev
- https://motion-primitives.com
- https://cult-ui.com
- https://skiper-ui.com
- https://kokonutui.com
- https://animata.design

**Broad component registries (app UI, forms, tables)**
- https://originui.com
- https://www.kibo-ui.com
- https://reui.io
- https://ui.shadcn.com

**Full sections / blocks (hero, pricing, features, footer)**
- https://www.shadcnblocks.com
- https://tailark.com
- https://www.hyperui.dev
- https://preline.co

**Framework-agnostic HTML/CSS**
- https://uiverse.io
- https://flowbite.com
- https://daisyui.com

**Angular projects**
- https://www.spartan.ng
- https://zardui.com
- https://primeng.org

**Real product inspiration (screens, flows)**
- https://mobbin.com
- https://land-book.com
- https://www.lapa.ninja
- https://godly.website

## Process

1. **Read the project first.** Check the framework (React / Next / Angular / plain HTML),
   styling setup (Tailwind version, CSS vars, shadcn/spartan already installed?), existing
   design tokens, fonts, and brand colors. The new design must use what is already here.

2. **Clarify only if essential.** If the target section, audience, or vibe is unclear and a
   wrong guess would be costly, ask one short question. Otherwise state your assumptions and go.

3. **Research 4–6 references.** Use web search / fetch on the sources above (and beyond them
   if needed). For each reference, note in 1–2 lines:
   - layout structure and visual hierarchy
   - spacing rhythm, typography scale, color usage
   - interaction / motion idea (what moves, when, how subtle)
   - what specifically makes it feel good

4. **Synthesize a design direction.** Combine the strongest ideas into one coherent direction.
   Write a short brief before coding:
   - layout plan (sections, grid, breakpoints)
   - type scale and color tokens (mapped to the project's existing tokens)
   - 1–3 signature details (a motion, a texture, a layout twist) that make it distinctive
   - which references inspired which decision

5. **Build it from scratch** in the project's stack:
   - write new code; do not paste reference source
   - responsive from 360px up, no horizontal scroll
   - accessible: semantic HTML, focus states, contrast AA, `prefers-reduced-motion` respected
   - motion is purposeful and short (150–400ms), never blocking content
   - dark mode if the project supports it

6. **Self-review.** Run the dev server / take a screenshot if possible, check mobile and
   desktop, fix spacing and alignment issues before reporting.

7. **Report briefly:** what was built, the references used (as links), and one suggested
   next tweak.

## Rules
- Inspiration only: no copied code, text, logos, illustrations, or near-identical layouts.
- If a component's license requires attribution or is a paid/Pro item, do not reproduce it.
- Prefer components already installed in the project over adding new dependencies;
  if a new dependency is truly needed, say why.
- Avoid the generic "default shadcn look": vary typography, spacing, and accent usage.
