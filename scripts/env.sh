# Sourced by other scripts. Uses Xcode.app without sudo if xcode-select points at CLT.
if ! xcodebuild -version >/dev/null 2>&1 && [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export SIM_NAME="${SIM_NAME:-iPhone 17}"
export SCHEME=GolfLaunchr
export DERIVED=build/DerivedData
