# The Suite Budget

For superpowers:subagent-driven-development; the lookups in the table
serve every skill that needs a green suite. Decide it once, at pre-flight;
record it in the
ledger as `Suite budget: <S>s per run — <per-task | batched every <K> tasks>`.

Every full-suite run on a tree that a run already proved green is waste. A
green run is recorded once — by `scripts/suite-run`, keyed by tree, in the
repository's shared store — and every later step that needs "green on this
tree" looks it up (`bash scripts/suite-run --lookup -- <command>`) instead
of running it again:

| Step | Looks up instead of re-running |
|------|-------------------------------|
| New worktree baseline (superpowers:using-git-worktrees) | the base commit's tree, from the last time it was proved |
| `task-verify` after an implementer reports | the implementer's own `suite-run` on its final commit |
| Finish (references/finish.md) and finishing-a-development-branch Step 1 | the last task's, or the final fix wave's, run |
| superpowers:landing-and-deploying's readiness report | the pushed head's tree |

## How long is a run?

The baseline run in the new worktree recorded its seconds
(`suite-run --lookup` prints them). No baseline run? Use the first task's.

## Per-task (a run takes 120 seconds or less)

Fill the implementer template's `[SUITE_POLICY]` with:

> After your last commit, run the full suite once through
> `bash <absolute path to this skill>/scripts/suite-run - -- <full test command>`.
> Red: fix, commit, and run it again. Report that command as your Test
> command.

`task-verify` then finds the record and cites it — one full run per task,
not two.

## Batched (a run takes longer than 120 seconds)

Fill `[SUITE_POLICY]` with:

> Before committing, run the test files for every module you changed, and
> report that command as your Test command. Do not run the full suite: the
> controller runs it.

Then run `bash scripts/suite-run PLAN_FILE -- <full test command>` yourself
after every K-th task (K = 3 by default; 1 for a task that changes a shared
interface) and before the final review. A red batched run: find the task
with `git bisect run <full test command>` over the commits since the last
green line — each task is its own commit range, so the culprit is a task —
and reopen that task's fix loop with the failing output.

Your human partner can set either policy or a different K; their word
beats the 120-second line.
