# Superpowers v7.0.1: Agentic SDLC Evaluation

**Scope:** every `skills/*/SKILL.md`, the SDD and executing-plans references, scripts and prompt templates, `hooks/session-start`, and `tests/skill-size`.
**Method:** I mapped each lifecycle phase to the skill that owns it, then checked the hand-offs between skills for contradictions, duplicated work, missing phases, and how close each file is to its size limit.
**Not done:** I ran no behaviour evals. `evals/` (superpowers-evals) is not cloned in this worktree. Every recommendation that changes skill wording needs an eval before anyone relies on it (see AGENTS.md, "Skill Changes Require Evaluation").

---

## 1. Lifecycle map

| SDLC phase | Owning skill | Gate / artifact | State that survives compaction |
|---|---|---|---|
| Intake and routing | using-superpowers (injected at SessionStart, 3.2 KB) | "invoke before any response" | Re-injected each session |
| Requirements and design | brainstorming | HARD-GATE: approved design doc, plus a builder-check subagent | `docs/superpowers/specs/*.md` |
| Planning | writing-plans | Header, Global Constraints, Review Focus, per-task Interfaces | `docs/superpowers/plans/*.md` |
| Environment isolation | using-git-worktrees | Consent, native tool first, baseline test run | Worktree on disk |
| Implementation | subagent-driven-development **or** executing-plans | Per-task brief; ledger; rulings | `.superpowers/sdd/<plan>/progress.md` |
| Unit-level quality | test-driven-development | Iron Law: failing test first | Commits |
| Defect handling | systematic-debugging | Root cause before fix; architecture discussion after 3 failed fixes | none |
| Per-task review | SDD task-reviewer-prompt (SDD only) | Spec ✅ and quality verdicts; 5-round fix loop with a breaker | Ledger lines |
| Whole-branch review | requesting-code-review's `code-reviewer.md` | One review on the most capable model, then one fix wave | Ledger "Final:" lines |
| Completion claims | verification-before-completion | Fresh evidence before any claim | none |
| Integration | finishing-a-development-branch | Green suite → 3-option menu → cleanup | Branch / PR |
| PR feedback | receiving-code-review | Verify before implementing | none |
| Release, deploy, operate | **none** | none | none |
| Retro and learning | diagnosing-superpowers (reactive) | Findings cite `path:line` | `~/.superpowers/diagnosing-superpowers/` |

**What is already strong:**

- The spec→plan→brief chain keeps one source of truth at each level.
- The ledger makes runs recoverable after compaction.
- "Rulings, not stalls" keeps long runs moving, and the "Rulings I made" list still reports every ruling to your human partner.
- Diffs reach reviewers as files, so they stay out of the controller's context.
- Model tiers are set per role.
- The final-review fix wave is capped.

Agentic SDLC tooling rarely gets these right, and nothing below argues for removing any of them.

---

## 2. Findings, ranked

### Tier 1: consistency defects (mechanical, low behavioural risk)

**F1. requesting-code-review is out of date with the two executors that call it.**
- `requesting-code-review/SKILL.md:28` sets `BASE_SHA=$(git rev-parse HEAD~1)`. SDD forbids exactly this in two places (`SKILL.md:241`, `:266`): it "silently drops all but the last commit of a multi-commit task."
- `code-reviewer.md` tells the reviewer to run `git diff` itself, and its template has no slot for a review-package path. `references/final-review.md` and `executing-plans` both hand the reviewer a package file, so the reviewer gets two conflicting instructions.
- It says "Dispatch a `general-purpose` subagent" and never mentions a model. SDD says: "Always specify the model explicitly… an omitted model inherits your session's model."
- It lists "Mandatory: after each task in subagent-driven development", but SDD uses its own `task-reviewer-prompt.md` for per-task review.

*Fix:*
- Default `BASE_SHA` to the recorded task base or `git merge-base`.
- Add a `[REVIEW_PACKAGE]` placeholder and make it take precedence over running `git diff`.
- Add a single line on choosing the model explicitly.
- Remove the stale SDD bullet.

**F2. Text shared by SDD and executing-plans is duplicated, and the copies have already drifted.**
Both files contain near-verbatim Setup / ledger / Finish sections. The pre-flight scan now differs between them:
- `SDD/references/preflight.md` requires "One row for every task: whether its own text agrees with itself".
- `executing-plans` says "Each task's own text is checked when you read its brief, not here."

