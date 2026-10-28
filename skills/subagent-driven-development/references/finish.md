# Finish

Shared by superpowers:subagent-driven-development and
superpowers:executing-plans. The final whole-branch review is done and its
fixes are committed.

Before you delete anything, collect from the ledger, in the order they
were written:

- every line containing `Ruling:` — preflight rulings, plan-defect rulings,
  parked findings, breaker adjudications, final-review rulings, all of
  them — into your final message under "Rulings I made", each with what it
  costs if wrong;
- every `minor (deferred)` line into your final message under "Deferred
  minors".

Both lists are exhaustive: if the ledger holds a line, the list holds it.
Your final message is the only place the decisions you took on your human
partner's behalf — and the findings you chose not to act on — reach them.
They read it and rework whatever you got wrong. A ruling that dies with
the workspace was a decision made in secret.

Then delete this plan's workspace directory (`rm -rf <workspace>`) — the
git history is the record now. Sibling directories belong to other plans;
leave them alone.

Use superpowers:finishing-a-development-branch.
