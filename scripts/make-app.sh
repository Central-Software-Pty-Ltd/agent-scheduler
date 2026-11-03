#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

install=false
zip=false
release=false
for arg in "$@"; do
  case $arg in
    --install) install=true ;; # copies the app to ~/Applications and relaunches it
    --zip) zip=true ;; # writes build/Agent-Scheduler-<version>.zip for a GitHub release
    --release) release=true; zip=true ;; # signs with Developer ID, notarizes, staples, then zips
  esac
done

swift build -c release
app="build/Agent Scheduler.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/AgentScheduler "$app/Contents/MacOS/"
cp Info.plist "$app/Contents/"
xcrun actool Resources/Assets.xcassets Resources/AppIcon.icon \
  --compile "$app/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 15.0 \
  --app-icon AppIcon \
  --output-partial-info-plist build/assets.plist \
  --output-format human-readable-text >/dev/null
if $release; then
  codesign --force --options runtime --timestamp --sign "${SIGNING_IDENTITY:-Developer ID Application: CENTRAL SOFTWARE PTY LTD (99T8V837A5)}" "$app"
  ditto -c -k --keepParent "$app" build/notarize.zip
  xcrun notarytool submit build/notarize.zip --keychain-profile "${NOTARY_PROFILE:-agent-scheduler}" --wait
  xcrun stapler staple "$app"
  rm build/notarize.zip
else
  codesign --force --sign - "$app"
fi

if $zip; then
  version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
  ditto -c -k --keepParent "$app" "build/Agent-Scheduler-$version.zip"
fi

if $install; then
  pkill -x AgentScheduler || true
  rm -rf ~/Applications/"Agent Scheduler.app"
  mkdir -p ~/Applications
  ditto "$app" ~/Applications/"Agent Scheduler.app"
  open ~/Applications/"Agent Scheduler.app"
fi