Because both executors share one ledger (so a plan can switch executors partway through), this drift means a resumed run follows different pre-flight rules depending on which executor picks it up.

*Fix:* move workspace/ledger setup, pre-flight and Finish into shared reference files (e.g. `subagent-driven-development/references/workspace.md`) that both skills link to. Pick one pre-flight rule on purpose; don't let it be decided by whichever copy changed last.

**F3. SDD has 494 bytes left before the compaction cut.**
`subagent-driven-development/SKILL.md` is 19,506 bytes, and `tests/skill-size` fails at 20,000. `executing-plans` is at 18,103. Any future fix to SDD will fail CI or push content past the point where Claude Code truncates skills after compaction (#2481). The F2 extraction is the obvious way to free space. Do it before any other SDD change.

**F4. using-git-worktrees runs the wrong installer for common setups.**
In Step 2:
- `package.json` always triggers `npm install`, even in pnpm, yarn or bun repos. In those repos this creates a stray `package-lock.json` or changes resolution.
- `pyproject.toml` always triggers `poetry install`, which fails or does the wrong thing for uv, hatch, pdm and plain-pip projects.

This runs in a brand-new worktree on every plan, so a wrong installer leaves an unrelated lockfile change in the diff before Task 1 starts.

*Fix:* pick the installer from the lockfile (`pnpm-lock.yaml`, `yarn.lock`, `bun.lockb`, `uv.lock`, `poetry.lock`) and fall back to "ask" rather than guess.

### Tier 2: throughput and cost

**F5. The full suite runs about N+4 times per plan.**
For an N-task plan, the full suite runs at:
1. The worktree baseline.
2. Every task. TDD's "Verify GREEN" requires the project suite, and the implementer prompt says "run full suite once before committing".
3. `task-done` per task (inline executor).
4. The suite after the final fix pass.
5. finishing Step 1.
6. After the merge (Option 1).

Steps 4 and 5 often run on the *same tree*. finishing's rationalization table is right that "a green run only proves the tree it ran on". The answer is to record which tree each run proved, not to re-run blindly.

*Fix:*
- Record `git rev-parse HEAD^{tree}` together with each green suite result in the ledger.
- finishing Step 1 may cite an existing ledger line if `HEAD^{tree}` matches and `git status --porcelain` is empty. Otherwise it runs the suite.
- The post-merge run always happens, because the merge produces a different tree.

This keeps what the rule is for and removes one full-suite run per plan. For slow suites that run is the largest wall-clock cost of finishing.

**F6. In SDD, nobody independently checks the implementer's test results.**
- The implementer's report "is the test evidence" (`implementer-prompt.md:124`).
- The reviewer is told not to re-run tests (`task-reviewer-prompt.md:75-82`, `SKILL.md:280`).
- verification-before-completion lists "Agent said success → Verify independently" and "Agent completed → VCS diff shows changes".

SDD is the one executor where an implementer's claim of passing tests is never checked by anyone else until finishing Step 1. executing-plans already has `scripts/task-done`, which runs the tests, keeps the output on disk, prints 5 lines and writes the ledger line.

*Fix:* after an implementer reports DONE, the SDD controller runs `task-done` with the test command named in the brief, before it builds the review package. This costs one test run per task (scoped to the brief's command, not the full suite), adds about 5 lines to the controller's context, and gives both executors the same ledger format.
*Risk:* moderate. This changes SDD's cost profile, so measure it with `tests/claude-code/test-subagent-driven-development-integration.sh` and its token analysis.

**F7. Tasks always run one at a time, even when the plan shows they are independent.** (Biggest potential gain, highest risk.)
SDD says "Never dispatch multiple implementation subagents in parallel". Yet writing-plans already makes every task declare `Consumes:` / `Produces:` and its exact files, so the dependency graph can be worked out from the plan. Tasks with no shared files and no producer→consumer edge are currently queued behind each other for no reason.

*Proposal:*
- writing-plans adds an optional `Depends on: Task N` line.
- SDD may dispatch a *wave* of tasks with no edges between them and no shared files, each in its own worktree.
- Each task still gets its own task review.
- Waves merge into the plan branch in task order, then the full suite runs.
- Make it opt-in at the writing-plans execution handoff ("Subagent-driven, parallel waves").

*Risks:* merge conflicts that the file lists don't predict (lockfiles, generated files, shared fixtures), a more complex ledger, and harder recovery after compaction. Do not attempt this without a quorum scenario comparing serial and wave runs on wall-clock time, tokens and final-review findings.

### Tier 3: gaps in the lifecycle

**F8. Nothing hands PR feedback back into the workflow.**
finishing Option 2 keeps the worktree because "your human partner iterates on PR feedback there". But nothing points at receiving-code-review, which only fires if its description matches. Of the core skills, only executing-plans references requesting-code-review, and **no** skill references receiving-code-review.

*Fix:* one line in Option 2: "When review comments arrive, use superpowers:receiving-code-review."

**F9. Security gets one line in the whole review pipeline.**
- `code-reviewer.md` has a single bullet, "Security concerns?".
- writing-plans' Review Focus covers input classes and failure modes but never names trust boundaries.

Without breaking the core's "general-purpose" rule, writing-plans could ask Review Focus to name any trust boundary the spec touches (untrusted input, authn/authz, secrets, file/exec paths). The final reviewer then checks those deliberately instead of relying on one generic bullet. This needs an eval, because Review Focus is tuned content.

**F10. Release, deploy and operate are deliberately missing, and should stay that way in core.**
CI waiting, deploy, canary and rollback all depend on specific tools. AGENTS.md is explicit that this belongs in a separate plugin. The clean extension point is the end of finishing-a-development-branch: a plugin skill that triggers on "PR created / merged". Core needs no change for that to work.

**F11. The learning loop only starts when someone asks.**
diagnosing-superpowers runs only after a complaint. The ledger already records rulings and deferred minors but nothing about cost. If each dispatch ledger line also recorded `model` and, where the harness reports it, turns or tokens, diagnosing-superpowers' `cost-and-time` dimension could read the ledger instead of reconstructing costs from transcripts. Low priority.

### Tier 4: triggering

**F12. The descriptions of SDD and executing-plans are lopsided.**
- executing-plans says when it applies ("your human partner chose inline execution, or no subagent tool is available").
- SDD's description ("executing implementation plans with independent tasks in the current session") also matches the inline case.

The writing-plans handoff makes the real choice. Making SDD's description match ("…when your human partner chose subagent-driven execution") would cut down on the wrong executor firing after compaction or in a new session. Description changes affect triggering, so run `tests/explicit-skill-requests/` (especially `after-planning-flow`, `mid-conversation-execute-plan`) before and after.

---

## 3. What I would not touch

- The Red Flags and Common Rationalizations tables, the Iron Laws, the "your human partner" wording, and the brainstorming conversation design. AGENTS.md treats these as tuned behaviour code, and nothing in this review shows them failing.
- The 1%-chance rule in using-superpowers. It looks aggressive, but brainstorming's "everything that matters is in the request → do it" path already absorbs most of the cost of over-triggering.
- writing-skills' 5.8k-word `anthropic-best-practices.md`. It is loaded only on demand, so it costs nothing in normal sessions.

---

## 4. Recommended order and how to verify each step

| Step | Findings | Verify with | Behavioural risk |
|---|---|---|---|
| 1 | F3 + F2 (extract shared references, settle the pre-flight rule) | `tests/skill-size`, `tests/claude-code/test-sdd-workspace.sh`, `test-executing-plans-scripts.sh` | Low |
| 2 | F1, F4, F8 | Reading the diffs; worktree tests (`test-worktree-*`) | Low |
| 3 | F5 (tree-keyed evidence) | SDD integration test plus a finishing quorum scenario | Medium |
| 4 | F6 (controller `task-done`) | SDD integration test token analysis, before and after | Medium |
| 5 | F12, F9 | `tests/explicit-skill-requests/`; Review Focus eval | Medium |
| 6 | F7 (parallel waves) | New quorum scenario: serial vs waves | High |
| n/a | F10, F11 | Separate plugin / later | n/a |

**Implementation status (this branch):**
- Steps 1–2 (F1–F4, F8) are done.
- Step 3 (F5) is done:
  - `subagent-driven-development/scripts/suite-run` records `Suite: green on tree <T>`, but only for a green run on a tree that is clean and unchanged after the run.
  - `references/finish.md` makes the executor's own full-suite run the final check, then carries that line forward.
  - finishing Step 1 cites the line instead of re-running when `HEAD^{tree}` matches and the worktree is clean.
  - This also covers the final-tree part of F6: the controller now runs the suite itself before finishing.
  - Follow-up, the remaining repeats: `suite-run` also writes every green run to a shared store in the git common dir (`.git/superpowers/suite-evidence.tsv`, keyed by tree and command, with seconds), which outlives the plan workspace and every worktree sees. `suite-run --lookup` answers "is this exact tree already proved?" for:
    - the new-worktree baseline (using-git-worktrees Step 3), when the base tree was already proved;
    - `task-verify`, which cites an implementer's own `suite-run` on its final commit instead of re-running — one full run per task, not two;
    - finishing Step 1 and landing's readiness report, when the session holds no `Suite:` line.
  - `references/suite-budget.md` sets the implementer's `[SUITE_POLICY]` at pre-flight from the baseline's measured seconds: up to 120s, implementers run the full suite once through `suite-run`; above it, they run the tests for the modules they changed and the controller runs the full suite every K tasks (default 3), bisecting by task on a red run.
- Step 4 (F6, per task) is done:
  - Implementers now report the exact test command they ran.
  - On DONE, and after each fix round, the controller re-runs that command with the new `scripts/task-verify`. A red result is a Critical finding.
- Step 5 (F12, F9) is done:
  - SDD's description now names only its trigger (your human partner chose subagent-driven execution and a subagent tool is available), following `writing-skills/references/discovery.md`.
  - Review Focus must name any trust boundary the software crosses.
- Step 6 (F7) is done, opt-in only:
  - writing-plans tasks carry `Depends on:`.
  - `references/parallel-waves.md` covers building waves at pre-flight, one worktree per task, a review per task, landing in task order, and re-queuing a task on a merge conflict.
  - `task-verify -C` keeps the ledger in the plan's own checkout.
  - Serial execution stays the default.
  - Exercised end to end by `tests/claude-code/test-sdd-parallel-wave.sh` with the real scripts: three worktrees from one WAVE_BASE, `task-verify -C` (reusing recorded runs), review packages, `--no-ff` landing in task order, a conflicting task aborted and re-queued, the suite on the landed wave, worktree cleanup, the serial re-run, and the run summary. Implementers in that test are stand-in edits; real subagent waves still need a behaviour eval.
- F11 is done: SDD completion lines record `models:` and fix rounds; before the workspace is deleted, `scripts/run-summary` prints the run's cost lines (tasks, models per seat, fix rounds, suite runs and seconds, verifications re-run vs reused, ruling counts) for the final message and archives them with the whole ledger under `.git/superpowers/runs/`. Diagnosing's cost-and-time prompt reads that archive.
- F10 is addressed in this fork only, by four generic skills adapted from the gstack release skills (`setup-deploy`, `ship` + `document-release`, `land-and-deploy`, `canary`): configuring-deploys, preparing-a-release, landing-and-deploying (with `scripts/poll-until` and a forge command table for GitHub, GitLab, Azure DevOps and Gitea) and verifying-a-deploy (with `scripts/http-probe`, which compares against a baseline log, and `scripts/probe-watch` for watch mode with two-round persistence). They hook in at finishing-a-development-branch Option 2. Upstream AGENTS.md puts deploy work outside core, so these are not for an upstream PR; ship them as a separate plugin if they are ever shared.
- gstack skills assessed and not adapted: `health` (overlaps verification-before-completion), `cso` (a full security audit; F9's trust-boundary review covers the SDLC part), `retro` (team analytics, not a gate), `benchmark` (needs gstack's browse daemon; its relative-threshold rule is in verifying-a-deploy), `careful` / `guard` (PreToolUse hooks; the SDD stop rules cover the agent side).
- SDD `SKILL.md` is 19,183 bytes. Its content is only moved out when a change needs the room, never just to cut size.
- Pre-existing test issues fixed on the way: the Codex packaging scripts rejected linked worktrees (`.git` is a file there), and the zip's normalised timestamps shifted by the local UTC offset because `zip` ran outside `TZ=UTC`.
- Every script added or changed passes shellcheck. `scripts/lint-shell.sh --all` still reports 11 findings in three upstream test files this branch does not touch.
- No behaviour evals have been run. Script tests cover every helper; the agent-behaviour side needs the superpowers-evals lab (`evals/`, not cloned here), which drives real agent CLIs at API cost.

**For sending changes upstream:** AGENTS.md requires one problem per PR, a problem your human partner actually hit, a search for duplicate PRs, and eval evidence for skill-content changes. F1 and F4 are the most defensible as standalone bug fixes, and only if you have hit them in a real session. F5–F7 are design changes and should start as an issue or discussion, not a PR.
