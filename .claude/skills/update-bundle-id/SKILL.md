---
name: update-bundle-id
description: Change an iOS app's bundle identifier (PRODUCT_BUNDLE_IDENTIFIER) safely and consistently across the app target, extensions, widgets, tests, and entitlements/Info.plist references. Use when asked to rename the bundle id, change the app identifier, or set up a new bundle id for a target.
---

# update-bundle-id

Change `PRODUCT_BUNDLE_IDENTIFIER` everywhere it must change, keeping extension/widget prefixes correct.

## 1. Inventory every bundle id
```bash
grep -rn "PRODUCT_BUNDLE_IDENTIFIER" *.xcodeproj/project.pbxproj
grep -rln "PRODUCT_BUNDLE_IDENTIFIER" . --include=*.xcconfig
```
Expect several, and they are **not all the same**. Typical pattern:
- App: `com.company.App`
- Widget extension: `com.company.App.Widget`
- Notification/Share extension: `com.company.App.<ext>`
- Tests: `com.company.AppTests` / `...UITests`

Map old → new preserving the **suffix hierarchy** (the part after the app id stays attached to the new app id).

## 2. Apply
- **xcconfig** if present — change the base there.
- Otherwise edit each `PRODUCT_BUNDLE_IDENTIFIER = ...;` line in `project.pbxproj`. Back up first:
  ```bash
  cp *.xcodeproj/project.pbxproj /tmp/project.pbxproj.bak
  ```
  Do **not** blind `replace_all` a single string — extensions have different ids. Change each occurrence to its correctly-suffixed new value.

## 3. Follow the references — these break silently
- **Entitlements** (`*.entitlements`): App Groups (`group.com.company.App`), Keychain sharing, associated domains, push environment — update any that embed the bundle id.
- **Info.plist**: URL schemes, `CFBundleIdentifier` (usually `$(PRODUCT_BUNDLE_IDENTIFIER)` — leave the variable), background modes config.
- **Code**: `grep -rn "com.company.App" --include=*.swift` for hardcoded ids (App Group names, UserDefaults suites, keychain access groups, notification category prefixes, Universal Links).
- **GoogleService-Info.plist / Firebase, RevenueCat, analytics** configs keyed by bundle id.

## 4. Signing / capabilities (flag, don't silently fix)
- A new bundle id needs a matching **App ID + provisioning profile** in the Apple Developer portal for device builds/distribution. Note this; don't attempt portal changes.
- App Group / iCloud container ids may need re-provisioning.

## 5. Verify
```bash
xcodebuild -list >/dev/null && echo "pbxproj parses OK"
```
Build via `xcode-build` (simulator build doesn't need signing — good first check). List every place you changed and every reference you updated.

## Rules
- Never collapse distinct extension ids into one.
- Surface signing/provisioning consequences; leave portal work to the user.
