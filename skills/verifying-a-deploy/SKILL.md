---
name: verifying-a-deploy
description: Use when a deploy or release just happened or is about to, or your human partner asks whether production (or staging) is healthy after a change
---

# Verifying a Deploy

## Overview

Check that what was deployed is what is running, and that it works — by
comparing the live system against how it looked before, not against an
ideal. Report a verdict with evidence.

**Core principle:** A green pipeline proves the deploy ran. Only checks
against the running system prove it works. No verdict without evidence
from this session (superpowers:verification-before-completion).

**Announce at start:** "I'm using the verifying-a-deploy skill to check the deploy."

**Read-only.** This skill observes and reports. It never changes code,
configuration, or infrastructure, and never rolls back; when something is
wrong it hands your human partner the evidence and the options.

## The checks

Take them from the `## Deploy Configuration` record
(superpowers:configuring-deploys); ask for anything missing. Strongest
first:

1. **Version check** — a version or health endpoint reports the new
   version or commit SHA. Without it you may be checking the old release.
2. **Health checks** — the record's URLs (`scripts/http-probe`, one line
   per URL: status, time, size) and status commands.
3. **Error signals** — any log, error-rate, or alerting query the record
   names (run as given; read-only).
4. **User-visible pages** — when the change touches a UI and you have a
   browser tool: load the main pages, note console errors, keep
   screenshots as evidence.

A package or app release swaps these for: the registry or store shows the
new version, and a clean install of it works (`npm view`, `pip index
versions`, installing into a scratch directory).

Keep artifacts in `.superpowers/deploy/<environment>/`, and make sure
`.superpowers/deploy/.gitignore` exists containing `*`.

## Modes

**Baseline (before deploying).** Run every check once, with `--log` into
`baseline.tsv`, and record error counts and page notes beside it. Without a
baseline, a post-deploy run is a health check, not a comparison; say so.

**Quick (right after deploying, the default).** Wait until the version check
shows the new release (`poll-until` from superpowers:landing-and-deploying,
bounded), then run every check once and compare against the baseline.

**Watch (on request, or after a risky change).** Repeat the checks every
minute for the agreed window (default 10 minutes), logging each round.

## Judging results

**Alert on change, not on absolutes.** Three errors that were there before
the deploy are not a finding; one new one is. Latency over twice the
baseline is a regression; 1.5× is usually noise.

**Persistence.** In watch mode, a finding counts once it shows in two
consecutive rounds; a single blip is noted, not alerted.

| Severity | Examples |
|----------|----------|
| CRITICAL | Unreachable, 5xx, version check still shows the old release after the deploy settled |
| HIGH | New errors in logs or console; a health check failing that passed in the baseline |
| MEDIUM | Latency over 2× baseline; degraded but working page |
| LOW | New 404s on secondary links; cosmetic differences |

**On CRITICAL or HIGH, stop and report immediately** — in watch mode,
don't finish the window first. Offer: investigate
(superpowers:systematic-debugging, starting from the evidence), keep
watching if it may be transient, or roll back
(superpowers:landing-and-deploying's rollback step, on their go).

## Report

```
VERIFY <environment> — <url or package>   <timestamp>
Version:  <expected> → <seen>   (<match / MISMATCH / not checkable>)
Checks:   <N> run, <N> ok, <N> failing  (baseline: <yes / none>)
Findings: <severity> <what changed> — <evidence: probe line, log query, screenshot path>
VERDICT:  HEALTHY | DEGRADED | BROKEN | UNVERIFIED
```

UNVERIFIED is an honest verdict: the version can't be checked, the URL
needs a VPN, there was no baseline for a subtle change. Say what would make
it verifiable.

When healthy, offer to make this run the new baseline.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The pipeline is green, it's deployed" | Check the version endpoint. Pipelines succeed against the wrong target too. |
| "It returns 200, so it's healthy" | Compare with the baseline: errors, latency, content. |
| "One timeout, it's broken" | One round is a blip. Two consecutive rounds is a finding. |
| "There were already errors, so new ones don't matter" | New errors are exactly what a deploy introduces. Count the change. |
| "I'll quickly fix the bug in production" | This skill is read-only. Report, then work through the normal flow. |
| "No baseline, but it looks fine — HEALTHY" | Without a baseline say what you checked and that it wasn't compared. |
