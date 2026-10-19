#!/usr/bin/env bash
# Runs the UI screenshot tests on the 6.9-inch simulator and drops the PNGs into asc/screenshots.
#   scripts/screenshots.sh <Scheme> [simulator-udid]
set -euo pipefail
scheme="$1"
sim="${2:-$(xcrun simctl list devices available | grep -E 'iPhone 1[6-9] Pro Max|iPhone 17 Pro Max' | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')}"
dest="${3:-asc/screenshots/6.9}"   # third argument puts the PNGs somewhere else, e.g. the iPad set
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
xcodegen generate >/dev/null
# XcodeGen only attaches the StoreKit configuration to the Run action; the paywall screenshot needs it under Test too.
scheme_file="$scheme.xcodeproj/xcshareddata/xcschemes/$scheme.xcscheme"
if ! sed -n '/<TestAction/,/<\/TestAction>/p' "$scheme_file" | grep -q StoreKitConfigurationFileReference; then
  python3 - "$scheme_file" "$scheme" <<'PY'
import sys, re
path, scheme = sys.argv[1], sys.argv[2]
s = open(path).read()
ref = f'      <StoreKitConfigurationFileReference\n         identifier = "../../{scheme}/StoreKit/Products.storekit">\n      </StoreKitConfigurationFileReference>\n'
s = re.sub(r'(<TestAction[^>]*>\n)', lambda m: m.group(1) + ref, s, count=1)
open(path, 'w').write(s)
PY
fi
out="$(mktemp -d)"
xcodebuild -project "$scheme.xcodeproj" -scheme "$scheme" -destination "id=$sim" -derivedDataPath "$out/dd" \
  -only-testing:"${scheme}UITests" -resultBundlePath "$out/ui.xcresult" test 2>&1 | grep -E "error:|Test Case .* (passed|failed)|TEST (SUCCEEDED|FAILED)" || true
xcrun xcresulttool export attachments --path "$out/ui.xcresult" --output-path "$out/shots" >/dev/null
python3 - "$out/shots" "$dest" <<'PY'
import json, shutil, pathlib, sys
shots = pathlib.Path(sys.argv[1]); dest = pathlib.Path(sys.argv[2]); dest.mkdir(parents=True, exist_ok=True)
for test in json.load(open(shots / "manifest.json")):
    for a in test.get("attachments", []):
        base = a["suggestedHumanReadableName"].split("_")[0].replace(".png", "")
        if not (base == "paywall" or (len(base) > 3 and base[:2].isdigit() and base[2] == "-")):
            continue  # failure diagnostics, not screenshots
        target = pathlib.Path("asc/screenshots/paywall.png") if base == "paywall" and str(dest).endswith("6.9") else dest / f"{base}.png"
        shutil.copy(shots / a["exportedFileName"], target); print(target)
PY
