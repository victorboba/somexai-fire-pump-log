#!/usr/bin/env bash
# Build a complete, App-Store-legal AppIcon.appiconset: all three appearances iOS asks for,
# the Contents.json that declares them, and a validation pass through Xcode's own asset compiler.
#
#   scripts/make-appicon.sh <AppTarget> <glyph> <bg> <bg2> <badge>
#
#   scripts/make-appicon.sh CraneLog crane-hook 1F3A5F 3E6FA8 F2A63B
#
# Writes <AppTarget>/Assets.xcassets/AppIcon.appiconset/{AppIcon,AppIcon-Dark,AppIcon-Tinted}.png
# plus Contents.json, then runs actool and fails loudly if anything is wrong.
set -euo pipefail

if [ $# -lt 5 ]; then sed -n '2,12p' "$0"; exit 1; fi
target="$1"; glyph="$2"; bg="$3"; bg2="$4"; badge="$5"
root="$(cd "$(dirname "$0")/.." && pwd)"
set="$root/$target/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$set"

swift "$root/scripts/make-icon.swift" --out "$set/AppIcon.png"        --glyph "$glyph" --bg "$bg" --bg2 "$bg2" --badge "$badge" --appearance light
swift "$root/scripts/make-icon.swift" --out "$set/AppIcon-Dark.png"   --glyph "$glyph" --bg "$bg" --bg2 "$bg2" --badge "$badge" --appearance dark
swift "$root/scripts/make-icon.swift" --out "$set/AppIcon-Tinted.png" --glyph "$glyph" --bg "$bg" --bg2 "$bg2" --badge "$badge" --appearance tinted

cat > "$set/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "filename" : "AppIcon-Dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ],
      "filename" : "AppIcon-Tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

fail=0
# The App Store icon is the strict one: exactly 1024x1024 and no alpha channel, or the upload is
# rejected after the build has already been processed, which costs an hour.
w=$(sips -g pixelWidth "$set/AppIcon.png" | awk '/pixelWidth/{print $2}')
h=$(sips -g pixelHeight "$set/AppIcon.png" | awk '/pixelHeight/{print $2}')
a=$(sips -g hasAlpha "$set/AppIcon.png" | awk '/hasAlpha/{print $2}')
[ "$w" = 1024 ] && [ "$h" = 1024 ] || { echo "FAIL: AppIcon.png is ${w}x${h}, must be 1024x1024"; fail=1; }
[ "$a" = "no" ] || { echo "FAIL: AppIcon.png has an alpha channel; the App Store rejects that"; fail=1; }
# The two on-device appearances are the opposite: iOS composites them over its own ground, so they
# must keep their transparency.
for v in Dark Tinted; do
  a=$(sips -g hasAlpha "$set/AppIcon-$v.png" | awk '/hasAlpha/{print $2}')
  [ "$a" = "yes" ] || { echo "FAIL: AppIcon-$v.png has no alpha; iOS needs to see through it"; fail=1; }
done

# Xcode's own compiler is the last word on whether the catalog is well formed.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
if ! xcrun actool "$root/$target/Assets.xcassets" --compile "$tmp" --platform iphoneos \
      --minimum-deployment-target 17.0 --app-icon AppIcon \
      --output-partial-info-plist "$tmp/partial.plist" --errors > "$tmp/log" 2>&1; then
  echo "FAIL: actool rejected the catalog"; cat "$tmp/log"; fail=1
elif grep -q "com.apple.actool.errors" "$tmp/log"; then
  echo "FAIL: actool reported errors"; sed -n '/actool.errors/,/<\/array>/p' "$tmp/log"; fail=1
fi

[ "$fail" = 0 ] || exit 1
echo "OK  $target: light (opaque) + dark + tinted, 1024x1024, actool clean"
