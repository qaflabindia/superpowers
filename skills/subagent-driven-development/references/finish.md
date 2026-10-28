# Finish

Shared by superpowers:subagent-driven-development and
superpowers:executing-plans. The final whole-branch review is done and its
fixes are committed.

First, the final tree's suite evidence. If the ledger's last `Suite:` line
names the tree `git rev-parse HEAD^{tree}` prints now and `git status
--porcelain` is empty, it stands. Otherwise run the project's full test
command through subagent-driven-development's suite-run (it records no
evidence for uncommitted changes, so find out why the tree is dirty first):
`bash scripts/suite-run PLAN_FILE -- <full test command>` (from that
skill's directory). You run it yourself, not a subagent: this is the
independent check on every report that said "tests pass". A red run stops
the finish: report the failures to your human partner and stop, as
finishing-a-development-branch's Step 1 would.

Before you delete anything, collect from the ledger, in the order they
were written:

- every line containing `Ruling:` — preflight rulings, plan-defect rulings,
  parked findings, breaker adjudications, final-review rulings, all of
  them — into your final message under "Rulings I made", each with what it
  costs if wrong;
- every `minor (deferred)` line into your final message under "Deferred
  minors";
- the last `Suite: green on tree …` line, verbatim, under "Suite
  evidence". finishing-a-development-branch cites it instead of re-running
  the suite when the tree still matches.

Both lists are exhaustive: if the ledger holds a line, the list holds it.
Your final message is the only place the decisions you took on your human
partner's behalf — and the findings you chose not to act on — reach them.
They read it and rework whatever you got wrong. A ruling that dies with
the workspace was a decision made in secret.

Then delete this plan's workspace directory (`rm -rf <workspace>`) — the
git history is the record now. Sibling directories belong to other plans;
leave them alone.

Use superpowers:finishing-a-development-branch.
