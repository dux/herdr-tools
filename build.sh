#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

# Stamp .version from the commit count before reading it below.
hammer version >/dev/null

# UNIVERSAL=1 builds a single arm64 + x86_64 binary for distribution.
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  swift build -c release --arch arm64 --arch x86_64
  binary="$PWD/.build/apple/Products/Release/HerdrTools"
else
  swift build -c release
  binary="$PWD/.build/release/HerdrTools"
fi

app_path="$PWD/build/Herdr_Tools.app"
iconset_path="$PWD/build/HerdrTools.iconset"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$iconset_path"
for icon_size in 16 32 128 256 512; do
  sips -z "$icon_size" "$icon_size" Resources/HerdrToolsIcon.png --out "$iconset_path/icon_${icon_size}x${icon_size}.png" >/dev/null
  retina_size=$((icon_size * 2))
  sips -z "$retina_size" "$retina_size" Resources/HerdrToolsIcon.png --out "$iconset_path/icon_${icon_size}x${icon_size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset_path" -o "$app_path/Contents/Resources/HerdrTools.icns"
cp "$binary" "$app_path/Contents/MacOS/HerdrTools"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$(zsh tools/version.sh --short)" "$app_path/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$(zsh tools/version.sh --count)" "$app_path/Contents/Info.plist"
cp Resources/HerdrIcon.png "$app_path/Contents/Resources/HerdrIcon.png"
codesign --force --sign - --entitlements Resources/Entitlements.plist "$app_path"
print "Built $app_path"
