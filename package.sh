#!/bin/bash
set -euo pipefail

APP_NAME="MenuBrowser"
VERSION="1.0"
BUILD_DIR="build"
DMG_NAME="${APP_NAME}-${VERSION}"
DMG_FINAL="${BUILD_DIR}/${DMG_NAME}.dmg"
DMG_TEMP="${BUILD_DIR}/${DMG_NAME}-temp.dmg"
STAGING_DIR="${BUILD_DIR}/dmg-staging"
VOLUME_NAME="${APP_NAME}"
BG_PNG="${BUILD_DIR}/dmg-background.png"

# DMG window dimensions
WIN_W=660
WIN_H=400

echo "=== MenuBrowser DMG Packager ==="
echo ""

# Step 1: Build the app
echo "[1/6] Building app..."
./build.sh
echo ""

# Step 2: Generate background image with Swift + Core Graphics
echo "[2/6] Generating background image..."
BG_GEN="${BUILD_DIR}/generate-dmg-bg"
xcrun swiftc -o "${BG_GEN}" -framework CoreGraphics -framework CoreText -framework ImageIO \
    -target arm64-apple-macos26.0 generate-dmg-bg.swift 2>/dev/null
"${BG_GEN}" "${BG_PNG}"
rm -f "${BG_GEN}"

# Step 3: Create staging directory
echo "[3/6] Staging DMG contents..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}/.background"

cp -R "${BUILD_DIR}/${APP_NAME}.app" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

if [ -f "${BG_PNG}" ]; then
    cp "${BG_PNG}" "${STAGING_DIR}/.background/background.png"
fi

# Step 4: Create writable DMG
echo "[4/6] Creating DMG..."
rm -f "${DMG_TEMP}" "${DMG_FINAL}"

SIZE_KB=$(du -sk "${STAGING_DIR}" | cut -f1)
SIZE_KB=$((SIZE_KB + 10240))

hdiutil create \
    -srcfolder "${STAGING_DIR}" \
    -volname "${VOLUME_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${SIZE_KB}k" \
    "${DMG_TEMP}" \
    >/dev/null

# Step 5: Mount and customize Finder window
echo "[5/6] Customizing DMG window..."
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify "${DMG_TEMP}" | grep "/Volumes/")
DEVICE=$(echo "${MOUNT_OUTPUT}" | head -1 | awk '{print $1}')
MOUNT_POINT="/Volumes/${VOLUME_NAME}"

sleep 2

osascript <<EOF
tell application "Finder"
    activate
    delay 1

    tell disk "${VOLUME_NAME}"
        open
        delay 1

        set cw to container window
        set current view of cw to icon view
        set toolbar visible of cw to false
        set statusbar visible of cw to false
        set sidebar width of cw to 0
        delay 0.5

        set the bounds of cw to {200, 200, $((200 + WIN_W)), $((200 + WIN_H))}
        delay 0.5

        set vo to the icon view options of cw
        set arrangement of vo to not arranged
        set icon size of vo to 128
        set text size of vo to 14
        set background picture of vo to file ".background:background.png"
        delay 0.5

        set position of item "${APP_NAME}.app" of cw to {180, 180}
        set position of item "Applications" of cw to {480, 180}
        delay 0.5

        -- Close and reopen to force .DS_Store write
        close
        delay 1
        open
        delay 2

        set cw to container window
        set current view of cw to icon view
        set toolbar visible of cw to false
        set statusbar visible of cw to false
        set sidebar width of cw to 0
        set the bounds of cw to {200, 200, $((200 + WIN_W)), $((200 + WIN_H))}
        delay 1
        close
    end tell
end tell
EOF

# Ensure .DS_Store is flushed
sync
sleep 2

# Detach
hdiutil detach "${DEVICE}" -quiet || hdiutil detach "${DEVICE}" -force -quiet || true
sleep 1

# Step 6: Convert to compressed read-only DMG
echo "[6/6] Compressing DMG..."
hdiutil convert \
    "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_FINAL}" \
    >/dev/null

# Cleanup
rm -f "${DMG_TEMP}"
rm -rf "${STAGING_DIR}"
rm -f "${BG_PNG}"

DMG_SIZE=$(du -h "${DMG_FINAL}" | cut -f1 | xargs)
echo ""
echo "=== Done ==="
echo "DMG: ${DMG_FINAL} (${DMG_SIZE})"
echo "Open with: open ${DMG_FINAL}"
