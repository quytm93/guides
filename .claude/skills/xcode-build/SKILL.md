---
name: xcode-build
description: Build, test, and run an iOS app from the command line via xcodebuild and xcrun simctl, then parse and surface errors concisely. Use when asked to build the app, run tests, launch the simulator, or check that iOS changes compile.
---

# xcode-build

Drive an Xcode iOS project from the CLI. Targets Xcode 26 toolchain.

## Discover the project first
Run from the project root:
```bash
ls *.xcworkspace *.xcodeproj 2>/dev/null
xcodebuild -list -json 2>/dev/null   # or add -workspace/-project if multiple
```
- If a `.xcworkspace` exists (CocoaPods / SPM workspace), use `-workspace Name.xcworkspace`.
- Otherwise use `-project Name.xcodeproj`.
- Read the scheme from `-list`. If multiple schemes, ask which.

## Pick a simulator destination
```bash
xcrun simctl list devices available
```
Prefer a generic destination so it works on any machine:
`-destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'`
(Fall back to a booted device name from the list above if that model isn't installed.)

## Build
```bash
xcodebuild build \
  -scheme "<Scheme>" \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -configuration Debug \
  -quiet | tee /tmp/xcodebuild.log
```
- Add `clean` before `build` only if the user asks or caching looks stale.
- If `xcbeautify` or `xcpretty` is installed, pipe through it for readable output; otherwise grep the log.

## Test
```bash
xcodebuild test \
  -scheme "<Scheme>" \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  | tee /tmp/xcodebuild-test.log
```

## Run on simulator
```bash
# Build, then boot + install + launch:
xcrun simctl boot "iPhone 16" 2>/dev/null; open -a Simulator
# Find the built .app:
APP=$(xcodebuild -showBuildSettings -scheme "<Scheme>" | awk '/TARGET_BUILD_DIR/{d=$3}/FULL_PRODUCT_NAME/{p=$3}END{print d"/"p}')
xcrun simctl install booted "$APP"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl launch booted "$BUNDLE_ID"
```

## Parsing results — report concisely
- **Success**: report `BUILD SUCCEEDED` / test pass count, nothing more.
- **Failure**: extract only the relevant lines:
  ```bash
  grep -nE "error:|warning:|FAILED|Testing failed|BUILD FAILED" /tmp/xcodebuild.log | head -40
  ```
  Surface the actual `error:` lines with `file:line`, not the whole log. Then propose a fix.
- Common gotchas to recognize: missing signing for device builds (build for *simulator* unless asked), wrong scheme, unavailable simulator OS (use `OS=latest`), provisioning errors (don't try to fix signing unless asked).

## Rules
- Never modify signing/provisioning or push to a device without explicit instruction.
- Long builds: run in background and poll the log rather than blocking.
- Always state the exact destination/scheme used so results are reproducible.
