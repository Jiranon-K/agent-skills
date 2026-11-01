# Plugins

Skills that come from these plugins are **not** copied into this repo. Install them
with Claude Code instead, so they stay current with upstream.

## Marketplaces

```bash
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add obra/superpowers-marketplace
claude plugin marketplace add pbakaus/impeccable
claude plugin marketplace add typesafe-ai/skills
claude plugin marketplace add makenotion/claude-code-notion-plugin
```

## Enabled plugins

| Plugin | Marketplace | Used for |
| --- | --- | --- |
| `mattpocock-skills` | claude-plugins-official | tdd, to-spec, to-tickets, implement, prototype, grilling, code-review, research |
| `superpowers` | superpowers-marketplace | brainstorming, systematic debugging, verification, plans |
| `code-simplifier` | claude-plugins-official | simplify pass |
| `commit-commands` | claude-plugins-official | commit helpers |
| `playwright` | claude-plugins-official | browser automation |
| `typescript-lsp` | claude-plugins-official | TypeScript LSP |
| `mongodb` | claude-plugins-official | MongoDB tools |
| `impeccable` | impeccable | UI design and polish |
| `typesafe` | typesafe-ai | type-safe AI patterns |
| `notion` | anthropic-plugin-directory | Notion workspace |

`settings.json` is not stored here: it holds machine-specific permissions, hooks
and env. Re-enable the plugins above from `/plugin` on a new machine.
