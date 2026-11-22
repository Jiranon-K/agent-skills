---
name: loop-start
description: Starts the Loop Engineering system on the owner's command. Runs one round of the runner (clean, triage, open Designers and Workers in Orca), or one task only, then shows what waits for the owner. Also pauses and resumes the chain that starts the next round by itself. Nothing in the Loop starts on a timer. Usage `/loop-start [<task key> | stop | resume]`.
---

# Loop Start

The owner typing this is the request to run the Loop. Reply in Thai, concise. One plain shell command per call, with every path written out.

## `/loop-start stop`

Run `touch ~/loop/state/paused`. Say that sessions already open keep working, and that no new round starts until `/loop-start resume`. Stop here.

## `/loop-start resume`

Run `rm -f ~/loop/state/paused`, then go on as `/loop-start` with no argument.

## `/loop-start` and `/loop-start <task key>`

1. If `~/loop/state/paused` exists, say the Loop is paused and that this one round still runs; leave the file.
2. Run the runner and wait for it. It takes a few minutes: triage is one headless model call.
   - No argument: `~/loop/bin/loop-run.sh`
   - One task: `ONLY_TASK=<task key> ~/loop/bin/loop-run.sh`. It triages that task alone. A task with an approved spec gets a Worker; a task without one gets a Designer.
3. Read what the round did: the sections of `~/loop/logs/<today>.md` written by this run (their `## HH:MM` is the time you started or later). A line with `FAILED` or `skipped` is shown to the owner as it is, with its reason.
4. Show what waits for the owner by following the `loop-summary` skill (`~/.claude/skills/loop-summary/SKILL.md`): new summary sections, work in progress, designs that wait for review, tasks that need a grill.
5. Last lines:
   - `ดู session ทั้งหมดใน Orca` and, when a Worker or Designer was opened, its name (`loop <task>` or `design <task>`).
   - `รอบถัดไปเริ่มเองเมื่อ session จบ หรือเมื่อ approve design` unless the Loop is paused.

## Rules

- Never run a second round while one is running: when the runner logs `skipped — previous run still active`, say so and stop.
- Never approve a design, merge, or post a comment from here. Those stay with `/loop-design-review` and `/merge-approved`.
- When the runner says Orca did not start, say so and stop. Do not start sessions another way.
