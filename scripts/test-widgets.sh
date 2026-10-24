#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
products="$PWD/.build/DerivedData/Build/Products/${1:-Release}"
mkdir -p .build/tests
xcrun swiftc -module-cache-path .build/tests/ModuleCache \
  -F "$products/PockKit" -framework PockKit \
  -Xlinker -rpath -Xlinker "$products/PockKit" \
  -Xlinker -rpath -Xlinker "$products/TinyConstraints" \
  Tests/WidgetLoadTests.swift -o .build/tests/WidgetLoadTests
.build/tests/WidgetLoadTests "$products/Esc.pock" \
  "$products/NowPlaying.pock" \
  "$products/Weather.pock"
