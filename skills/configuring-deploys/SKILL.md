---
name: configuring-deploys
description: Use when a project's release or deploy process is unknown and you are about to land, release, deploy, or verify it - or your human partner asks you to set up or record how this project deploys
---

# Configuring Deploys

## Overview

Find out how this project gets from merged code to something running or
published, confirm it with your human partner, and record it once in the
project's instructions file. superpowers:landing-and-deploying and
superpowers:verifying-a-deploy read that record instead of guessing again.

**Core principle:** Detection is evidence, not a conclusion. A `fly.toml` says
Fly.io was configured once; only your human partner can say it is how
production deploys today.

**Announce at start:** "I'm using the configuring-deploys skill to record how this project deploys."

This skill is read-only toward every remote system. It never triggers a
deploy, a release, or a publish to test anything.

## Step 1: Look for an existing record

```bash
for f in CLAUDE.md AGENTS.md GEMINI.md; do
  [ -f "$f" ] && grep -n -A 25 '^## Deploy Configuration' "$f"
done
```

If one exists, show it and ask whether it is still right, needs one field
changed, or should be redone. "Still right" ends the skill.

Write to the instructions file the project already uses. If it has none,
ask which one to create.

## Step 2: Gather evidence

Read [references/platform-signals.md](references/platform-signals.md) for the
files and commands that indicate each kind of deploy. Then:

- List every signal present, with its file.
- **Read** each CI workflow or pipeline file that mentions deploy, release,
  publish, or an environment name. Note its trigger (push to which branch,
  tag, manual dispatch), its environments, and the command that deploys.
- Identify the forge from `git remote get-url origin` and whether its CLI
  (`gh`, `glab`, or another) is installed and authenticated.
- Note release bookkeeping the project already does: a version file or
  manifest version, a changelog, release tooling (changesets,
  release-please, semantic-release, towncrier, and the like).

Several signals at once are normal (a Dockerfile, a CI workflow, and a
platform file can describe one pipeline or three abandoned ones).

## Step 3: Ask what evidence cannot settle

One question per message, the most consequential first. Only ask what the
evidence leaves open:

- **What a release is here:** a running service, a published package, a
  shipped app, a static site, or nothing (a library consumed from source).
- **What triggers it:** merge to a branch, a tag, a manual command or
  button, a schedule.
- **Environments:** is there staging or a preview, and does production
  follow it automatically or by hand?
- **How success shows:** a pipeline run's conclusion, a status command, a
  health URL, a version endpoint, a dashboard only a person can read.
- **How to roll back:** revert and redeploy, a platform rollback command, a
  previous release to promote, or "ask me".
- **What you may do yourself:** merging, triggering a deploy, running a
  rollback. Default for all three: ask your human partner every time.

A project that does not deploy gets a record that says so; the other skills
then stop after merging.

## Step 4: Write the record

Show the filled section, get your human partner's yes, then write it with
an exact edit: replace the old section, or append a new one. Never rewrite
the rest of the file.

```markdown
## Deploy Configuration

- Release kind: <service / package / app / static site / none>
- Forge: <GitHub / GitLab / other> (CLI: <gh / glab / none>)
- Merge: <method the repo uses: merge / squash / rebase; merge queue yes/no>
- Trigger: <what starts a release, e.g. "push to main runs .github/workflows/deploy.yml">
- Environments: <staging → production, preview per PR, or production only>
- Deploy status: <command, or "pipeline run for the merge commit", or "none">
- Health checks: <URLs with expected status, version endpoint, or commands>
- Rollback: <exact method>
- Version and changelog: <files and tooling, or "none">
- Agent permissions: <merge / deploy / rollback: "ask each time" unless your human partner said otherwise>
- Notes: <anything a newcomer would trip on>
```

Commands go in exactly as they run. Secrets never go in: name the
environment variable a command needs, never its value.

## Step 5: Verify, read-only

Run what can be run without changing anything: the deploy status command,
each health check (`superpowers:verifying-a-deploy`'s `scripts/http-probe`
prints status and timing per URL), the forge CLI's auth status. Report each
result. A failure is noted in the record's Notes, not a reason to stop: the
URL may need a VPN, the CLI may not be installed here.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "There's a `vercel.json`, so it deploys on Vercel" | Config files outlive the setups they describe. Read the pipeline and ask. |
| "I'll trigger a deploy to check the config works" | A deploy is a production change. Verification here is read-only. |
| "They'll obviously want me to merge and deploy myself" | Permissions are theirs to grant. Default to asking each time. |
| "I'll paste the token into the record so the next run works" | Name the variable, never the value. |
| "No deploy files, so I'll invent a reasonable process" | Ask. "This project doesn't deploy" is a valid answer and a useful record. |
