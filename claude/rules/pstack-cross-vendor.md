# pstack cross-vendor seat

Claude Code's `Agent` tool runs only Claude models, so a pstack step that wants a model from another vendor (the arena cross-judge, an interrogate adversary, the cross-model review in show-me-your-work) uses `~/loop/bin/loop-ask` instead of skipping the seat.

- `~/loop/bin/loop-ask gpt <prompt file> [<diff base ref>]` asks GPT-6-Luna (high) through `codex`; `gemini` asks Gemini 4 Neon (high) through `agy`. Try `gpt` first, then `gemini`. If both fail, skip the seat and say so. For a high-risk change ask both.
- Neither edits anything. `gpt` runs in codex's read-only sandbox and may run read-only commands; `gemini` only reads files. Run it from the directory it must read, write everything it must judge into the prompt file or name the paths in it, and pass a base ref when it reviews a diff.
- Its answer is a claim, never proof. Run a repro yourself before you keep a finding it reports.
- It never replaces a Claude seat on a panel: it adds the outside vendor.
