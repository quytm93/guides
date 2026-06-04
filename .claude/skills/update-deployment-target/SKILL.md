---
name: update-deployment-target
description: Change an iOS app's minimum deployment target (IPHONEOS_DEPLOYMENT_TARGET) safely across the Xcode project, and flag APIs that the new floor allows or forbids. Use when asked to raise/lower the minimum iOS version, change the deployment target, or "support iOS X+".
---

# update-deployment-target

Change `IPHONEOS_DEPLOYMENT_TARGET` consistently and verify the build still passes.

## 1. Find current value
```bash
grep -rn "IPHONEOS_DEPLOYMENT_TARGET" *.xcodeproj/project.pbxproj
```
It usually appears multiple times: per-configuration (Debug/Release) and possibly per-target (app, tests, extensions, widgets). Note them all. Also check any `.xcconfig` files (`grep -rn IPHONEOS_DEPLOYMENT_TARGET . --include=*.xcconfig`) and SPM `Package.swift` `platforms:`.

## 2. Apply the change
Set **every** occurrence to the new value (keep app + extensions consistent unless the user wants otherwise). Prefer one of:

- **xcconfig (best):** if the project uses `.xcconfig`, change it there — single source of truth.
- **pbxproj edit:** if values live in `project.pbxproj`, replace each line. Match exactly including the trailing semicolon, e.g.:
  ```
  IPHONEOS_DEPLOYMENT_TARGET = 16.0;  →  IPHONEOS_DEPLOYMENT_TARGET = 17.0;
  ```
  Use Edit with `replace_all` only after confirming all occurrences should change to the same value. **Back up first:** the pbxproj is fragile.
  ```bash
  cp *.xcodeproj/project.pbxproj /tmp/project.pbxproj.bak
  ```
- **SPM:** update `platforms: [.iOS(.v17)]` in `Package.swift` to match.

## 3. Verify integrity
```bash
xcodebuild -list >/dev/null && echo "pbxproj parses OK"   # fails loudly if you corrupted it
```
Then build via the `xcode-build` skill.

## 4. Flag API implications
- **Raising** the floor (e.g. 16 → 17): note newly-allowed APIs the codebase can now adopt and `if #available` / `@available` guards that become dead and can be removed (`@Observable`, SwiftData, `.scrollPosition`, etc. become unconditional at 17).
- **Lowering** the floor: search for APIs that won't compile/run below the new minimum and wrap them in `if #available(iOS X, *)`. Build will surface most; call them out.

## Rules
- Keep app target and all extensions/widgets in sync unless told otherwise.
- Don't silently drop a target's value — list every place you changed.
- Always confirm the build passes before declaring done.
