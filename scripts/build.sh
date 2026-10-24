#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-Release}"
xcodebuild -workspace Pock.xcworkspace -scheme PockWithWidgets \
  -configuration "$configuration" -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build

resources=".build/DerivedData/Build/Products/$configuration/Pock.app/Contents/Resources/DefaultWidgets"
rm -rf "$resources"
mkdir -p "$resources"
for widget in Esc Dock NowPlaying Status Weather; do
  widget_product=".build/DerivedData/Build/Products/$configuration/$widget.pock"
  xattr -cr "$widget_product"
  codesign --force --deep --sign - "$widget_product"
  ditto -c -k --keepParent --norsrc \
    ".build/DerivedData/Build/Products/$configuration/$widget.pock" "$resources/$widget.pkarchive"
done

python3 - "$configuration" <<'PYTHON'
import json
import plistlib
from pathlib import Path
import sys
products = Path('.build/DerivedData/Build/Products') / sys.argv[1]
resources = products / 'Pock.app/Contents/Resources/DefaultWidgets'
catalog = {}
for name in ('Esc', 'Dock', 'NowPlaying', 'Status', 'Weather'):
    with (products / f'{name}.pock/Contents/Info.plist').open('rb') as handle:
        info = plistlib.load(handle)
    catalog[info['CFBundleIdentifier']] = f'{name}.pkarchive'
(resources / 'catalog.json').write_text(json.dumps(catalog, indent=2) + '\n')
PYTHON
