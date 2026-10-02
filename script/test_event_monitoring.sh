#!/usr/bin/env bash
# Run after ./script/build_and_run.sh --verify. No input events are posted.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCTS="${DERIVED_DATA_PATH:-$ROOT_DIR/.codex/rename-build}/Build/Products/Debug"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/loop-event-tests.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT

SANITIZER="${1:-thread}"
case "$SANITIZER" in
    thread|address) ;;
    *) echo "Usage: $0 [thread|address]" >&2; exit 2 ;;
esac

xcrun swiftc -g -Onone -swift-version 5 -sanitize="$SANITIZER" \
    -I "$PRODUCTS" \
    -load-plugin-executable "$PRODUCTS/ScribeMacros#ScribeMacros" \
    "$PRODUCTS/Defaults.o" "$PRODUCTS/Scribe.o" \
    "$ROOT_DIR/Tests/EventMonitoring/Fixtures.swift" \
    "$ROOT_DIR/Tests/EventMonitoring/Regression.swift" \
    "$ROOT_DIR/Wally‘s Hand/Window Management/Window Action/WindowActionCache.swift" \
    "$ROOT_DIR/Wally‘s Hand/Utilities/Event Monitoring/EventMonitorProtocol.swift" \
    "$ROOT_DIR/Wally‘s Hand/Utilities/Event Monitoring/EventTapThread.swift" \
    "$ROOT_DIR/Wally‘s Hand/Utilities/Event Monitoring/BaseEventTapMonitor.swift" \
    "$ROOT_DIR/Wally‘s Hand/Utilities/Event Monitoring/ActiveEventMonitor.swift" \
    "$ROOT_DIR/Wally‘s Hand/Utilities/Event Monitoring/PassiveEventMonitor.swift" \
    -o "$TEST_DIR/regression"
TSAN_OPTIONS="halt_on_error=1" ASAN_OPTIONS="halt_on_error=1" "$TEST_DIR/regression"
