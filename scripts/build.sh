#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-Release}"
xcodebuild -workspace Pock.xcworkspace -scheme Pock \
  -configuration "$configuration" -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
