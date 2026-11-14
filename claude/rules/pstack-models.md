# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat model (omit Agent `model`). Alias entries in a panel list still count toward its fan-out.
# `opus` and `sonnet` are Claude Code aliases that always resolve to the newest version, so no version is pinned here.
# budget: small (medium)
feature, refactoring: sonnet medium
bug-fix: sonnet medium
perf-issue: sonnet medium
hillclimb: sonnet medium
judgment and prose: opus medium
hardest tasks: opus medium
how explorer: sonnet medium
how explainer: opus medium
why investigators: sonnet medium
why synthesizer: opus medium
reflect tooling: sonnet medium
reflect judgment, divergent, synthesizer: opus medium
arena runners: opus medium, sonnet medium
arena cross-judge pool: opus medium, sonnet medium
swarm workers: sonnet medium
architect runners: opus medium, sonnet medium
interrogate reviewers: opus medium, sonnet medium
