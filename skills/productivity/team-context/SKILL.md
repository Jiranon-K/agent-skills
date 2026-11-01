---
name: team-context
description: Interviews the user one question at a time about themselves and their teammates (roles, duties, how to talk to each person, @mentions per app, chat channels, and how Claude may read or send messages) and saves the answers as a private per-team file outside any repo. Use when setting up a new machine or team, before reply, blocker-ping, be-review or daily-standup need to know who is who, or when a teammate joins or leaves.
argument-hint: "[team-name] [update]"
---

# Team context

Builds `~/.claude/teams/<team>.md`: who the owner of this machine is, who they work
with, how to address each person, and how Claude may reach them. Communication skills
read this file instead of guessing names, tone or mentions.

## When to use

- First time on a machine or a team, or `reply` / `blocker-ping` says no team file was found.
- Someone joined, left, changed role, or a channel moved → run with `update`.

## When not to use

- Repo or product context (stack, domain, glossary) → that belongs in the repo's own docs.

## Where the file lives

- One file per **team**, not per repo: `~/.claude/teams/<team>.md`. The frontmatter
  `repos:` lists the repo paths (globs allowed) that belong to the team; a skill finds
  its team by matching the current directory against every team file's `repos:`.
- Never write it inside a git repository and never commit it: it holds people's names,
  nicknames and how you talk to them. The template in this skill uses example names only.

## Workflow

1. **Pick the team.** From the argument, or from the current repo: match it against
   existing `~/.claude/teams/*.md`. Found + `update` → load it and only ask about what
   changed. Found without `update` → show a summary and ask whether to update it.
   None → ask for a short team name and which repo folders belong to it.
2. **Look things up before asking.** Use what is available, skip what is not:
   - Owner: `git config user.name` / `user.email`, Jira `atlassianUserInfo`.
   - Teammates: `git shortlog -sne` on the team's repos, `glab api projects/:id/members`,
     Jira `lookupJiraAccountId`, Notion `notion-get-users`.
   Present what was found as a candidate list for the user to confirm, never as fact.
3. **Interview — one question per message**, plain language, short options where possible.
   Order:
   1. **The owner (you) first:** name and nickname, role, what you do and can do,
      responsibilities, the language and particles you write in, your own handles on
      each app (so Claude never mentions you by mistake and signs as you correctly).
   2. **Team size**, then the list of people (confirm the looked-up candidates).
   3. **For each person**, one at a time:
      - name and nickname, role, responsibilities, what you usually talk to them about;
      - relationship and tone: e.g. senior → polite sibling-style Thai, ends with ครับ;
        same batch → casual, friendly, no particle; English-only, formal, etc.;
      - how fast they usually answer and the best time to ask, if it matters;
      - mentions per app: Discord handle (and user ID for webhooks), Jira account ID
        and display name, Notion user, GitLab username.
   4. **Channels:** which apps the team uses for what (daily standup, bugs, release,
      DMs), with the URL of each Discord channel or thread Claude may open.
   5. **How Claude may interact:** reading (open the channel with Claude in Chrome,
      or a screenshot from the user) and sending (see Rules). Offer the defaults below;
      record what the user picks.
4. **Draft the file** from [`references/team-template.md`](references/team-template.md),
   show it, apply corrections, then write it. Create `~/.claude/teams/` if needed.
5. **Confirm** with the file path and one line per person.

## Rules

- Ask only what cannot be looked up; one question per message; skip a question the user
  declines and leave the field empty rather than guessing.
- Store handles and IDs only, never passwords, tokens, webhook URLs or phone numbers.
  A webhook URL belongs in the environment (e.g. `DISCORD_WEBHOOK_URL`), not this file.
- No health or private details about anyone.
- Sending rules written into the file (defaults):
  1. Claude drafts; the user approves that exact text and destination.
  2. Claude in Chrome opens the channel URL from this file, types the message, and takes
     a screenshot of the composer before sending.
  3. After sending, a screenshot confirms it was posted.
  One approval covers one message. Never send to a person or channel not in this file.

## Next Step

The file is ready: `reply`, `blocker-ping`, `be-review` and `daily-standup` pick it up
on their next run. Re-run `/team-context <team> update` when the team changes.
