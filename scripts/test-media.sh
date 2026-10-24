#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
node Tests/media-automation.test.js
mkdir -p .build/tests
xcrun swiftc -module-cache-path .build/tests/ModuleCache \
  Vendor/Widgets/now-playing-widget/NowPlaying/Sources/MediaSession.swift \
  Tests/MediaSessionTests.swift -o .build/tests/MediaSessionTests
.build/tests/MediaSessionTests
