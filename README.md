# agent-skills

My Claude Code setup for daily frontend work: the skills I actually use, the global
instructions, the Loop Engineering automation, and the scheduled tasks. Shared with example values; see Setup after install.

Skills that ship as plugins (Matt Pocock, superpowers, impeccable, …) are not copied
here — see [`plugins.md`](plugins.md).

## Layout

```
skills/
  engineering/   branch → review → MR workflow
  productivity/  team communication and team context
  design/        UI reference database
  loop/          Loop Engineering (triage → work → review → ship)
  personal/      skills built with Claude for my own use
claude/          ~/.claude: CLAUDE.md, AGENTS.md, statusline.sh, agents/
loop/            ~/loop/bin/loop-run.sh, loop-state, launchd job, spec.html
scheduled/       ~/.claude/scheduled-tasks: daily-standup, loop-summary
plugins.md       plugins to install on a new machine
scripts/install.sh
```

## Install on a Mac

```bash
git clone git@github.com:Jiranon-K/agent-skills.git ~/Projects/agent-skills
~/Projects/agent-skills/scripts/install.sh --dry-run
~/Projects/agent-skills/scripts/install.sh
```

`install.sh` symlinks the generic skills, so `git pull` keeps them current. Your own
setup — `claude/`, `loop/`, `scheduled/`, `skills/loop/` — is copied as a template
only where nothing exists yet, and never overwritten. `loop/bin/loop-state` is the exception: it is symlinked, since the runner and loop skills share it. `--force` replaces existing
generic skills only, moving the old ones to `~/.claude/backups/`.

Then install the plugins in [`plugins.md`](plugins.md) and run `/team-context` once
per team.

## Setup after install

The templates use example values. Replace them in the copied files:

| Placeholder | Means |
| --- | --- |
| `gitlab.example.com`, `example-team` | your GitLab host and group |
| `example.atlassian.net`, `EX-123`, `PB-*` | your Jira site and project keys |
| `https://www.notion.so/<issues-db-id>` | your Notion issues database |
| `project-a` / `web-app`, `project-b` / `project-b-web`, `project-b-api` | your workspace folders and repos |
| `owner:you`, `your.username`, `@you` | your MR label and usernames |
| `/Users/YOUR_USER` | your home folder (launchd does not expand `~`) |

For the loop job, copy `loop/launchd/com.example.loop.plist` to
`~/Library/LaunchAgents/`, fix its paths, then:

```bash
launchctl load ~/Library/LaunchAgents/com.example.loop.plist
```

## Daily workflow

| Stage | Skill |
| --- | --- |
| Pick up a ticket | `/understand <ticket>` |
| Shape a change | `superpowers:brainstorming`, `mattpocock-skills:grilling` (plugins) |
| Build | `/mattpocock-skills:tdd` (plugin) |
| Check in a browser | `/e2e` |
| Clean up the branch | `/review-branch` |
| Open the MR | `/open-mr` (or `/ship-branch` for all three gates) |
| Set up who is who | `/team-context` (once per team) |
| Talk to the team | `/reply`, `/blocker-ping`, `/be-review` |

## Loop Engineering

launchd runs `loop/bin/loop-run.sh` daily at 09:15. It calls
`/loop-triage` → `/loop-work` → `/loop-review` → `/loop-work --finish`, and the
`loop-summary` scheduled task shows the result at 09:30. Human gates:
`/loop-e2e`, `/loop-ship`, `/merge-approved`. Logs, state and summaries stay in
`~/loop` and are not committed.

## Scheduled tasks

| Task | When | What |
| --- | --- | --- |
| `daily-standup` | 17:47 Mon–Fri | Standup for Discord from the day's sessions and git activity |
| `loop-summary` | 09:30 daily | Shows new loop summaries |

## Skills

| Bucket | Skill | What it does |
| --- | --- | --- |
| engineering | `be-review` | Reviews a backend proposal from the frontend side |
| engineering | `e2e` | Browser end-to-end check of the branch changes |
| engineering | `open-mr` | Pushes, waits for CI, opens the MR |
| engineering | `review-branch` | Simplify, review, fix, split commits before an MR |
| engineering | `ship-branch` | review-branch → e2e → open-mr in gated steps |
| productivity | `blocker-ping` | Follow-ups for blockers that keep rolling over |
| productivity | `reply` | Reply drafts in each person's tone; sends via Claude in Chrome after approval |
| productivity | `team-context` | Interview that saves who is who, tone and mentions per team |
| design | `ui-ux-pro-max` | Searchable styles, palettes, fonts, UX rules |
| loop | `loop-triage` | Coordinator: lists, labels and picks a ticket |
| loop | `loop-work` | Worker: implements one low-risk ticket |
| loop | `loop-review` | Reviewer: read-only review of the Worker diff |
| loop | `loop-summary` | Shows summaries since last run |
| loop | `loop-e2e` | User-run browser e2e for a loop MR |
| loop | `loop-ship` | User-run push and MR for project-b-web |
| loop | `merge-approved` | User-run merge after human review |
| personal | `understand` | Thai HTML explainer for a component or ticket |
| personal | `read-book` | Thai explanation of English technical text |
| personal | `ui-inspire` | Researches UI patterns, then designs an original UI |
| personal | `dev-challenge-generator` | Frontend Mentor-style portfolio challenges |
