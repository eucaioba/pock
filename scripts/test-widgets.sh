#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
products="$PWD/.build/DerivedData/Build/Products/${1:-Release}"
mkdir -p .build/tests
xcrun swiftc -module-cache-path .build/tests/ModuleCache \
  -F "$products/PockKit" -framework PockKit \
  -Xlinker -rpath -Xlinker "$products/PockKit" \
  -Xlinker -rpath -Xlinker "$products/TinyConstraints" \
  -Xlinker -rpath -Xlinker "$products/Defaults" \
  Tests/WidgetLoadTests.swift -o .build/tests/WidgetLoadTests
.build/tests/WidgetLoadTests "$products/Esc.pock" "$products/Dock.pock" \
  "$products/NowPlaying.pock" "$products/Status.pock" \
  "$products/ControlCenter.pock" "$products/Weather.pock"
