# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat model (omit Agent `model`). Alias entries in a panel list still count toward its fan-out.
# `opus` and `sonnet` are Claude Code aliases that always resolve to the newest version, so no version is pinned here.
# defaults: 3
# budget: small (medium)
feature, refactoring: opus medium
bug-fix: opus medium
perf-issue: opus medium
hillclimb: opus medium
judgment and prose: opus medium
arena runners: opus medium, sonnet medium
arena cross-judge pool: opus medium, sonnet medium
swarm workers: sonnet medium
interrogate reviewers: opus medium, sonnet medium
