# Parallel Waves (opt-in)

Part of superpowers:subagent-driven-development. Read this only when your
human partner asked for parallel execution of this plan. Without that
request, tasks run one at a time, as SKILL.md says.

A wave is a set of tasks that can be built at the same time because none
needs another's commits and none touches another's files. Each wave task
gets its own implementer in its own worktree; every task still gets its own
task review; the wave lands on the plan branch one task at a time, in task
order. What changes is wall-clock time, not the gates.

## Building the waves (at pre-flight)

After the pre-flight table, compute the waves and write them to the ledger
as `Waves: [1,2,5] [3] [4,6] …` before Task 1.

Two tasks may share a wave only if all of these hold:

- neither lists the other, directly or through a chain, under
  `Depends on:` — and neither Consumes what the other Produces;
- their `Files:` lists share no path;
- neither touches a file every task tends to touch: lockfiles and
  dependency manifests, generated files, migration directories, shared
  fixtures, snapshot files, a central registry or route table. Such a task
  gets a wave of its own.

A plan without `Depends on:` lines gets inferred edges from Consumes /
Produces and shared files; if you cannot tell, the task goes in a wave of
its own. Cap a wave at three tasks. When in doubt, serial: a wrong wave
costs a conflicted merge and a re-run, a serial task costs only time.

## Running a wave

1. Record WAVE_BASE (`git rev-parse HEAD` on the plan branch) and extract
   every wave task's brief (`bash scripts/task-brief PLAN_FILE N`).
2. Give each task its own worktree cut from WAVE_BASE. Prefer the harness's
   own subagent isolation (on Claude Code, the `Agent` tool's worktree
   isolation). Otherwise `git worktree add -b sdd/<plan>/task-N <dir>
   WAVE_BASE`, with `<dir>` outside the repository's working tree so the
   project's test runner never discovers a second copy of the code. If the
   worktree cannot be created (sandbox), run the wave serially and ledger
   that you did.
3. Dispatch all wave implementers in one message, each with its worktree as
   the `Work from:` directory, its brief, and its own report file. Record
   each implementer's identity for the fix loop.
4. As each reports DONE, from the plan-branch checkout (so every ledger
   line lands in this plan's one ledger): `bash scripts/task-verify -C
   <its worktree> PLAN_FILE N -- <its test command>`, then
   `bash scripts/review-package PLAN_FILE WAVE_BASE sdd/<plan>/task-N`
   (worktrees share branches, so the range resolves here), then dispatch
   its task reviewer. Fix loops run per task, in that task's worktree,
   exactly as references/fix-loop.md says, with the same `-C`.

## Landing a wave

Land the clean tasks on the plan branch in task order, one at a time:
`git merge --no-ff sdd/<plan>/task-N` (or cherry-pick the task's range when
the plan's history must stay linear). After each merge, append the usual
completion line, with the commit range as landed on the plan branch.

- **A merge conflicts:** abort it (`git merge --abort`). That task did not
  belong in this wave. Discard its branch and worktree, ledger
  `Wave: Task <N> re-queued — conflicted with <file>`, and run it again,
  serially, from the new plan-branch HEAD after the wave lands.
- **After the last task lands:** run the full suite once with
  `bash scripts/suite-run PLAN_FILE -- <full test command>`. A red suite
  after a clean set of task reviews is an interaction between wave tasks:
  use superpowers:systematic-debugging, fix it as a fix round on the
  task the evidence points at, and ledger the ruling.
- Remove the wave's worktrees and task branches once landed, then start
  the next wave from the new HEAD.

Ledger, per wave: `Wave <k>: tasks <list> landed at <head7>` after the
suite run. On resume, a wave with no such line is incomplete: tasks that
have a completion line landed; the rest re-run from the current HEAD.
