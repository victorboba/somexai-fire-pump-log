#!/usr/bin/env bash
# Build and test an app from this template, from the terminal, without filling the system disk.
#
#   scripts/ci.sh <Scheme> [simulator-name]
#   scripts/ci.sh CraneLog SomexSim1
#
# Two things this gets right that a bare xcodebuild does not:
#   * DerivedData goes under build/ (or $DERIVED_DATA_ROOT), so it can live on a roomy volume.
#   * Each concurrent build gets its own simulator. Two xcodebuild runs pointed at the same device
#     fight over it and fail in ways that look like test failures.
set -euo pipefail

scheme="${1:?usage: ci.sh <Scheme> [simulator-name]}"
sim="${2:-SomexSim1}"
derived="${DERIVED_DATA_ROOT:-$PWD/build/DerivedData}/$scheme"

# Create the simulator if it is not there, so a fresh checkout can build unattended.
if ! xcrun simctl list devices | grep -q "$sim ("; then
  xcrun simctl create "$sim" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max \
    com.apple.CoreSimulator.SimRuntime.iOS-26-2 >/dev/null
fi

dest="platform=iOS Simulator,name=$sim"
log="$derived/last.log"
mkdir -p "$derived"

run() {
  local action="$1"
  echo "==> xcodebuild $action  ($scheme on $sim)"
  # Clear the bundle immediately before the run, not once at the top: xcodebuild refuses to start
  # if one already exists, and a stray concurrent run can recreate it in between.
  rm -rf "$derived/$action.xcresult"
  if xcodebuild -scheme "$scheme" -destination "$dest" -derivedDataPath "$derived" \
       -resultBundlePath "$derived/$action.xcresult" "$action" > "$log" 2>&1; then
    echo "    $action OK"
  else
    echo "    $action FAILED — first errors:"
    grep -E "error:|XCTAssert|failed -|Falling back" "$log" | head -25
    echo "    full log: $log"
    return 1
  fi
}

run build
run test
# The count is worth printing: a suite that silently runs zero tests looks identical to a pass.
grep -oE "Executed [0-9]+ tests?, with [0-9]+ failures?" "$log" | tail -2 || true
echo "ALL GREEN  $scheme"
