#!/bin/zsh

set -euo pipefail

readonly project_root="${0:A:h:h}"
readonly derived_data_path="${TMPDIR:-/tmp}/DerivedAppRegression"

cd "$project_root"

xcodebuild -quiet \
  -project Derived.xcodeproj \
  -scheme Derived \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data_path" \
  CODE_SIGNING_ALLOWED=NO \
  test

xcodebuild -quiet \
  -project Derived.xcodeproj \
  -scheme Derived \
  -configuration Release \
  -derivedDataPath "$derived_data_path" \
  CODE_SIGNING_ALLOWED=NO \
  build
