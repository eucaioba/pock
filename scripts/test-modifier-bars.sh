#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/tests
xcrun swiftc -module-cache-path .build/tests/ModuleCache \
  Pock/UI/TouchBar/ModifierTouchBar/ModifierTouchBarLayout.swift \
  Tests/ModifierTouchBarTests.swift -o .build/tests/ModifierTouchBarTests
.build/tests/ModifierTouchBarTests
xcrun swiftc -module-cache-path .build/tests/ModuleCache \
  Pock/UI/TouchBar/AppControls/AppProfile.swift \
  Tests/AppProfileTests.swift -o .build/tests/AppProfileTests
.build/tests/AppProfileTests
xcrun swiftc -module-cache-path .build/tests/ModuleCache \
  Pock/UI/TouchBar/BuiltInWidgets/StatusLogic.swift \
  Tests/StatusLogicTests.swift -o .build/tests/StatusLogicTests
.build/tests/StatusLogicTests
