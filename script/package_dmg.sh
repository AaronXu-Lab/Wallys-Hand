#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.codex/wallys-hand-release}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/Wally‘s Hand.app"
mkdir -p "$OUTPUT_DIR"
xcodebuild -project "$ROOT_DIR/Wally‘s Hand.xcodeproj" -scheme "Wally‘s Hand (GH ACTIONS)" \
  -configuration Release -derivedDataPath "$DERIVED_DATA_PATH" \
  build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  VERSION="${APP_VERSION:-0.0.2}" BUILD_NUMBER="${APP_BUILD:-1}"
# Sign embedded Mach-O helpers and libraries before containing bundles.
while IFS= read -r -d '' binary; do
  if file -b "$binary" | grep -q 'Mach-O'; then
    codesign --force --sign - "$binary"
  fi
done < <(find "$APP_PATH/Contents" -type f -print0)
# Ad-hoc signing requires no Apple account or signing certificate.
while IFS= read -r -d '' framework; do
  codesign --force --sign - "$framework"
done < <(find "$APP_PATH/Contents" -depth -name '*.framework' -print0)
while IFS= read -r -d '' helper; do
  codesign --force --sign - "$helper"
done < <(find "$APP_PATH/Contents" -depth \( -name '*.xpc' -o -name '*.appex' -o -name '*.bundle' -o -name '*.app' \) -print0)
codesign --force --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT
ditto "$APP_PATH" "$STAGE_DIR/Wally‘s Hand.app"
ln -s /Applications "$STAGE_DIR/Applications"
hdiutil create -volname "Wally‘s Hand" -srcfolder "$STAGE_DIR" -ov -format UDZO "$OUTPUT_DIR/Wallys-Hand.dmg"
hdiutil verify "$OUTPUT_DIR/Wallys-Hand.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$OUTPUT_DIR/Wallys-Hand.zip"
(cd "$OUTPUT_DIR" && shasum -a 256 Wallys-Hand.dmg Wallys-Hand.zip > SHA256SUMS.txt)
