#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DERIVED="${TMPDIR:-/tmp}/theone-ios-derived-data"

xcodebuild \
  -project "$ROOT/TheOne.xcodeproj" \
  -scheme TheOne \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild \
  -project "$ROOT/TheOne.xcodeproj" \
  -scheme TheOne \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath "${DERIVED}-tests" \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
