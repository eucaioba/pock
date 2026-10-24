#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_app=".build/DerivedData/Build/Products/Release/Pock.app"
# Stage outside Documents: file providers can reattach Finder metadata while
# codesign is running, even immediately after xattr cleanup.
staging_root="$(mktemp -d /private/tmp/pock-install.XXXXXX)"
trap 'rm -rf "$staging_root"' EXIT
signed_app="$staging_root/Pock.app"
if [[ ! -x "$source_app/Contents/MacOS/Pock" ]]; then
  echo "Build Release first: bash scripts/build.sh Release" >&2
  exit 1
fi
if pgrep -x Pock >/dev/null; then
  echo "Quit Pock before installing." >&2
  exit 1
fi
mkdir -p .build/LocalInstall
ditto --noextattr --norsrc "$source_app" "$signed_app"
# Local build folders can inherit Finder metadata that codesign rejects.
xattr -cr "$signed_app"
# A stable identity keeps Accessibility/Automation grants across rebuilds;
# ad hoc signatures change identity on every build. See create-local-signing-identity.sh.
identity="${POCK_SIGN_IDENTITY:-Pock Local Signing}"
if security find-certificate -c "$identity" >/dev/null 2>&1; then
  codesign --force --deep --sign "$identity" "$signed_app"
else
  echo "warning: \"$identity\" not found, signing ad hoc. Permissions will need to be granted again after each install." >&2
  codesign --force --deep --sign - "$signed_app"
fi
codesign --verify --deep --strict "$signed_app"
# Keep backups out of /Applications so Launchpad and Spotlight only show one Pock.
app_backups=".build/LocalInstall/AppBackups"
if [[ -e /Applications/Pock.app ]]; then
  mkdir -p "$app_backups"
  mv /Applications/Pock.app "$app_backups/Pock-$(date +%Y%m%d-%H%M%S).app"
  # Keep the three most recent backups.
  ls -1d "$app_backups"/Pock-*.app | sort -r | tail -n +4 | while read -r old_backup; do rm -rf "$old_backup"; done
fi
ditto --noextattr --norsrc "$signed_app" /Applications/Pock.app
codesign --verify --deep --strict /Applications/Pock.app
# Install the matching default widgets as well as the host application.
widget_stage="$staging_root/Widgets"
widget_backups=".build/LocalInstall/WidgetBackups-$(date +%Y%m%d-%H%M%S)"
widget_destination="$HOME/Library/Application Support/Pock/Widgets"
mkdir -p "$widget_stage" "$widget_destination"
for archive in "$signed_app"/Contents/Resources/DefaultWidgets/*.pkarchive; do
  ditto -xk --noextattr --norsrc "$archive" "$widget_stage"
done
for widget in "$widget_stage"/*.pock; do
  codesign --verify --deep --strict "$widget"
  widget_name="$(basename "$widget")"
  if [[ -e "$widget_destination/$widget_name" ]]; then
    mkdir -p "$widget_backups"
    mv "$widget_destination/$widget_name" "$widget_backups/$widget_name"
  fi
  ditto --noextattr --norsrc "$widget" "$widget_destination/$widget_name"
done
open /Applications/Pock.app
