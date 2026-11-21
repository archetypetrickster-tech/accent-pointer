#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
./build.sh
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
archive="$PWD/outputs/Accent-$version-macOS-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$PWD/outputs/Акцент.app" "$archive"
(
  cd outputs
  shasum -a 256 "Accent-$version-macOS-arm64.zip" > SHA256SUMS.txt
)
echo "Архив: $archive"
