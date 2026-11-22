---
name: loop-summary
description: Shows the Loop Engineering summaries written since the last time this ran, plus the designs that wait for the owner's review and the tasks that need a grill before an agent can start. Read-only; `/loop-start` follows it after each round, and the owner can run it alone.
---

# Loop Summary (visible session)

Show the user what the loop did since the last summary. Read-only except the marker file. Reply in Thai, concise.

1. Read the marker `~/loop/state/last-summary-seen` (format `YYYY-MM-DD HH:MM`). Missing → treat as today 00:00.
2. Read `~/loop/summaries/<date>.md` for each date from the marker's date to today. Keep only `## HH:MM` sections later than the marker.
3. Read the "Current sprint" table and the list "Out-of-sprint tasks the owner asked for" in `~/loop/workspace.md`, and per space run the read-only `query_view` `space=<key>`, `sprint=<id>`, `view_type=table`, `group=none`. Its keys plus the owner's list are the sprint keys. Every task list below shows only sprint keys; leave every other task out. A failed call: say so in one line and show every task.
4. Run `~/loop/bin/loop-state list` (one line per task: `<task> status=… repo=… [branch=…] [mr=…]`) for work in progress.
5. Read the section `### ต้อง grill ก่อน Agent เริ่มได้` of `~/loop/state/last-triage.md`, and run `~/loop/bin/loop-spec list proposed` (one line per design that waits for review: `<task> proposed repo=… risk=…`).
6. Reply:
   - No new sections → one line: `ไม่มีอะไรใหม่ตั้งแต่ <marker time>`.
   - Otherwise → paste the new sections in time order exactly as written (they already contain links).
   - Then `งานที่ค้าง:` listing tasks that are `working`, `ready-to-ship`, `mr-open` or `blocked`, with their MR links. For `ready-to-ship`, say the repo forbids agent pushes and the owner pushes by hand.
   - Then `รอรีวิว design:` one line per proposed design: task, repo, risk and the command `/loop-design-review <task>`. This block comes first among the pending ones because a Worker cannot start until the owner reviews. Omit it when there is none.
   - Then `ต้อง grill ก่อน Agent เริ่ม:` one line per row of step 5: task link, who to ask, the topic. Do not repeat the question text and do not add questions of your own. Omit the block when the table says "ไม่มี".
   - Last line: `ดูภาพรวม: /loop-board`. Do not run it.
7. Write the current time (`date "+%Y-%m-%d %H:%M"`) to `~/loop/state/last-summary-seen`.
