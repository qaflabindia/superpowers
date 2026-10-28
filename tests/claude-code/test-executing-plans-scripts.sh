#!/usr/bin/env bash
# Tests for executing-plans' bookkeeping helpers: scripts/task-start extracts
# the brief and records BASE in one call; scripts/task-done runs the task's
# test command, records the result in the ledger, and refuses to record a
# failing task; scripts/suite-run (shared with SDD) records tree-keyed suite
# evidence only for a green run on a clean, unchanged tree; scripts/task-verify
# (SDD) re-runs an implementer's test command without marking the task complete.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EP_SCRIPTS="$REPO_ROOT/skills/executing-plans/scripts"
SDD_SCRIPTS="$REPO_ROOT/skills/subagent-driven-development/scripts"

FAILURES=0
TEST_ROOT=""

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

cleanup() {
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}

main() {
    echo "=== Test: executing-plans scripts ==="

    TEST_ROOT="$(mktemp -d)"
    trap cleanup EXIT

    git init -q -b main "$TEST_ROOT/repo"
    local repo
    repo="$(cd "$TEST_ROOT/repo" && git rev-parse --show-toplevel)"
    # Same spelling as the scripts print (pwd), not rev-parse's C:/... on Git Bash.
    repo="$(cd "$repo" && pwd)"
    local git_id=(-c user.email=t@example.com -c user.name=t -c commit.gpgsign=false)

    cat > "$repo/plan.md" <<'PLAN'
# Plan

## Task 1: First thing

Do the first thing.

## Task 2: Second thing

Do the second thing.
PLAN
    ( cd "$repo" && git add plan.md && git "${git_id[@]}" commit -qm fixture )
    local base
    base="$(cd "$repo" && git rev-parse HEAD)"

    # --- task-start: argument validation ---
    local rc=0
    (cd "$repo" && "$EP_SCRIPTS/task-start" plan.md >/dev/null 2>&1) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        pass "task-start without a task number errors with exit 2"
    else
        fail "task-start without a task number errors with exit 2 (got $rc)"
    fi

    # --- task-start: brief path + BASE in one call ---
    local out
    out="$(cd "$repo" && "$EP_SCRIPTS/task-start" plan.md 1)"
    if [[ "$out" == *"brief: $repo/.superpowers/sdd/plan/task-1-brief.md"* ]]; then
        pass "task-start prints the brief path under the plan's workspace"
    else
        fail "task-start prints the brief path under the plan's workspace"
        echo "    got: $out"
    fi
    if [[ "$out" == *"base: $base"* ]]; then
        pass "task-start prints BASE as the current HEAD"
    else
        fail "task-start prints BASE as the current HEAD"
        echo "    got: $out"
    fi
    if [[ -s "$repo/.superpowers/sdd/plan/task-1-brief.md" ]]; then
        pass "task-start writes the brief file"
    else
        fail "task-start writes the brief file"
    fi

    # --- task-done: records a passing task ---
    ( cd "$repo" && echo x > work.txt && git add work.txt && git "${git_id[@]}" commit -qm "task 1" )
    local head
    head="$(cd "$repo" && git rev-parse HEAD)"
    out="$(cd "$repo" && "$EP_SCRIPTS/task-done" plan.md 1 "$base" -- sh -c 'echo "Ran 3 tests"; echo OK')"
    rc=$?
    local ledger="$repo/.superpowers/sdd/plan/progress.md"
    local expected="Task 1: complete (commits ${base:0:7}..${head:0:7}, tests: sh -c 'echo \"Ran 3 tests\"; echo OK' → OK)"
    if [[ -f "$ledger" ]] && grep -qF "$expected" "$ledger"; then
        pass "task-done appends the completion line with commit range and test result"
    else
        fail "task-done appends the completion line with commit range and test result"
        echo "    expected: $expected"
        echo "    ledger:"; sed 's/^/      /' "$ledger" 2>/dev/null || echo "      (missing)"
    fi
    if [[ "$out" == *"OK"* ]]; then
        pass "task-done prints the tail of the test output"
    else
        fail "task-done prints the tail of the test output"
        echo "    got: $out"
    fi
    if [[ -s "$repo/.superpowers/sdd/plan/task-1-tests.log" ]]; then
        pass "task-done keeps the full test output in the workspace"
    else
        fail "task-done keeps the full test output in the workspace"
    fi

    # --- task-done: refuses to record a failing task ---
    rc=0
    out="$(cd "$repo" && "$EP_SCRIPTS/task-done" plan.md 2 "$head" -- sh -c 'echo "FAILED (errors=1)"; exit 1' 2>&1)" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        pass "task-done exits non-zero when the test command fails"
    else
        fail "task-done exits non-zero when the test command fails"
    fi
    if ! grep -q "Task 2: complete" "$ledger"; then
        pass "task-done does not record a failing task as complete"
    else
        fail "task-done does not record a failing task as complete"
    fi
    if [[ "$out" == *"FAILED"* ]]; then
        pass "task-done shows the failing output"
    else
        fail "task-done shows the failing output"
        echo "    got: $out"
    fi

    # --- task-done: records a passing task whose test command prints nothing ---
    # https://github.com/obra/superpowers/issues/2385 -- under `set -euo
    # pipefail`, the ledger's `grep -v '^[[:space:]]*$' log | tail -n 1`
    # exits 1 on an empty/blank log, which used to abort the whole script
    # (silently, no ledger line) even though the test command itself passed.
    ( cd "$repo" && echo y > work2.txt && git add work2.txt && git "${git_id[@]}" commit -qm "task 2" )
    local head2
    head2="$(cd "$repo" && git rev-parse HEAD)"
    rc=0
    out="$(cd "$repo" && "$EP_SCRIPTS/task-done" plan.md 2 "$head" -- true 2>&1)" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        pass "task-done exits 0 when a passing test command prints nothing"
    else
        fail "task-done exits 0 when a passing test command prints nothing (got rc=$rc)"
        echo "    got: $out"
    fi
    local expected2="Task 2: complete (commits ${head:0:7}..${head2:0:7}, tests: true → (no output))"
    if [[ -f "$ledger" ]] && grep -qF "$expected2" "$ledger"; then
        pass "task-done records a passing task that printed no output"
    else
        fail "task-done records a passing task that printed no output"
        echo "    expected: $expected2"
        echo "    ledger:"; sed 's/^/      /' "$ledger" 2>/dev/null || echo "      (missing)"
    fi

    # --- suite-run: records tree-keyed evidence for a green run on a clean tree ---
    local tree
    tree="$(cd "$repo" && git rev-parse 'HEAD^{tree}')"
    rc=0
    out="$(cd "$repo" && "$SDD_SCRIPTS/suite-run" plan.md -- sh -c 'echo "12 passed"' 2>&1)" || rc=$?
    local expected3="Suite: green on tree $tree (HEAD ${head2:0:7}, [0-9]+s) — sh -c 'echo \"12 passed\"' → 12 passed"
    if [[ "$rc" -eq 0 ]] && grep -q "^Suite: green on tree $tree (HEAD ${head2:0:7}, [0-9]*s) — sh -c 'echo \"12 passed\"' → 12 passed\$" "$ledger"; then
        pass "suite-run records the tree a green suite ran on"
    else
        fail "suite-run records the tree a green suite ran on (rc=$rc)"
        echo "    expected: $expected3"
        echo "    ledger:"; sed 's/^/      /' "$ledger" 2>/dev/null || echo "      (missing)"
    fi
    if [[ -s "$repo/.superpowers/sdd/plan/suite-${tree:0:7}.log" ]]; then
        pass "suite-run keeps the full suite output in the workspace"
    else
        fail "suite-run keeps the full suite output in the workspace"
    fi

    # --- suite-run: a red suite records nothing and returns its status ---
    local before
    before="$(grep -c '^Suite:' "$ledger")"
    rc=0
    out="$(cd "$repo" && "$SDD_SCRIPTS/suite-run" plan.md -- sh -c 'echo "1 failed"; exit 3' 2>&1)" || rc=$?
    if [[ "$rc" -eq 3 ]] && [[ "$(grep -c '^Suite:' "$ledger")" -eq "$before" ]]; then
        pass "suite-run returns the failing status and records nothing"
    else
        fail "suite-run returns the failing status and records nothing (rc=$rc)"
    fi

    # --- suite-run: uncommitted changes mean no tree evidence ---
    ( cd "$repo" && echo dirty >> work.txt )
    rc=0
    out="$(cd "$repo" && "$SDD_SCRIPTS/suite-run" plan.md -- true 2>&1)" || rc=$?
    if [[ "$rc" -eq 0 ]] && [[ "$(grep -c '^Suite:' "$ledger")" -eq "$before" ]] \
        && [[ "$out" == *"uncommitted changes"* ]]; then
        pass "suite-run records no evidence for a dirty working tree"
    else
        fail "suite-run records no evidence for a dirty working tree (rc=$rc)"
        echo "    got: $out"
    fi
    ( cd "$repo" && git checkout -q -- work.txt )

    # --- suite-run: a suite that changes tracked files proves nothing ---
    rc=0
    out="$(cd "$repo" && "$SDD_SCRIPTS/suite-run" plan.md -- sh -c 'echo mutated >> work.txt' 2>&1)" || rc=$?
    if [[ "$rc" -eq 0 ]] && [[ "$(grep -c '^Suite:' "$ledger")" -eq "$before" ]]; then
        pass "suite-run records no evidence when the run dirtied the tree"
    else
        fail "suite-run records no evidence when the run dirtied the tree (rc=$rc)"
        echo "    got: $out"
    fi
    ( cd "$repo" && git checkout -q -- work.txt )

    # --- task-verify (SDD): records verification, never completion ---
    rc=0
    out="$(cd "$repo" && "$SDD_SCRIPTS/task-verify" plan.md 3 -- sh -c 'echo "5 passed"' 2>&1)" || rc=$?
    local expected4="Task 3: tests verified at ${head2:0:7} — sh -c 'echo \"5 passed\"' → 5 passed"
    if [[ "$rc" -eq 0 ]] && grep -qF "$expected4" "$ledger"; then
        pass "task-verify records the controller's own test run"
    else
        fail "task-verify records the controller's own test run (rc=$rc)"
        echo "    expected: $expected4"
        echo "    ledger:"; sed 's/^/      /' "$ledger" 2>/dev/null || echo "      (missing)"
    fi
    if ! grep -q "^Task 3: complete" "$ledger"; then
        pass "task-verify never writes a completion line"
    else
        fail "task-verify never writes a completion line"
    fi
    if [[ -s "$repo/.superpowers/sdd/plan/task-3-verify-${head2:0:7}.log" ]]; then
        pass "task-verify keeps the full output in the workspace"
    else
        fail "task-verify keeps the full output in the workspace"
    fi

    rc=0
    out="$(cd "$repo" && "$SDD_SCRIPTS/task-verify" plan.md 4 -- sh -c 'echo "2 failed"; exit 1' 2>&1)" || rc=$?
    if [[ "$rc" -eq 1 ]] && ! grep -q "^Task 4:" "$ledger" && [[ "$out" == *"2 failed"* ]]; then
        pass "task-verify returns the failing status, shows it, and records nothing"
    else
        fail "task-verify returns the failing status, shows it, and records nothing (rc=$rc)"
        echo "    got: $out"
    fi

    rc=0
    (cd "$repo" && "$SDD_SCRIPTS/task-verify" plan.md 3 >/dev/null 2>&1) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        pass "task-verify without a command errors with exit 2"
    else
        fail "task-verify without a command errors with exit 2 (got $rc)"
    fi

    # --- task-verify -C: runs in a wave worktree, ledgers in the plan checkout ---
    local wt="$TEST_ROOT/wave-task-5"
    ( cd "$repo" && git worktree add -q -b sdd/plan/task-5 "$wt" HEAD \
        && cd "$wt" && echo z > wave.txt && git add wave.txt \
        && git "${git_id[@]}" commit -qm "task 5" )
    local wt_head
    wt_head="$(git -C "$wt" rev-parse HEAD)"
    rc=0
    out="$(cd "$repo" && "$SDD_SCRIPTS/task-verify" -C "$wt" plan.md 5 -- sh -c 'test -f wave.txt && echo "1 passed"' 2>&1)" || rc=$?
    local expected5="Task 5: tests verified at ${wt_head:0:7} — sh -c 'test -f wave.txt && echo \"1 passed\"' → 1 passed"
    if [[ "$rc" -eq 0 ]] && grep -qF "$expected5" "$ledger" && [[ ! -e "$wt/.superpowers" ]]; then
        pass "task-verify -C runs in the worktree and ledgers in the plan checkout"
    else
        fail "task-verify -C runs in the worktree and ledgers in the plan checkout (rc=$rc)"
        echo "    got: $out"
        echo "    ledger:"; sed 's/^/      /' "$ledger" 2>/dev/null || echo "      (missing)"
    fi
    ( cd "$repo" && git worktree remove --force "$wt" )

    # --- suite-run --lookup: shared store outlives the ledger, keyed by tree ---
    local store
    store="$(cd "$repo" && cd "$(git rev-parse --git-common-dir)" && pwd)/superpowers/suite-evidence.tsv"
    if [[ -f "$store" ]] && grep -q "^$tree"$'\t' "$store"; then
        pass "suite-run writes green evidence to the shared store"
    else
        fail "suite-run writes green evidence to the shared store"
    fi
    rc=0
    out="$(cd "$repo" && git checkout -q "$head2" 2>/dev/null && "$SDD_SCRIPTS/suite-run" --lookup -- sh -c 'echo "12 passed"' 2>&1)" || rc=$?
    if [[ "$rc" -eq 0 && "$out" == "Suite: green on tree $tree"* ]]; then
        pass "suite-run --lookup finds evidence for the current tree and command"
    else
        fail "suite-run --lookup finds evidence for the current tree and command (rc=$rc)"
        echo "    got: $out"
    fi
    rc=0
    ( cd "$repo" && "$SDD_SCRIPTS/suite-run" --lookup -- other-command >/dev/null 2>&1 ) || rc=$?
    if [[ "$rc" -eq 1 ]]; then
        pass "suite-run --lookup misses for a different command"
    else
        fail "suite-run --lookup misses for a different command (rc=$rc)"
    fi
    ( cd "$repo" && echo dirty >> work.txt )
    rc=0
    ( cd "$repo" && "$SDD_SCRIPTS/suite-run" --lookup >/dev/null 2>&1 ) || rc=$?
    if [[ "$rc" -eq 1 ]]; then
        pass "suite-run --lookup refuses a dirty working tree"
    else
        fail "suite-run --lookup refuses a dirty working tree (rc=$rc)"
    fi
    ( cd "$repo" && git checkout -q -- work.txt )
    local before_store
    before_store="$(grep -c '' "$store")"
    rc=0
    out="$(cd "$repo" && "$SDD_SCRIPTS/suite-run" - -- sh -c 'echo "3 passed"' 2>&1)" || rc=$?
    if [[ "$rc" -eq 0 && "$(grep -c '' "$store")" -eq $((before_store + 1)) && "$out" == *"evidence: Suite: green"* ]]; then
        pass "suite-run - records to the shared store without a plan"
    else
        fail "suite-run - records to the shared store without a plan (rc=$rc)"
        echo "    got: $out"
    fi

    # --- task-verify: reuses suite-run evidence for the same tree + command ---
    rc=0
    out="$(cd "$repo" && "$SDD_SCRIPTS/task-verify" plan.md 9 -- sh -c 'echo "3 passed"' 2>&1)" || rc=$?
    if [[ "$rc" -eq 0 ]] && grep -q "^Task 9: tests verified at .* → reused: green on tree $tree" "$ledger" \
        && [[ ! -e "$repo/.superpowers/sdd/plan/task-9-verify-${head2:0:7}.log" ]]; then
        pass "task-verify cites a recorded green run instead of re-running"
    else
        fail "task-verify cites a recorded green run instead of re-running (rc=$rc)"
        echo "    got: $out"
    fi

    # --- run-summary: summarises and archives the ledger past the workspace ---
    printf '%s\n' \
        "Task 7: complete (commits aaaaaaa..bbbbbbb, review clean; models: impl haiku, review sonnet, rounds 0)" \
        "Task 8: complete (commits bbbbbbb..ccccccc, 1 parked; models: impl haiku→sonnet, review sonnet, rounds 5)" \
        "Ruling: plan said X, spec says Y — followed spec" \
        "Task 8: minor (deferred) — naming" >> "$ledger"
    rc=0
    out="$(cd "$repo" && "$SDD_SCRIPTS/run-summary" plan.md 2>&1)" || rc=$?
    local archive
    archive="$(printf '%s\n' "$out" | sed -n 's/^Archived: //p')"
    if [[ "$rc" -eq 0 ]] \
        && [[ "$out" == *"Fix rounds: 5 total (most: 5 on Task 8)"* ]] \
        && [[ "$out" == *"1 with parked findings"* ]] \
        && [[ "$out" == *"impl haiku ×1"* && "$out" == *"review sonnet ×2"* ]] \
        && [[ "$out" == *"Rulings: 1; deferred minors: 1"* ]] \
        && [[ "$out" == *"Task verifications: "*" re-ran tests, 1 reused a recorded green run"* ]] \
        && [[ -f "$archive" ]] && grep -qF "Task 8: minor (deferred)" "$archive"; then
        pass "run-summary reports models, rounds, rulings and archives the ledger"
    else
        fail "run-summary reports models, rounds, rulings and archives the ledger (rc=$rc)"
        echo "    got: $out"
    fi

    echo
    if [[ "$FAILURES" -eq 0 ]]; then
        echo "PASS"
    else
        echo "FAIL ($FAILURES)"
        exit 1
    fi
}

main "$@"
