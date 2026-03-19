#!/bin/bash
set -e

APP_NAME="RemindersMac"
BUNDLE_ID="com.reminders.mac"
BUILD_DIR=".build/arm64-apple-macosx/debug"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ENV_SOURCE_FILE=".env.local"
BUNDLE_ENV_FILE="$APP_BUNDLE/Contents/Resources/AIConfig.env"

sign_app_bundle() {
    local designated_requirement="designated => identifier \"$BUNDLE_ID\""
    echo "Signing app bundle with stable designated requirement..."
    codesign --force --deep --sign - -r="$designated_requirement" "$APP_BUNDLE"
}

usage() {
    echo "用法: ./app.sh [命令]"
    echo ""
    echo "命令:"
    echo "  build   仅构建项目"
    echo "  run     构建并运行（默认）"
    echo "  kill    终止运行中的进程"
    echo "  restart 先终止再重新构建运行"
    echo ""
    exit 0
}

do_kill() {
    if pgrep -f "$APP_NAME" > /dev/null 2>&1; then
        pkill -9 -f "$APP_NAME" 2>/dev/null
        sleep 1
        echo "已终止 $APP_NAME"
    else
        echo "$APP_NAME 未在运行"
    fi
}

install_runtime_ai_config() {
    rm -f "$BUNDLE_ENV_FILE"

    if [[ -f "$ENV_SOURCE_FILE" ]]; then
        cp "$ENV_SOURCE_FILE" "$BUNDLE_ENV_FILE"
        echo "已注入本地 AI 配置"
    else
        echo "警告: 未找到 $ENV_SOURCE_FILE，AI 解析功能将不可用"
    fi
}

do_build() {
    echo "Building..."
    swift build

    echo "Creating app bundle..."
    rm -rf "$APP_BUNDLE"
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"

    cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

    if [[ -f "Resources/AppIcon.icns" ]]; then
        cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    fi

    install_runtime_ai_config

    cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.reminders.mac</string>
    <key>CFBundleName</key>
    <string>RemindersMac</string>
    <key>CFBundleExecutable</key>
    <string>RemindersMac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
PLIST

    sign_app_bundle

    echo "Build 完成"
}

do_run() {
    do_build
    echo "Launching $APP_NAME.app..."
    open "$APP_BUNDLE"
}

CMD="${1:-run}"

case "$CMD" in
    build)   do_build ;;
    run)     do_run ;;
    kill)    do_kill ;;
    restart) do_kill; do_run ;;
    -h|--help|help) usage ;;
    *) echo "未知命令: $CMD"; usage ;;
esac
