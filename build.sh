#!/usr/bin/env bash
#
# build.sh — DeepSeek Clock
#
# ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
# │ `swift build` only produces a bare binary. macOS treats a program as a real  │
# │ menu bar app only when it lives inside a .app bundle with an Info.plist (the │
# │ file that carries `LSUIElement`, i.e. "hide the Dock icon").                 │
# │                                                                              │
# │ This script does that packaging in four predictable steps:                   │
# │   1. compile a release build with SwiftPM                                    │
# │   2. create the .app folder structure macOS expects                          │
# │   3. copy in the binary + Info.plist                                         │
# │   4. ad-hoc code-sign it so macOS will launch it locally                     │
# └──────────────────────────────────────────────────────────────────────────────┘
#
set -euo pipefail

APP_NAME="DeepSeekClock"
BUNDLE="${APP_NAME}.app"

# 1. Compile. Release mode = optimised, smaller, faster startup.
swift build -c release

# 2. Fresh bundle skeleton. The folder names inside Contents/ are fixed by macOS:
#    MacOS/ holds executables, Resources/ holds assets.
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"

# 3. Drop the compiled binary, the metadata plist, and the artwork into place.
#    AppIcon.icns is what the Finder/Dock show and is referenced by
#    CFBundleIconFile in Info.plist.
cp ".build/release/${APP_NAME}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${BUNDLE}/Contents/Info.plist"
cp "Resources/AppIcon.icns" "${BUNDLE}/Contents/Resources/AppIcon.icns"
cp "Sources/DeepSeekClock/Resources/DeepSeekWhale.pdf" "${BUNDLE}/Contents/Resources/"

# 4. Ad-hoc signature ("-") is enough for a locally-built app on the same Mac.
codesign --force --sign - "${BUNDLE}" >/dev/null 2>&1 || true

echo "Built ${BUNDLE}"
echo "Run it with:  open ${BUNDLE}"
echo "Stop it with: osascript -e 'quit app \"DeepSeek Clock\"'"
