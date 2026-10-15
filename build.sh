#!/bin/bash
# 编译并打包成 build/TodoFloat.app
# 用法：./build.sh            只打包
#       ./build.sh --install  打包并安装到 ~/Applications，然后启动
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="TodoFloat"
APP="build/$APP_NAME.app"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "已生成 $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x "$APP_NAME" || true
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/$APP_NAME.app"
    cp -R "$APP" "$HOME/Applications/"
    open "$HOME/Applications/$APP_NAME.app"
    echo "已安装到 ~/Applications/$APP_NAME.app 并启动"
fi
