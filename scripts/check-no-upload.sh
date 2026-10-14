#!/bin/bash
# F21 network audit (static): the app code must not contain any way to send data off the device. Fails on networking APIs in
# App/ or Packages/*/Sources, and on third-party package dependencies. Opening a link with openURL (user-initiated) is allowed.
# Usage: scripts/check-no-upload.sh [root]   (root defaults to the repository)
cd "${1:-$(dirname "$0")/..}" || exit 2
PATTERN='URLSession|URLRequest|NSURLConnection|NWConnection|NWListener|CFStream|CFSocket|WebSocket|MultipeerConnectivity|WKWebView|SFSafariViewController|import Network|import CloudKit|import (Firebase|Alamofire|Sentry|Crashlytics|Amplitude|Mixpanel|Segment)'
hits=$(grep -rnE "$PATTERN" App Packages --include='*.swift' 2>/dev/null | grep -v '/Tests/' | grep -v '/\.build/' | grep -vE '^[^:]*:[0-9]+:\s*///?')
if [ -n "$hits" ]; then
  echo "FAIL: networking or analytics APIs found in shipping code:"; echo "$hits" | head -20; exit 1
fi
# Third-party dependencies would be a channel too: only local packages are allowed.
if grep -rnE '\.package\(url:|url: *"https?://' Packages/*/Package.swift project.yml 2>/dev/null | grep -v 'schemas'; then
  echo "FAIL: third-party package dependency found"; exit 1
fi
echo "no-upload ok"
