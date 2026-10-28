# The Pre-flight Scan

Shared by superpowers:subagent-driven-development and
superpowers:executing-plans. Run it once, before Task 1.

Scan the plan once for conflicts, writing down what you checked as you
check it:

- tasks that contradict each other or the plan's Global Constraints
- anything the plan explicitly mandates that the review rubric treats as a
  defect (a test that asserts nothing, verbatim duplication of a logic block)

The scan's output is a table, not a verdict. "The scan is clean" without
its rows is not a scan you ran.

**Interface rows — both executors.** The plan's Interfaces blocks tell you
where to look. One row for every pair of tasks that share a file or an
interface: the two tasks, what one produces against what the other
consumes, and what you found. Tasks that share nothing get no row; a plan
whose tasks share nothing gets the single line
`Pre-flight: no shared interfaces`.

**Task self-consistency rows — when they run depends on who reads the
brief.** One row per task: whether its own text agrees with itself — the
tests it specifies against the code it specifies, the files it creates
against the files it later touches.

- Under subagent-driven-development, write these rows now. The controller
  never works a brief step by step; this scan is its only read of each
  task's internals before an implementer is dispatched on them.
- Under executing-plans, skip them here. You read every brief in full when
  you take its task, and you check its self-consistency then, before the
  first step. A self-inconsistent brief is ruled on and ledgered exactly
  like a pre-flight row.

Write the table to the ledger. Rule on each conflict it surfaces — the spec
is the binding authority, the plan is its argument — and record each
ruling beside its row. If the scan is clean, proceed without comment. The
review loop (or, inline, the step-by-step `Expected:` checks) remains the
net for conflicts that only emerge from implementation.
