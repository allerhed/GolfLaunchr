#!/bin/bash
# Usage: scripts/screenshot.sh <name> [bundle-id-launch-args...]  -> Validation/Screens/<name>.png (gitignored)
cd "$(dirname "$0")/.." && source scripts/env.sh
mkdir -p Validation/Screens
xcrun simctl bootstatus "$SIM_NAME" -b >/dev/null 2>&1 || xcrun simctl boot "$SIM_NAME"
xcrun simctl io "$SIM_NAME" screenshot "Validation/Screens/$1.png" && echo "Validation/Screens/$1.png"
