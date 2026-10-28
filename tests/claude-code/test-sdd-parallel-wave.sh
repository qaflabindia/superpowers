#!/usr/bin/env bash
# End-to-end run of references/parallel-waves.md with the real SDD scripts:
# three tasks cut from one WAVE_BASE into their own worktrees, verified with
# task-verify -C (reusing an implementer's suite-run where one exists),
# packaged for review, landed in task order with --no-ff, a conflicting task
# aborted and re-queued, the suite run on the landed result, the worktrees
# removed, the re-queued task landed serially, and the run summarised.
# Implementers are stand-in shell edits; the mechanics are what is tested.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SK="$REPO_ROOT/skills/subagent-driven-development/scripts"

FAILURES=0
TEST_ROOT=""

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}
check() {
    local name=$1
    shift
    if "$@"; then pass "$name"; else fail "$name"; fi
}

cleanup() {
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}

main() {
    echo "=== Test: SDD parallel wave ==="
    TEST_ROOT="$(mktemp -d)"
    trap cleanup EXIT
    local g=(-c user.name=t -c user.email=t@t -c commit.gpgsign=false)

    git init -q -b main "$TEST_ROOT/repo"
    local repo
    repo="$(cd "$TEST_ROOT/repo" && pwd)"
    cd "$repo"
    mkdir -p docs/plans src
    cat > docs/plans/plan.md <<'P'
# Plan

### Task 1: Add greet
Files: src/greet.sh

### Task 2: Add farewell
Files: src/bye.sh

### Task 3: Shout greet
Files: src/greet.sh
P
    echo 'echo base' > src/base.sh
    cat > test.sh <<'T'
#!/bin/sh
n=0; for f in src/*.sh; do sh "$f" >/dev/null && n=$((n+1)); done; echo "$n passed"
T
    printf '.superpowers/\n' > .gitignore
    git add -A && git "${g[@]}" commit -qm init

    local plan=docs/plans/plan.md ledger=.superpowers/sdd/plan/progress.md
    local wb n
    wb="$(git rev-parse HEAD)"
    bash "$SK/sdd-workspace" "$plan" >/dev/null
    for n in 1 2 3; do
        bash "$SK/task-brief" "$plan" "$n" >/dev/null
        git worktree add -q -b "sdd/plan/task-$n" "$TEST_ROOT/wt$n" "$wb"
    done

    # Stand-in implementers. Tasks 1 and 2 record their suite run; 3 does not.
    (cd "$TEST_ROOT/wt1" && echo 'echo hello' > src/greet.sh && git add -A \
        && git "${g[@]}" commit -qm "task 1" && bash "$SK/suite-run" - -- sh test.sh >/dev/null 2>&1)
    (cd "$TEST_ROOT/wt2" && echo 'echo bye' > src/bye.sh && git add -A \
        && git "${g[@]}" commit -qm "task 2" && bash "$SK/suite-run" - -- sh test.sh >/dev/null 2>&1)
    (cd "$TEST_ROOT/wt3" && echo 'echo HELLO' > src/greet.sh && git add -A \
        && git "${g[@]}" commit -qm "task 3")

    local pkg
    for n in 1 2 3; do
        bash "$SK/task-verify" -C "$TEST_ROOT/wt$n" "$plan" "$n" -- sh test.sh >/dev/null 2>&1
        pkg="$(bash "$SK/review-package" "$plan" "$wb" "sdd/plan/task-$n" 2>&1)"
        check "task $n review package names one commit" grep -q "1 commit(s)" <<<"$pkg"
    done
    check "verify reuses an implementer's recorded run (task 1)" \
        grep -q "^Task 1: tests verified at .* → reused: green on tree" "$ledger"
    check "verify re-runs when nothing was recorded (task 3)" \
        grep -q "^Task 3: tests verified at .* → 2 passed$" "$ledger"
    check "no ledger is written inside a wave worktree" test ! -e "$TEST_ROOT/wt1/.superpowers"

    local landed="" requeued="" b
    for n in 1 2 3; do
        b="$(git rev-parse --short HEAD)"
        if git "${g[@]}" merge -q --no-ff -m "land task $n" "sdd/plan/task-$n" >/dev/null 2>&1; then
            echo "Task $n: complete (commits $b..$(git rev-parse --short HEAD), review clean; models: impl haiku, review sonnet, rounds 0)" >> "$ledger"
            landed="$landed$n"
        else
            git merge --abort
            echo "Wave: Task $n re-queued — conflicted with src/greet.sh" >> "$ledger"
            requeued="$requeued$n"
        fi
    done
    check "tasks 1 and 2 land in order" test "$landed" = "12"
    check "the conflicting task is aborted and re-queued" test "$requeued" = "3"
    check "an aborted merge leaves a clean tree" test -z "$(git status --porcelain)"
    check "the landed wave passes the suite" bash -c "bash '$SK/suite-run' '$plan' -- sh test.sh 2>&1 | grep -q '3 passed'"

    for n in 1 2 3; do
        git worktree remove --force "$TEST_ROOT/wt$n"
        git branch -q -D "sdd/plan/task-$n"
    done
    check "wave worktrees are removed" test "$(git worktree list | grep -c '')" -eq 1

    b="$(git rev-parse --short HEAD)"
    echo 'echo HELLO' > src/greet.sh && git add -A && git "${g[@]}" commit -qm "task 3 (serial)"
    bash "$SK/suite-run" - -- sh test.sh >/dev/null 2>&1
    bash "$SK/task-verify" "$plan" 3 -- sh test.sh >/dev/null 2>&1
    echo "Task 3: complete (commits $b..$(git rev-parse --short HEAD), review clean; models: impl haiku, review sonnet, rounds 0)" >> "$ledger"
    check "the re-queued task lands serially" test "$(sh src/greet.sh)" = "HELLO"

    local summary
    summary="$(bash "$SK/run-summary" "$plan")"
    check "summary counts three completed tasks" grep -q "^Tasks: 3 complete" <<<"$summary"
    # Tasks 1 and 2 in the wave and task 3 serially recorded their runs.
    check "summary counts reused verifications" \
        grep -q "^Task verifications: 1 re-ran tests, 3 reused a recorded green run" <<<"$summary"

    echo
    if [[ "$FAILURES" -eq 0 ]]; then
        echo "PASS"
    else
        echo "FAIL ($FAILURES)"
        exit 1
    fi
}

main "$@"
