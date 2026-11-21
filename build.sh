#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
app="$PWD/outputs/Акцент.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" work/module-cache
if [[ ! -f work/AppIcon.icns || Tools/Icon.swift -nt work/AppIcon.icns ]]; then
  swift Tools/Icon.swift work/AppIcon.iconset
  iconutil -c icns work/AppIcon.iconset -o work/AppIcon.icns
fi
swiftc -swift-version 5 -O -target arm64-apple-macos14.0 \
  -module-cache-path "$PWD/work/module-cache" \
  Sources/AccentPointer/*.swift -o "$app/Contents/MacOS/Accent" \
  -framework AppKit -framework SwiftUI -framework Combine -framework Carbon -framework QuartzCore
cp Info.plist "$app/Contents/Info.plist"
if [[ -f work/AppIcon.icns ]]; then cp work/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"; fi
codesign --force --sign - --identifier ru.ninesquares.Accent \
  --requirements '=designated => identifier "ru.ninesquares.Accent"' "$app"
"$app/Contents/MacOS/Accent" --self-test
echo "Готово: $app"
