---
name: loop-summary
description: Shows the Loop Engineering summaries written since the last time this ran, as a visible session in the Claude app, plus the tasks that need a grill before an agent can start. Read-only; run by the app's scheduled task "loop-summary" daily at 9:30, after the 9:15 launchd loop.
---

# Loop Summary (visible session)

Show the user what the loop did since the last summary. Read-only except the marker file. Reply in Thai, concise.

1. Read the marker `~/loop/state/last-summary-seen` (format `YYYY-MM-DD HH:MM`). Missing → treat as today 00:00.
2. Read `~/loop/summaries/<date>.md` for each date from the marker's date to today. Keep only `## HH:MM` sections later than the marker.
3. Run `~/loop/bin/loop-state list` (one line per task: `<task> status=… repo=… [branch=…] [mr=…]`) for work in progress.
4. Read the section `### ต้อง grill ก่อน Agent เริ่มได้` of `~/loop/state/last-triage.md`.
5. Reply:
   - No new sections → one line: `ไม่มีอะไรใหม่ตั้งแต่ <marker time>`.
   - Otherwise → paste the new sections in time order exactly as written (they already contain links).
   - Then `งานที่ค้าง:` listing tasks that are `working`, `ready-to-ship`, `mr-open` or `blocked`, with their MR links. For `ready-to-ship`, say the repo forbids agent pushes and the owner pushes by hand.
   - Then `ต้อง grill ก่อน Agent เริ่ม:` one line per row of step 4: task link, who to ask, the topic. Do not repeat the question text and do not add questions of your own. Omit the block when the table says "ไม่มี".
6. Write the current time (`date "+%Y-%m-%d %H:%M"`) to `~/loop/state/last-summary-seen`.
