#!/bin/bash
# Checks the toolchain. Exit 1 if something required is missing.
cd "$(dirname "$0")/.." && source scripts/env.sh
ok=0
chk(){ if eval "$2" >/dev/null 2>&1; then echo "ok    $1"; else echo "FAIL  $1 -> $3"; ok=1; fi; }
chk "xcodebuild" "xcodebuild -version" "install Xcode"
chk "simulator '$SIM_NAME'" "xcrun simctl list devices available | grep -q \"$SIM_NAME \"" "set SIM_NAME to an installed simulator"
chk "xcodegen" "which xcodegen" "brew install xcodegen"
chk "gh authenticated" "gh auth status" "gh auth login"
which swiftlint >/dev/null 2>&1 && echo "ok    swiftlint" || echo "warn  swiftlint missing (optional): brew install swiftlint"
which swiftformat >/dev/null 2>&1 && echo "ok    swiftformat" || echo "warn  swiftformat missing (optional): brew install swiftformat"
xcode-select -p | grep -q Xcode.app || echo "note  xcode-select points at CLT; scripts use DEVELOPER_DIR instead (or: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer)"
exit $ok
