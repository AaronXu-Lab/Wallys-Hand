#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wally-cli-tests.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -swift-version 5 \
    "$ROOT_DIR/Wally‘s Hand/App/CLI/PortCLICommand.swift" \
    "$ROOT_DIR/Wally‘s Hand/Port Management/PortServiceManager.swift" \
    "$ROOT_DIR/Wally‘s Hand/Port Management/PortService.swift" \
    "$ROOT_DIR/Wally‘s Hand/Port Management/PortProcess.swift" \
    "$ROOT_DIR/Wally‘s Hand/Port Management/PortPlaceholder.swift" \
    "$ROOT_DIR/Wally‘s Hand/Port Management/PortSupervisor.swift" \
    "$ROOT_DIR/Tests/CLI/Regression.swift" -o "$TEST_DIR/regression"
"$TEST_DIR/regression"
