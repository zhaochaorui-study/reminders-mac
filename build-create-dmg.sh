#!/bin/bash
set -euo pipefail

APP_NAME="RemindersMac"
BUNDLE_ID="com.reminders.mac"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTIFACT_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$ARTIFACT_DIR/$APP_NAME.app"
BUNDLE_ENV_FILE="$APP_BUNDLE/Contents/Resources/AIConfig.env"
ENV_SOURCE_FILE="$ROOT_DIR/.env.local"
VERSION="${APP_VERSION:-${1:-1.0}}"
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$ARTIFACT_DIR/$DMG_NAME"
STAGING_DIR=""

require_command() {
    local command_name="$1"
    local install_hint="${2:-}"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "error: missing required command '$command_name'"
        if [[ -n "$install_hint" ]]; then
            echo "$install_hint"
        fi
        exit 1
    fi
}

cleanup() {
    if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
        rm -rf "$STAGING_DIR"
    fi
}

trap cleanup EXIT

require_command swift
require_command create-dmg "Install it with: brew install create-dmg"
require_command ditto

sign_app_bundle() {
    local sign_identity="$1"
    local -a sign_args=(--force --deep --sign "$sign_identity")

    if [[ "$sign_identity" != "-" ]]; then
        sign_args+=(--options runtime)
    else
        sign_args+=(-r "designated => identifier \"$BUNDLE_ID\"")
    fi

    echo "==> Signing app bundle ($sign_identity)"
    codesign "${sign_args[@]}" "$APP_BUNDLE"
}

install_runtime_ai_config() {
    rm -f "$BUNDLE_ENV_FILE"

    if [[ -f "$ENV_SOURCE_FILE" ]]; then
        cp "$ENV_SOURCE_FILE" "$BUNDLE_ENV_FILE"
        echo "==> Injecting local AI config"
    else
        echo "warning: missing $ENV_SOURCE_FILE, AI parsing will be unavailable"
    fi
}

mkdir -p "$ARTIFACT_DIR"
STAGING_DIR="$(mktemp -d "$ARTIFACT_DIR/create-dmg.XXXXXX")"

cd "$ROOT_DIR"

echo "==> Building latest release binary"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BINARY_PATH="$BIN_DIR/$APP_NAME"

if [[ ! -x "$BINARY_PATH" ]]; then
    echo "error: built binary not found at $BINARY_PATH"
    exit 1
fi

echo "==> Assembling app bundle"
rm -rf "$APP_BUNDLE" "$DMG_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

install_runtime_ai_config

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
    SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
    sign_app_bundle "$SIGN_IDENTITY"
fi

echo "==> Preparing DMG staging"
ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"

echo "==> Creating DMG"
rm -f "$DMG_PATH"
create-dmg \
    --volname "$APP_NAME" \
    --window-pos 200 120 \
    --window-size 680 420 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 180 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 500 190 \
    "$DMG_PATH" \
    "$STAGING_DIR"

echo "==> Done"
echo "App bundle: $APP_BUNDLE"
echo "DMG: $DMG_PATH"
