# Commands in a worktree session

A session that runs inside a git worktree (`.claude/worktrees/<name>`) has every Bash command checked to stay inside that worktree. A command the check cannot read is refused, not asked about.

- One plain command per Bash call, with every path written out. No shell variables, no `$(...)`, no loops, and no `;`, `&&` or `|` around `git`, `glab`, `sed` or `lsof`.
- Run git from the worktree itself. Never `git -C <main checkout>` and never `cd` out to it. To read the base branch, `git fetch origin <base>` and use `origin/<base>`.
- Change files with Edit or Write, never with `sed -i` or a script that rewrites them.
- Put long text (an MR description, an issue body, a note) in a file with Write and pass the file to the command.
- A refused command is never sent again in another spelling of the same shape. Split it into plain commands.
