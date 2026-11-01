# agent-skills

Personal Claude Code setup for a Mac, published with example values.

- `skills/<bucket>/<name>/SKILL.md` — skills written or adapted here. Use example values only: no real names, hosts, IDs or ticket keys. Buckets:
  `engineering`, `productivity`, `design`, `loop`, `personal`.
- `claude/` — global `CLAUDE.md`, `AGENTS.md`, statusline, agents.
- `loop/` — Loop Engineering runner and launchd job. Logs, state and summaries stay on the machine.
- `scheduled/` — scheduled-task prompts (daily-standup, loop-summary).
- Skills available from a plugin are listed in `plugins.md`, never copied in.
- Never commit secrets, `settings.json`, or anything under `~/loop/{logs,state,summaries}`.
- After adding or removing a skill, update the table in `README.md`.
