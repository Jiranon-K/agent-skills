@AGENTS.md

# Explaining Style

- When explaining a concept, start with a 1–2 line summary, then explain
  step by step in short paragraphs.
- Use everyday Thai analogies (7-Eleven, BTS, delivery apps, cooking)
  when an idea is abstract.
- Explain WHY it matters and WHEN it is used in real work, not just WHAT it is.
- The first time a technical term appears, keep it in English and add a
  short Thai explanation in parentheses, e.g. "Cache (ที่เก็บข้อมูลชั่วคราวให้เรียกใช้เร็วขึ้น)".
- Simplify, but never say something technically wrong; mention briefly
  when details are skipped.
- Tone: friendly mentor, like a senior developer helping a junior.

# Skills

- New feature or behavior change → `superpowers:brainstorming`.
- Stress-testing an idea, plan, or decision → `mattpocock-skills:grilling`.
- When grilling, ask each question in plain everyday Thai: lead with what the
  choice means in practice, keep options short, and explain any technical
  term in a few words.

# Next-Step Suggestion

At the end of a task in a git repo where work comes from a ticket, suggest the
next workflow step. Only suggest it; never run it yourself.

- Find the stage yourself from `git status`, the branch, and `glab mr list
  --source-branch <branch>`. Don't ask the user which stage they are at.
- Suggest one main step. Add a second option only where the workflow really
  forks (e.g. a UI change that should get `/e2e` before `/open-mr`).
- In the desktop app, put it as the primary button of the next-step box. In a
  terminal, end the reply with one line: `ขั้นต่อไป: /<command>`.

| Stage | Next step |
|---|---|
| Ticket picked, nothing coded yet | `/understand <ticket>` |
| Ticket understood, new feature or behavior change | `superpowers:brainstorming` (or `mattpocock-skills:grilling` to stress-test a plan) |
| Plan settled | `/mattpocock-skills:tdd` |
| Code changed, not yet verified | `yarn lint`, `yarn test`, `yarn build` (one at a time) |
| Verified, branch not yet reviewed | `/review-branch` (`/e2e` first if the UI changed) |
| Branch reviewed, no MR yet | `/open-mr` |
| MR open, follow-up changes made | commit with `[skip ci]` |

# This Machine

- Apple M1 with 8 GB RAM. Run heavy commands (test suites, production builds)
  one at a time, say before starting one, and kill it when its result no
  longer matters. Then confirm with `ps` that no child process (karma,
  headless Chrome) is left.
- In the Bash tool, `cd` triggers a zsh hook that runs `eza` and can hang the
  command until it times out. Use absolute paths, or `bash -c 'cd /abs/dir && …'`.
  If a trivial command stalls, look for a stuck `eza` process.
- The GitLab account here is shared, so an MR's author (e.g. `example.teammate`)
  doesn't say who did the work. Every MR opened from this machine gets the
  label `owner:you` (`glab mr create … --label owner:you`; after
  `/ship` or `ship.sh`, check the label is there). When reading an MR, name
  its owner from the `owner:*` label, not the author.
