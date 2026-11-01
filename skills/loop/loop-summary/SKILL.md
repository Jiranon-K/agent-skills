---
name: loop-summary
description: Shows the Loop Engineering summaries written since the last time this ran, as a visible session in the Claude app. Read-only; run by the app's scheduled task "loop-summary" daily at 9:30, after the 9:15 launchd loop.
---

# Loop Summary (visible session)

Show the user what the loop did since the last summary. Read-only except the marker file. Reply in Thai, concise.

1. Read the marker `~/loop/state/last-summary-seen` (format `YYYY-MM-DD HH:MM`). Missing → treat as today 00:00.
2. Read `~/loop/summaries/<date>.md` for each date from the marker's date to today. Keep only `## HH:MM` sections later than the marker.
3. Also run `~/loop/bin/loop-state list` (one line per ticket: `<ticket> status=… repo=… [branch=…] [mr=…]`) for work in progress.
4. Reply:
   - No new sections → one line: `ไม่มีอะไรใหม่ตั้งแต่ <marker time>` plus one line of work in progress if any.
   - Otherwise → paste the new sections in time order exactly as written (they already contain links), then one line `งานที่ค้าง:` listing tickets that are `working`, `ready-to-ship`, `mr-open`, or `blocked`, with their MR links.
   Do not add questions that are not in the summaries. Do not re-ask old unanswered questions.
5. Write the current time (`date "+%Y-%m-%d %H:%M"`) to `~/loop/state/last-summary-seen`.
