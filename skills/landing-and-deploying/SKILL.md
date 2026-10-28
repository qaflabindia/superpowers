---
name: landing-and-deploying
description: Use when a pull or merge request is ready and your human partner wants it merged - and, in a project that deploys or publishes, released and checked in production
---

# Landing and Deploying

## Overview

Take a reviewed PR from "ready" to "merged, released, and verified": wait for
CI, show your human partner exactly what is about to happen, merge on their
go, follow the deploy, check the result, and report with evidence.

**Core principle:** Merging, deploying, and rolling back are irreversible
and shared. Every one of them happens on your human partner's explicit go,
given for this PR at this commit. Waiting, reading, and checking you do
without asking.

**Announce at start:** "I'm using the landing-and-deploying skill to merge and deploy this PR."

## Before you start

- **The deploy record.** Read the `## Deploy Configuration` section of the
  project's instructions file. None? Use superpowers:configuring-deploys
  first, or, if your human partner wants to proceed without one, ask the
  few things this run needs (how it deploys, how success shows, how to roll
  back).
- **The PR.** From the current branch or the number your human partner
  gave. With GitHub `gh pr view --json number,state,title,url,headRefOid,baseRefName,mergeable`;
  other forges: [references/forges.md](references/forges.md). Without a
  forge CLI, ask for the URL and do the merge step through your human
  partner. Merged or closed already:
  say so and stop (a merged PR may still need superpowers:verifying-a-deploy).

Long waits use this skill's `scripts/poll-until`: it re-runs a read-only
status command, prints a few lines, and exits 0 (done), 1 (failed), or
124 (timed out). Keep `--timeout` under your harness's command time limit
and loop, or run it in the background where your harness allows.

## Step 1: CI and mergeability

```bash
bash scripts/poll-until --interval 30 --timeout 540 --pending-exit 8 -- gh pr checks <N> --required
```

(`gh pr checks` exits 0 when all pass, 8 while pending, 1 on a failure;
judge other CLIs by exit code too — a pattern like `fail` matches "0
failing". On GitLab, `glab ci status`.) Failing checks or conflicts: **stop** and
report which checks and why, from their logs. Fixing them is new work on
the branch, under superpowers:systematic-debugging, with your human
partner's go; then this skill starts over.

## Step 2: Readiness report — the gate

Gather, then present in one message:

- **CI:** each required check and its conclusion, at head `<sha7>`.
- **Tests:** the full suite on the PR head. On a clean checkout of that
  head, `bash <subagent-driven-development>/scripts/suite-run --lookup --
  <full test command>` prints a recorded green run for this exact tree;
  cite it. No record: run it (`suite-run - -- <command>` records it).
- **Review:** approvals, unresolved threads, commits pushed after the last
  approval.
- **Release bookkeeping:** if the project keeps a version or changelog,
  whether this branch updated it (superpowers:preparing-a-release).
- **The description:** does it still match the commits?
- **What will happen:** merge method (and merge queue, if any), then the
  deploy path from the record — which pipeline or command, staging first
  or straight to production — and how you will verify.

Then ask: merge, hold, or merge despite the warnings you listed. Blockers
(red CI, failing suite, conflicts) have no "merge anyway" from you; only
your human partner can choose to override one, by saying so.

**The go covers this PR at this head SHA.** A new commit before the merge
means a new report and a new go. If deploying is a separate manual step,
ask whether the go covers it too.

## Step 3: Merge

Use the repo's method, letting the forge honor branch protection and merge
queues: `gh pr merge <N> --auto` (add `--squash`, `--merge`, or `--rebase`
per the record), or `glab mr merge`.

**After any non-zero exit, read the PR's state before doing anything else.**
`gh pr view <N> --json state,mergeCommit` — `MERGED` means it landed (note
the merge SHA), `OPEN` with auto-merge set means it is queued (wait with
`poll-until`), anything else: report the error and the state, and stop.
Never re-run the merge command blind, and never force-push.

Delete the remote branch only if the record or your human partner says the
project does. A local worktree goes through
superpowers:finishing-a-development-branch's cleanup rules.

## Step 4: Follow the deploy

Per the record's trigger:

- **Pipeline on merge:** find the run for the merge SHA
  (`gh run list --branch <base> --json databaseId,headSha,status,conclusion,workflowName`)
  and wait on it. `gh run view` exits 0 whatever the run's state, so turn
  the state into an exit code:

  ```bash
  bash scripts/poll-until --interval 30 --timeout 540 --pending-exit 8 -- sh -c '
    r=$(gh run view <run-id> --json status,conclusion -q ".status+\" \"+.conclusion")
    echo "$r"
    case "$r" in "completed success") exit 0 ;; completed*) exit 1 ;; *) exit 8 ;; esac'
  ```
- **Platform auto-deploy:** poll the record's deploy status command, or the
  version endpoint until it reports the new version or SHA
  (`poll-until -- sh -c 'curl -fsS <version-url> | grep -q <sha7>'` —
  without `--pending-exit`, every non-zero exit counts as pending).
- **Manual trigger:** run the record's command only with the go from Step
  2 covering it; otherwise hand your human partner the exact command.
- **Package or app release:** tagging and publishing are irreversible
  publications. Ask, even when the merge was approved.
- **Staging first:** deploy and verify staging, report, and ask before
  production unless the go said "straight through".

A failed or timed-out deploy: stop, show the failing step's log, and offer
investigate, roll back (Step 6), or wait longer.

## Step 5: Verify

Use superpowers:verifying-a-deploy (single pass) against the environment
just deployed. Docs-only or config-only changes still get one check that
the service answers; a project that doesn't deploy ends at Step 3.

## Step 6: Roll back — only on your human partner's go

When verification or the deploy fails, present the record's rollback method
and what it does, with the evidence. On their go: platform rollback
command, or `git revert -m 1 <merge-sha>` (drop `-m 1` for a squash or
rebase merge) on a fresh branch from the base, through a PR when the base
is protected. Then follow that deploy and verify again.

## Step 7: Report

```
LANDED: PR #<N> "<title>" → <base> at <merge-sha7> (<method>, <queue/direct>)
CI:     <checks> green at <head-sha7>
Deploy: <pipeline/command> → <succeeded/failed> in <duration>
Verify: <HEALTHY / DEGRADED / BROKEN / UNVERIFIED> — <evidence lines>
Next:   <rollback status, follow-ups, or "none">
```

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "They said ship it earlier, that covers the merge" | The go is for this PR at this head, after the readiness report. Ask. |
| "CI is just flaky, merge anyway" | A red check is a blocker. Report it; overriding is your human partner's call. |
| "The merge command failed, run it again" | It may have landed. Read the PR state first. |
| "Deploy succeeded, so production is fine" | A green pipeline proves it ran. Verification proves it works. |
| "It's broken — I'll revert right away to limit damage" | Rollback is a production change too. Show the evidence and ask. |
| "Waiting is wasting time, I'll check back later" | Use poll-until with a bounded timeout. Silent gaps lose the thread. |
