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

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues (`gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
