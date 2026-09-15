#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AirPods Privacy Blur"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
EXECUTABLE="$ROOT_DIR/.build/release/AirPodsPrivacyBlur"
LOGO="$ROOT_DIR/Resources/logo.png"
ROUNDED_LOGO="$ROOT_DIR/Resources/logo-rounded.png"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"

cd "$ROOT_DIR"
if [ -f "$LOGO" ]; then
    swift "$ROOT_DIR/scripts/make_app_icon.swift" "$LOGO" "$APP_ICON" "$ROUNDED_LOGO"
fi

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/AirPodsPrivacyBlur"
cp "$ROOT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
printf "APPL????" > "$APP_DIR/Contents/PkgInfo"

if [ -d "$ROOT_DIR/Resources" ]; then
    find "$ROOT_DIR/Resources" -maxdepth 1 -type f -exec cp {} "$APP_DIR/Contents/Resources/" \;
fi

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"
