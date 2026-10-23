#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_app=".build/DerivedData/Build/Products/Release/Pock.app"
signed_app=".build/LocalInstall/Pock.app"
if [[ ! -x "$source_app/Contents/MacOS/Pock" ]]; then
  echo "Build Release first: bash scripts/build.sh Release" >&2
  exit 1
fi
if pgrep -x Pock >/dev/null; then
  echo "Quit Pock before installing." >&2
  exit 1
fi
mkdir -p .build/LocalInstall
# Always stage a fresh copy; the build product itself remains unsigned.
if [[ -e "$signed_app" ]]; then
  mv "$signed_app" ".build/LocalInstall/Pock-$(date +%Y%m%d-%H%M%S).app"
fi
ditto "$source_app" "$signed_app"
codesign --force --deep --sign - "$signed_app"
codesign --verify --deep --strict "$signed_app"
if [[ -e /Applications/Pock.app ]]; then
  mv /Applications/Pock.app "/Applications/Pock-backup-$(date +%Y%m%d-%H%M%S).app"
fi
ditto "$signed_app" /Applications/Pock.app
codesign --verify --deep --strict /Applications/Pock.app
open /Applications/Pock.app
