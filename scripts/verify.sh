#!/bin/bash
# The gate. Generates the project, runs package tests, app build + unit tests, l10n check.
# Usage: scripts/verify.sh [--ui]   (--ui also runs UI tests, slower)
# Output is deliberately quiet: only failures and a summary, to save tokens.
set -o pipefail
cd "$(dirname "$0")/.." && source scripts/env.sh
UI=0; [ "$1" = "--ui" ] && UI=1
LOG=build/verify.log; mkdir -p build; : > "$LOG"
step(){ echo "== $1"; }
fail(){ echo "VERIFY FAILED at: $1"; echo "--- last errors (full log: $LOG) ---"; grep -E "error:|failed|Fatal|✘|Issue" "$LOG" | sort -u | head -30; exit 1; }

step "lint + format"
swiftformat --lint . >>"$LOG" 2>&1 || { echo "Formatting violations (fix: swiftformat .)"; grep -E "error|warning" "$LOG" | head -10; fail "swiftformat --lint"; }
swiftlint --strict --quiet >>"$LOG" 2>&1 || fail "swiftlint"

step "package tests"
for p in Packages/*/; do
  [ -f "$p/Package.swift" ] || continue
  (cd "$p" && swift test) >>"$LOG" 2>&1 || fail "swift test $p"
done

step "l10n parity"
scripts/l10n-check.sh >>"$LOG" 2>&1 || { cat "$LOG" | tail -20; fail "l10n-check"; }

step "xcodegen"
xcodegen generate >>"$LOG" 2>&1 || fail "xcodegen"

DEST="platform=iOS Simulator,name=$SIM_NAME"
step "app build + unit tests"
xcodebuild test -project GolfLaunchr.xcodeproj -scheme "$SCHEME" -destination "$DEST" \
  -derivedDataPath "$DERIVED" -skipPackagePluginValidation \
  -only-testing:GolfLaunchrTests >>"$LOG" 2>&1 || fail "unit tests"

step "harness separation (Release has no debug harness)"
scripts/check-harness-separation.sh >>"$LOG" 2>&1 || { tail -5 "$LOG"; fail "harness separation"; }

if [ $UI = 1 ]; then
  step "UI tests"
  xcodebuild test -project GolfLaunchr.xcodeproj -scheme "$SCHEME" -destination "$DEST" \
    -derivedDataPath "$DERIVED" -only-testing:GolfLaunchrUITests >>"$LOG" 2>&1 || fail "UI tests"
fi
echo "VERIFY OK (unit$( [ $UI = 1 ] && echo ' + UI')). Device-only gates (G1/G2 capture, StoreKit) remain NOT RUN."
