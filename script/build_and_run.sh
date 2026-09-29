#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Wally‘s Hand.xcodeproj"
SCHEME="Wally‘s Hand"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.codex/rename-build}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Wally‘s Hand.app"
APP_BINARY="$APP_PATH/Contents/MacOS/Wally‘s Hand"
APP_PROCESS_NAME="Wally‘s Hand"

build_app() {
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        build \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO
}

stop_app() {
    pkill -x "$APP_PROCESS_NAME" >/dev/null 2>&1 || true
}

run_app() {
    [[ -d "$APP_PATH" ]] || { echo "Built app not found: $APP_PATH" >&2; exit 1; }
    stop_app
    open -n "$APP_PATH"
}

verify_app() {
    [[ -d "$APP_PATH" ]] || { echo "Built app not found: $APP_PATH" >&2; exit 1; }
    [[ -x "$APP_BINARY" ]] || { echo "Built executable not found: $APP_BINARY" >&2; exit 1; }

    local bundle_id
    bundle_id="$(/usr/bin/defaults read "$APP_PATH/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
    [[ "$bundle_id" == "com.xuweinan.LoopJust" ]] || {
        echo "Unexpected bundle identifier: ${bundle_id:-<missing>}" >&2
        exit 1
    }

    echo "Verified: $APP_PATH"
    echo "Bundle identifier: $bundle_id"
}

MODE="${1:-run}"
case "$MODE" in
    run|--run)
        build_app
        run_app
        ;;
    --debug)
        build_app
        stop_app
        lldb -- "$APP_BINARY"
        ;;
    --logs)
        build_app
        run_app
        /usr/bin/log stream --style compact --predicate "process == \"Wally‘s Hand\""
        ;;
    --telemetry)
        build_app
        run_app
        /usr/bin/log stream --style compact --predicate "process == \"Wally‘s Hand\" OR subsystem CONTAINS[c] \"Loop\""
        ;;
    --verify)
        build_app
        verify_app
        ;;
    *)
        echo "Usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
