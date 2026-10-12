#!/bin/bash
# The debug capture harness must exist in Debug builds and be absent from Release builds.
# Positive control: the same search must FIND it in Debug, otherwise the check proves nothing.
cd "$(dirname "$0")/.." && source scripts/env.sh
DEST="generic/platform=iOS Simulator"
PATTERN='HistoryFixtures|-uiTestSeedHistory|HarnessModel|HarnessView|HarnessEngine|DEBUG HARNESS|CAPTURE_HARNESS|harness\.root|practice\.demoShot|Demo shot|uiTestFakeCamera|uiTestSetupScene|uiTestSetupCalibrated|FakeEnvironmentObserver|uiTestNoOrientationLock'
build() { # configuration, derived data dir
  xcodebuild build -project GolfLaunchr.xcodeproj -scheme "$SCHEME" -configuration "$1" -destination "$DEST" \
    -derivedDataPath "$2" CODE_SIGNING_ALLOWED=NO >"build/harness-$1.log" 2>&1 || { tail -5 "build/harness-$1.log"; echo "build $1 failed"; exit 2; }
}
hits() { # app bundle dir -> number of matching strings across all Mach-O files in the bundle
  local n=0 f
  while IFS= read -r f; do
    n=$((n + $(strings -a "$f" | grep -Ec "$PATTERN")))
  done < <(find "$1" -type f \( -name 'GolfLaunchr' -o -name '*.dylib' \))
  echo "$n"
}
build Debug build/DerivedData
build Release build/DerivedRelease
DEBUG_APP=$(find build/DerivedData/Build/Products -name GolfLaunchr.app -path '*Debug-iphonesimulator*' | head -1)
REL_APP=$(find build/DerivedRelease/Build/Products -name GolfLaunchr.app -path '*Release-iphonesimulator*' | head -1)
D=$(hits "$DEBUG_APP"); R=$(hits "$REL_APP")
echo "harness strings: Debug=$D Release=$R"
[ "$D" -gt 0 ] || { echo "FAIL: positive control found nothing in Debug (check is vacuous)"; exit 1; }
[ "$R" -eq 0 ] || { echo "FAIL: Release contains harness code"; exit 1; }
echo "harness separation OK"
