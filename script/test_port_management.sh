#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/port-management-tests.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
PYTHON="$(command -v python3)"
xcrun swiftc -g -Onone -swift-version 5 \
    "$ROOT_DIR/Wally‘s Hand/Port Management/PortServiceManager.swift" \
    "$ROOT_DIR/Wally‘s Hand/Port Management/PortService.swift" \
    "$ROOT_DIR/Wally‘s Hand/Port Management/PortProcess.swift" \
    "$ROOT_DIR/Wally‘s Hand/Port Management/PortPlaceholder.swift" \
    "$ROOT_DIR/Wally‘s Hand/Port Management/PortSupervisor.swift" \
    "$ROOT_DIR/Tests/PortManagement/Regression.swift" \
    -o "$TEST_DIR/regression"
"$TEST_DIR/regression" "$PYTHON"
