#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
./build.sh
archive="$PWD/outputs/Accent-0.1.0-macOS-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$PWD/outputs/Акцент.app" "$archive"
(
  cd outputs
  shasum -a 256 Accent-0.1.0-macOS-arm64.zip > SHA256SUMS.txt
)
echo "Архив: $archive"
