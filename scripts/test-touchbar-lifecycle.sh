#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
products="$PWD/.build/DerivedData/Build/Products/Release"
mkdir -p .build/tests
xcrun swiftc -swift-version 5 -module-cache-path .build/tests/ModuleCache \
  -F "$products/PockKit" -F "$products/TinyConstraints" \
  -framework PockKit -Xlinker -rpath -Xlinker "$products/PockKit" \
  -Xlinker -rpath -Xlinker "$products/TinyConstraints" \
  Pock/UI/TouchBar/EmptyTouchBarController/EmptyTouchBarController.swift \
  Pock/Extensions/NSView+Extensions.swift Tests/TouchBarLifecycleTests.swift \
  -o .build/tests/TouchBarLifecycleTests
.build/tests/TouchBarLifecycleTests
