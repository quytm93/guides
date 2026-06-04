---
name: update-app-name
description: Change an iOS app's name — distinguishing the home-screen display name (CFBundleDisplayName) from the product/binary name that becomes the .app and .ipa filename (PRODUCT_NAME). Use when asked to rename the app, change the display name, change the IPA/product name, or set a per-environment app name.
---

# update-app-name

There are **two different "names"** — clarify which the user means (often both):

| Name | Where | Controls |
|---|---|---|
| **Display name** | `CFBundleDisplayName` (Info.plist) | The label under the icon on the home screen / Settings. Can have spaces/emoji, be localized, differ per env. |
| **Product name** | `PRODUCT_NAME` (build setting) | The `.app` bundle name and therefore the **`.ipa` filename** and `CFBundleName`. No spaces ideally. |

The IPA filename comes from the **scheme/archive** (`gym`/`xcodebuild` output) which derives from `PRODUCT_NAME`. To rename the runnable IPA, change `PRODUCT_NAME` (or set `gym(output_name:)` in fastlane).

## Procedure

### Display name (home screen)
1. Find it:
   ```bash
   grep -rn "CFBundleDisplayName" .   # Info.plist(s)
   ```
2. If absent, add the key to Info.plist. Prefer driving it from a build setting so it can vary per env:
   - Info.plist: `CFBundleDisplayName = $(DISPLAY_NAME)`
   - set `DISPLAY_NAME` in the per-env `.xcconfig` (see `build-configurations`), e.g. `MyApp`, `MyApp DEV`.
3. To **localize** the display name: add `CFBundleDisplayName` to `InfoPlist.strings` (or the App Name entry in the String Catalog) per language.

### Product name (IPA / binary)
1. Find it:
   ```bash
   xcodebuild -scheme "<Scheme>" -showBuildSettings | grep -E "PRODUCT_NAME|FULL_PRODUCT_NAME"
   grep -rn "PRODUCT_NAME" *.xcodeproj/project.pbxproj
   ```
2. Change `PRODUCT_NAME` (per config, or in xcconfig). Back up pbxproj first if editing it directly:
   ```bash
   cp *.xcodeproj/project.pbxproj /tmp/project.pbxproj.bak
   ```
3. If the IPA name is set in fastlane, update there instead/also:
   ```ruby
   gym(scheme: "App-Prod", output_name: "MyApp-Prod")
   ```

## Things that ride along — check them
- Renaming `PRODUCT_NAME` does **not** rename the Xcode target, scheme, or source folder. Decide whether the user wants a cosmetic name change (just settings) or a full project rename (target/scheme/group/dir — much bigger, error-prone; do only if asked).
- Hardcoded references to the old name in code/scripts/CI: `grep -rn "OldName" --include=*.swift --include=*.sh --include=Fastfile`.
- App Store Connect display name is managed in the portal, not the project — flag, don't attempt.

## Verify
```bash
xcodebuild -scheme "<Scheme>" -showBuildSettings | grep -E "PRODUCT_NAME|DISPLAY_NAME"
```
Build via `xcode-build`; report both names and where each is set.

## Rules
- Always state which name(s) you changed (display vs product) and the resulting IPA filename.
- Don't do a full target/scheme rename unless explicitly asked.
