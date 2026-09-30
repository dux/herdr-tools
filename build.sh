#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
swift build -c release
app_path="$PWD/build/Pastir.app"
iconset_path="$PWD/build/Pastir.iconset"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$iconset_path"
for icon_size in 16 32 128 256 512; do
  sips -z "$icon_size" "$icon_size" Resources/PastirIcon.png --out "$iconset_path/icon_${icon_size}x${icon_size}.png" >/dev/null
  retina_size=$((icon_size * 2))
  sips -z "$retina_size" "$retina_size" Resources/PastirIcon.png --out "$iconset_path/icon_${icon_size}x${icon_size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset_path" -o "$app_path/Contents/Resources/Pastir.icns"
cp .build/release/Pastir "$app_path/Contents/MacOS/Pastir"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
cp Resources/HerdrIcon.png "$app_path/Contents/Resources/HerdrIcon.png"
codesign --force --sign - --entitlements Resources/Entitlements.plist "$app_path"
print "Built $app_path"
