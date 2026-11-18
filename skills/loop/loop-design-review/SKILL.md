---
name: loop-design-review
description: User-run. The owner's design gate of the Loop Engineering system — shows the Designer's package for a task, takes the owner's verdict, then approves it as a ready spec or sends the pushback back for a redesign. Usage `/loop-design-review [<task key>]`. Only run when the user invokes it.
disable-model-invocation: true
---

# Loop design review (user-run)

The user invoking this is the review. You present and record; you never decide. Talk in Thai. Link every card name per `~/loop/workspace.md`.

1. **Pick the task**. With no argument, run `~/loop/bin/loop-spec list proposed`: none → say so and stop; one → use it; several → list them (task, repo, risk) and ask which one.
2. `~/loop/bin/loop-spec status <task>` must print `proposed`. Otherwise say what it is and stop.
3. Read `spec.md`, `design.md` and `decisions.tsv` in the package (`~/loop/bin/loop-spec path <task>`), and `get_task <task>` for the card's own acceptance criteria.
4. **Present**, in this order, short:
   - What will be built, from the user's side, and what the owner's own part is.
   - The chosen shape in two or three sentences, what lost and why, and the cross-judge's verdict.
   - **Card vs spec**: every acceptance criterion the spec adds, drops or rewords against the card. Say "ตรงกับ card" when there is none.
   - Risks, and the files a Worker will touch.
   - For a design over several repos (`repo=a,b` in `loop-spec list`): each part in `parts/<repo key>.md`, the order the parts merge in, and the contract between them.
   - Paths of `design.md` and `spec.md` for a full read.
5. **Ask for the decisions**: each item of "Decisions for the owner" as one question with the Designer's default first. Then ask for the verdict: approve, push back, or stop the task.
6. Act on the verdict:
   - **Approve** with every default accepted → `~/loop/bin/loop-spec approve <task>`, then `~/loop/bin/loop-next`. Say the Worker starts on the next run and a Draft MR follows.
   - **Approve a design over several repos** with every default accepted → a Worker builds one repo, so each part needs its own task. Draft one subtask of the card per repo (title, the part's acceptance criteria, the `repo:` label, the same assignee and sprint, a dependency on the part that must merge before it), show the drafts and wait for a yes. Then create them, and for each one run `~/loop/bin/loop-spec part <task> <repo key> <new task key>`: it writes that part as the new task's ready spec. Finish with `~/loop/bin/loop-next`. `loop-spec approve` refuses such a design.
   - **Approve with a changed decision or scope** → that is a pushback: the spec must say what the owner decided before a Worker reads it.
   - **Push back** → write the owner's points in their own words, plus the answers from step 5, to `~/loop/bin/loop-spec feedback <task>` on stdin, then `~/loop/bin/loop-next`. Say the Designer redesigns on the next run.
   - **Stop** → change nothing and say the package stays `proposed`.

Never edit `spec.md` or `design.md` yourself, and never approve a task the user did not name in this run.
