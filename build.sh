#!/bin/bash
set -euo pipefail

APP_NAME="MenuBrowser"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"

echo "Cleaning build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${MACOS}"

echo "Compiling..."
xcrun swiftc \
    -o "${MACOS}/${APP_NAME}" \
    -framework AppKit \
    -framework SwiftUI \
    -framework ServiceManagement \
    -framework CoreServices \
    -framework Carbon \
    -target arm64-apple-macos26.0 \
    Sources/main.swift \
    Sources/BrowserManager.swift \
    Sources/HotkeyManager.swift \
    Sources/PreferencesView.swift \
    Sources/AppDelegate.swift

echo "Copying Info.plist..."
cp Info.plist "${CONTENTS}/Info.plist"

echo "Copying app icon..."
mkdir -p "${CONTENTS}/Resources"
cp AppIcon.icns "${CONTENTS}/Resources/AppIcon.icns"

echo "Code signing..."
SIGN_IDENTITY=$(security find-identity -v -p codesigning | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [ -n "$SIGN_IDENTITY" ]; then
    codesign --force --sign "$SIGN_IDENTITY" "${APP_BUNDLE}"
    echo "Signed with: $SIGN_IDENTITY"
else
    codesign --force --sign - "${APP_BUNDLE}"
    echo "Warning: ad-hoc signed (Accessibility permission will reset on rebuild)"
fi

echo "Build complete: ${APP_BUNDLE}"
echo "Run with: open ${APP_BUNDLE}"
