#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc \
    "$ROOT_DIR/Wally‘s Hand/Memory Monitoring/MemorySnapshot.swift" \
    "$ROOT_DIR/Wally‘s Hand/Memory Monitoring/MemorySampler.swift" \
    "$ROOT_DIR/Tests/MemoryMonitoring/Regression.swift" \
    -o "$TEST_DIR/memory-regression"
"$TEST_DIR/memory-regression"
