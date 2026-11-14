#!/bin/zsh
set -euo pipefail

APP_NAME="PiPWindow"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
MODULE_CACHE="/tmp/pipwindow-module-cache"

echo "Building ${APP_NAME}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${MODULE_CACHE}"

swiftc \
    -O \
    -disable-sandbox \
    -target arm64-apple-macosx14.0 \
    -sdk "$(xcrun --show-sdk-path --sdk macosx)" \
    -module-cache-path "${MODULE_CACHE}" \
    -framework AppKit \
    -framework SwiftUI \
    -framework ScreenCaptureKit \
    -framework AVFoundation \
    -framework CoreMedia \
    -framework CoreVideo \
    -framework QuartzCore \
    Sources/PiPWindow/Models/WindowItem.swift \
    Sources/PiPWindow/Services/WindowCaptureStream.swift \
    Sources/PiPWindow/Services/WindowListViewModel.swift \
    Sources/PiPWindow/UI/PiPPanelController.swift \
    Sources/PiPWindow/UI/PiPContainerView.swift \
    Sources/PiPWindow/UI/ContentView.swift \
    Sources/PiPWindow/PiPWindowApp.swift \
    -o "${MACOS_DIR}/${APP_NAME}"

cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Strip iCloud/Finder extended attributes so codesign succeeds inside iCloud Drive folders
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true

# Ad-hoc sign the app bundle so macOS Screen Recording permissions persist cleanly
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Successfully built ${APP_BUNDLE}"
