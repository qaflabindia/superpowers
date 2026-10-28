# Resuming From an Existing Ledger

Shared by superpowers:subagent-driven-development and
superpowers:executing-plans. This plan's workspace already has a ledger at
`<workspace>/progress.md`.

If the ledger's first line names your plan file, tasks with a `Task <N>:
complete` line are DONE — do not re-dispatch or re-implement them; resume
at the first task without one. A task whose last line is a fix round is
mid-loop: under subagent-driven-development, resume the loop at the next
round; under executing-plans, finish the task yourself. A ledger whose
first line names a different plan file — or a stray ledger at the old flat
path `.superpowers/sdd/progress.md` — is another plan's progress: leave it
in place and start your own, fresh.

A ledger written by the other executor is still yours if its first line
names your plan. Its `Ruling:` lines bind you exactly as your own do.
