#!/usr/bin/env bash
# Tests for the deploy helpers: landing-and-deploying's scripts/poll-until
# (bounded waiting on a read-only status command, judged by exit code) and
# verifying-a-deploy's scripts/http-probe (one line per URL, content check).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
POLL="$REPO_ROOT/skills/landing-and-deploying/scripts/poll-until"
PROBE="$REPO_ROOT/skills/verifying-a-deploy/scripts/http-probe"

FAILURES=0
TEST_ROOT=""
SERVER_PID=""

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

cleanup() {
    if [[ -n "$SERVER_PID" ]]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}

expect_rc() {
    local want=$1 name=$2
    shift 2
    local rc=0
    "$@" >"$TEST_ROOT/out" 2>&1 || rc=$?
    if [[ "$rc" -eq "$want" ]]; then
        pass "$name"
    else
        fail "$name (exit $rc, wanted $want)"
        sed 's/^/      /' "$TEST_ROOT/out"
    fi
}

test_poll_until() {
    echo "--- poll-until ---"
    expect_rc 0 "succeeds when the command exits 0" "$POLL" --interval 1 --timeout 5 -- true
    expect_rc 124 "times out while still pending" "$POLL" --interval 1 --timeout 2 -- false
    expect_rc 1 "a non-pending exit code is a failure" \
        "$POLL" --interval 1 --timeout 5 --pending-exit 8 -- sh -c 'exit 1'
    expect_rc 124 "a pending exit code keeps waiting" \
        "$POLL" --interval 1 --timeout 2 --pending-exit 8 -- sh -c 'exit 8'
    expect_rc 1 "output matching --fail-pattern is a failure" \
        "$POLL" --interval 1 --timeout 5 --fail-pattern 'build failed' -- sh -c 'echo build failed; exit 3'
    expect_rc 124 "\"0 failing\" is not matched by an exit-code check" \
        "$POLL" --interval 1 --timeout 2 --pending-exit 8 -- sh -c 'echo "0 failing, 2 pending"; exit 8'

    local counter="$TEST_ROOT/count"
    echo 0 >"$counter"
    expect_rc 0 "succeeds once a pending command turns green" \
        "$POLL" --interval 1 --timeout 10 --pending-exit 8 -- sh -c \
        "n=\$(cat '$counter'); n=\$((n + 1)); echo \$n > '$counter'; [ \$n -ge 3 ] && exit 0; exit 8"

    expect_rc 2 "rejects a missing command" "$POLL" --interval 1
    expect_rc 2 "rejects a non-numeric interval" "$POLL" --interval soon -- true
}

free_port() {
    python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}

test_http_probe() {
    echo "--- http-probe ---"
    expect_rc 2 "rejects no URL" "$PROBE"
    expect_rc 1 "an unreachable URL fails" "$PROBE" --max-time 2 "http://127.0.0.1:1/health"
    if grep -q "status=000 .*FAIL (unreachable)" "$TEST_ROOT/out"; then
        pass "reports unreachable"
    else
        fail "reports unreachable"
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo "  [SKIP] python3 not available; live-server cases skipped"
        return
    fi
    local site="$TEST_ROOT/site" port
    mkdir -p "$site"
    echo "version abc1234" >"$site/health"
    port="$(free_port)"
    python3 -m http.server "$port" --bind 127.0.0.1 --directory "$site" >/dev/null 2>&1 &
    SERVER_PID=$!
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        curl -s -o /dev/null "http://127.0.0.1:$port/health" && break
        sleep 0.5
    done
    local base="http://127.0.0.1:$port"

    expect_rc 0 "a 200 with the expected content passes" "$PROBE" --contains abc1234 "$base/health"
    expect_rc 1 "missing content fails" "$PROBE" --contains def5678 "$base/health"
    expect_rc 1 "a 404 fails by default" "$PROBE" "$base/missing"
    expect_rc 0 "--expect accepts a specific code" "$PROBE" --expect 404 "$base/missing"
    expect_rc 1 "one failing URL fails the run" "$PROBE" "$base/health" "$base/missing"
    if [[ "$(grep -c '' "$TEST_ROOT/out")" -eq 2 ]]; then
        pass "prints one line per URL"
    else
        fail "prints one line per URL"
    fi

    local log="$TEST_ROOT/probe.tsv"
    "$PROBE" --log "$log" "$base/health" "$base/missing" >/dev/null 2>&1 || true
    if [[ "$(grep -c '' "$log")" -eq 2 ]] && awk -F'\t' 'NF != 6 { bad = 1 } END { exit bad }' "$log" \
        && grep -q $'\t200\t.*\tok$' "$log" && grep -q $'\t404\t.*\tfail$' "$log"; then
        pass "--log appends one six-field line per probe"
    else
        fail "--log appends one six-field line per probe"
        sed 's/^/      /' "$log"
    fi
}

main() {
    echo "=== Test: deploy scripts ==="
    TEST_ROOT="$(mktemp -d)"
    trap cleanup EXIT

    test_poll_until
    test_http_probe

    if [[ "$FAILURES" -gt 0 ]]; then
        echo "=== FAILED: $FAILURES ==="
        exit 1
    fi
    echo "=== All deploy script tests passed ==="
}

main "$@"
