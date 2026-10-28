---
name: preparing-a-release
description: Use when a finished branch is about to be pushed for review or merge in a project that keeps a version number, a changelog, or user-facing docs - or your human partner asks you to prepare a release
---

# Preparing a Release

## Overview

Before a branch goes up for review, make the parts of it that other people
read match the code: the version, the changelog, the docs, and the PR
description. Reviewers judge the branch by these; users meet the release
through them.

**Core principle:** Follow the project's own release conventions. Never
introduce a version scheme, changelog format, or doc structure the project
doesn't already use.

**Announce at start:** "I'm using the preparing-a-release skill to bring the version, changelog, and docs in line with this branch."

Runs after the implementation is complete and its suite is green, before
superpowers:finishing-a-development-branch pushes the branch. Never on the
base branch.

## Step 1: Learn the conventions

Read the project's `## Deploy Configuration` record if it has one
(superpowers:configuring-deploys writes it). Otherwise look for the release
bookkeeping in that skill's
[platform-signals.md](../configuring-deploys/references/platform-signals.md)
"Release bookkeeping" table, and read the last two or three changelog
entries and release commits to see how this project actually does it.

**A tool owns it, you don't hand-edit it.** With changesets, add a changeset
file. With release-please or semantic-release, the version comes from
commit messages: make sure yours follow the convention, and change no
version file. With towncrier, add a news fragment.

Nothing to keep (no version, no changelog, no user docs)? Say so in one
line and skip to Step 5.

## Step 2: Bring the branch up to date

Merge (or rebase, if that is the project's convention and the branch has
not been pushed) the current base branch into the branch, so the release
bookkeeping is written against what it will land on. Conflicts beyond
release-file ordering (two changelog entries, two version bumps): stop and
show them. Then run the full suite on the result. A red suite stops here.

## Step 3: Version

Decide the bump from the diff against the base, using the project's scheme
(semver unless it shows otherwise):

- **Breaking change** to a public interface → major.
- **New capability** (a command, flag, endpoint, option) → minor.
- **Fix or internal change** → patch.

State the level with its one-line reason. A patch you may write. **Ask your
human partner before writing a minor or major bump** — a version number is
a public promise. Pre-1.0 projects often bump minor for breaking changes;
follow what their history does.

Write every file the scheme keeps in sync (`VERSION`, manifests, lockfile
entries for the package itself, constants), and nothing else. If the
branch already carries a bump, check it still covers the whole diff and
still sits above the base's version.

## Step 4: Changelog and docs

**Changelog:** add one entry in the existing format, at the top, written
for the people who use the software: what they can now do, what changed
for them, what to do about breaking changes. Build it from the diff and the
commits, not from the commit subjects alone. Edit the file; never
regenerate, reorder, or rewrite existing entries.

**Docs coverage:** list the public surface the diff adds, changes, or
removes — commands, flags, config keys, environment variables, endpoints,
exported APIs. For each, find where the docs mention it.

| Finding | Action |
|---------|--------|
| Factual drift (a renamed flag, a changed default, a stale path or count) | Fix it directly |
| New surface with no mention anywhere | Add the reference entry (a table row, a list item, an options line) |
| Missing tutorial or explanation | Flag it in the PR description; don't write new guides unasked |
| Narrative, philosophy, security guidance, or removing a section | Ask first |
| Diagrams that name changed components | Flag them; don't redraw |

Read each doc file in full before editing it.

## Step 5: Commit and describe

Commit the release bookkeeping on its own (`chore: release vX.Y.Z`, or the
project's convention), after the work's commits. Never squash, reorder,
or rewrite commits that are already pushed.

Draft the PR description from the actual commits: what changed and why, the
version, the changelog entry, test evidence (the suite command and result
from Step 2), and the doc gaps you flagged. Hand it to
superpowers:finishing-a-development-branch, which pushes and opens the PR
following the repo's PR template.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The project has no changelog; I'll start one" | Introducing a convention is your human partner's call. Ask, or skip. |
| "It's a new feature but small, patch is fine" | The level follows what changed for users, not the line count. |
| "I'll bump the version file even though release-please manages it" | The tool will fight you and CI may reject it. Follow the tool. |
| "Let me tidy the old changelog entries while I'm here" | Existing entries are history. Add yours; touch nothing else. |
| "The docs need a whole new guide for this" | Flag the gap. Writing unrequested guides inflates the review. |
| "Tests passed before the base merge" | The merge changed the tree. Run them on what you'll push. |
