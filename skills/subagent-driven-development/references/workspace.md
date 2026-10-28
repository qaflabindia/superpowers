# The Plan Workspace and Ledger

Shared by superpowers:subagent-driven-development and
superpowers:executing-plans. Both executors use the same workspace and the
same ledger format, so a plan can change executors mid-flight and the new
one resumes from the same ledger.

Ensure the work happens in an isolated workspace: use
superpowers:using-git-worktrees to create one or verify the existing one.
Never start implementation on a main/master branch without your human
partner's explicit consent.

Conversation memory does not survive compaction. In real sessions,
executors that lost their place have re-dispatched or re-implemented entire
completed task sequences — the single most expensive failure observed.
Track progress in a ledger file, not only in todos. Harness todos are a
live view; the ledger is the record.

- Each plan owns a workspace: run
  `subagent-driven-development/scripts/sdd-workspace PLAN_FILE` — it prints
  the plan's git-ignored directory
  (`<repo-root>/.superpowers/sdd/<plan-basename>/`), home to every artifact
  for THIS plan: ledger, briefs, reports, review packages, test logs.
  Another plan's directory is never yours to read or write.
- Check for this plan's ledger at `<workspace>/progress.md`. If one exists,
  read [resuming.md](resuming.md) before anything else: it says whose
  ledger it is and where to resume.
- Otherwise create the ledger with its identity as the first line:
  `# SDD ledger — plan: <plan file path>`.
- The ledger is your recovery map: the commits it names exist in git even
  when your context no longer remembers creating them. After compaction,
  trust the ledger and `git log` over your own recollection.
- `git clean -fdx` will destroy the workspace (it's git-ignored scratch); if
  that happens, recover from `git log`.

Read the plan once, note its context and Global Constraints, and create a
todo per task. If the plan names a Spec, read that too: the spec is the
authority the plan argues from, and conflicts inside the plan resolve
against it. A plan with no reachable spec gets a ledger note saying so —
rulings made without one are provisional.

Then run the pre-flight scan: [preflight.md](preflight.md).
