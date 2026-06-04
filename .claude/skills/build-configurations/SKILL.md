---
name: build-configurations
description: Set up STAGING/PRODUCTION (and DEV) environment separation in an iOS project — via EITHER multiple build configurations on one target (SnapEdit style) OR separate app targets per env (SnapLedger style). Wires per-env bundle id, app name, API base URL, GoogleService plist, and a scheme per env. Use when asked to set up build environments, add a staging/prod flavor, create per-env schemes, or split debug/release into flavors.
---

# build-configurations

Set up per-environment builds (STAGING / PRODUCTION, optionally DEV) so each ships with its own bundle
id, display name, endpoints, Firebase/GoogleService plist, and a dedicated **shared scheme** the deploy
lanes target. **There are two valid architectures — pick one deliberately; they're not mixable casually.**

## The two patterns (both used in this org)

### Pattern A — Multi-config, single target (SnapEdit)
**One app target**, multiple build configurations. SnapEdit has 4: `Staging-Debug`, `Staging-Release`,
`Production-Debug`, `Production-Release`. Two schemes (`SnapEdit-Staging`, `SnapEdit-Production`) each
select the matching config pair for Run/Archive. Per-env values come from **build settings / xcconfig
keyed per config** (bundle id `com.sfun.snapedit.stag` vs `com.sfun.snapedit`, etc.).
- **Pros:** one target to maintain; files/build-phases/capabilities defined once; less duplication.
- **Cons:** per-env resources (e.g. `GoogleService-Info.plist`) need conditional handling (a build-phase
  script that copies the right plist per config, or `#if`); easy to forget a setting on one config.
- **Best when:** envs differ mostly in *settings* (endpoints, ids, flags), not in code/files/capabilities.

### Pattern B — Separate target per env (SnapLedger)
**One app target per environment.** SnapLedger has `SSMoney` (prod) + `SSMoneyStaging` (staging), sharing
the 3 extension targets, with only Debug/Release configs. Each target has its own scheme (`SSMoney`,
`SSMoneyStaging`), its own bundle id (`com.silverai.smoney` vs `.stag`), and its own membership of files
like the env's `GoogleService-Info.plist`.
- **Pros:** clean separation — each env can have different files, capabilities, entitlements, icons,
  plists via target membership; no per-config conditionals.
- **Cons:** two targets to keep in sync (a new file/build-phase must be added to both); more duplication.
- **Best when:** envs differ in *files/capabilities/resources* (different Firebase apps, entitlements, icons).

> **Don't conflate them.** Earlier docs wrongly said SnapEdit and SnapLedger share a pattern — they don't.
> SnapEdit = Pattern A (configs), SnapLedger = Pattern B (targets). Match the project you're editing.
> Either way: **drive settings through `.xcconfig`, not raw pbxproj edits** — both patterns touch many
> fragile pbxproj objects (XCBuildConfiguration / XCConfigurationList / PBXNativeTarget).

## Step 0 — Detect the existing pattern FIRST (don't guess, don't impose)
Before touching anything, classify the project so you extend its existing style instead of introducing a
conflicting one. Run the bundled detector (it sits next to this SKILL.md, in `scripts/`):
```bash
bash <this-skill-dir>/scripts/detect-env-pattern.sh path/to/App.xcodeproj   # project arg optional — auto-finds
# e.g. from Workshop:
bash .claude/skills/build-configurations/scripts/detect-env-pattern.sh /path/to/App.xcodeproj
```
It prints the app targets, configs, shared schemes, and a `VERDICT`:

| Verdict | Meaning | Do |
|---|---|---|
| `PATTERN_A` | one app target + env-prefixed configs (e.g. `Staging-Release`) | Follow **Pattern A** — add configs/xcconfig, don't add a target. |
| `PATTERN_B` | ≥2 app targets named per env (e.g. `…Staging`) | Follow **Pattern B** — duplicate the app target, don't add configs. |
| `NONE` | one target, only Debug/Release, single scheme (greenfield, e.g. SReel) | **Ask the user** which pattern: A if envs differ by *settings*, B if by *files/capabilities/resources*. |
| `MIXED` | both signals present | Stop and inspect manually; report before changing — never add a third style. |

How it decides (so you can sanity-check by hand): app targets = `PBXNativeTarget` with
`productType com.apple.product-type.application`; env configs = `XCBuildConfiguration` names beyond
`Debug`/`Release` matching staging/prod/dev; ≥2 env-named app targets ⇒ B, else env configs ⇒ A, else NONE.
Verified correct on SnapEdit (A), SnapLedger (B), SReel (NONE).

## Recommended tooling (either pattern)
1. **xcconfig + Xcode** — best for an existing native project.
2. **`xcodeproj` Ruby gem** — script config/target creation reproducibly (`gem install xcodeproj`).
3. **XcodeGen / Tuist** — declare configs *and* targets in `project.yml`/manifest; best for reproducibility.

## Design first (confirm with user)
- **Which pattern** (A configs vs B targets) — decide based on whether envs differ by settings or by files/capabilities.
- Environment list: usually `Staging` + `Production` (× Debug/Release for Pattern A).
- Per-env values: bundle id (`.stag` suffix), display name, API base URL, feature flags,
  Firebase/GoogleService plist, app icon variant.

---
# Pattern A procedure (multi-config, single target)

## A1. Create xcconfig files
```
Config/
  Shared.xcconfig
  DEV.xcconfig
  STAGING.xcconfig
  PROD.xcconfig
```
`DEV.xcconfig` example:
```
#include "Shared.xcconfig"
APP_ENV               = dev
PRODUCT_BUNDLE_IDENTIFIER = com.company.app.dev
PRODUCT_NAME          = $(TARGET_NAME)
DISPLAY_NAME          = MyApp DEV
API_BASE_URL          = https:/$()/dev.api.company.com   // $() escapes the // 
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) DEV
```
(STAGING/PROD analogous. `$()` is the xcconfig trick to keep `//` from being read as a comment in URLs.)

### A2. Add the build configurations
Duplicate `Debug`/`Release` into env-prefixed names (`Staging-Debug`, `Staging-Release`,
`Production-Debug`, `Production-Release` — SnapEdit's exact scheme) at the **project** level
(Project ▸ Info ▸ Configurations ▸ +), then assign each configuration's xcconfig file (Based on
Configuration File). Keep a debug- and release-flavored variant per env (CI needs both).
If scripting with the `xcodeproj` gem, add `XCBuildConfiguration` objects to both the project's and
the target's `XCConfigurationList` and set `baseConfigurationReference`.

### A3. Surface env values to Info.plist / code
In Info.plist add keys referencing the build settings so code can read them:
```
APP_ENV          = $(APP_ENV)
API_BASE_URL     = $(API_BASE_URL)
CFBundleDisplayName = $(DISPLAY_NAME)
```
Read in Swift:
```swift
enum AppEnv {
    static let apiBaseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as! String
}
```
Or gate code with the compilation condition:
```swift
#if DEV
let baseURL = "https://dev.api.company.com"
#endif
```

### A4. Create a scheme per environment
For each env duplicate the target's scheme → name it `App-Staging` / `App-Production`.
Per scheme set the configuration used for Run / Test / Profile / **Archive** (Edit Scheme ▸ each action ▸
Build Configuration → the matching `Staging-*` / `Production-*` config). **Mark schemes "Shared"** so
they're committed to `xcshareddata/xcschemes/` and CI/fastlane can see them.

### A5. Per-env resources (the multi-config gotcha)
Files like `GoogleService-Info.plist` can't use target membership to differ per env (one target). Options:
- A **Run Script build phase** that copies the right plist based on `$(CONFIGURATION)` into the bundle, or
- store both as `AppConfig/Staging/…` & `AppConfig/Production/…` and copy per config (SnapEdit/SnapLedger
  fastlane already references these `AppConfig/<Env>/GoogleService-Info.plist` paths).

### A6. Keep extensions in sync
Each extension target needs the **same 4 configs** and a suffixed bundle id per env (see `update-bundle-id`).
Don't leave an extension on plain Debug/Release.

---
# Pattern B procedure (separate target per env — SnapLedger)

### B1. Duplicate the app target
In Xcode: select the app target ▸ right-click ▸ **Duplicate**, rename the copy `AppStaging`
(SnapLedger: `SSMoneyStaging`). This clones build settings, build phases, and file membership.
Prefer the `xcodeproj` gem or XcodeGen/Tuist to do this reproducibly rather than by hand.

### B2. Differentiate the new target
- Bundle id → `.stag` (`com.silverai.smoney.stag`).
- Its own `Info.plist` / display name if needed.
- **File membership** for env-specific resources: the staging target includes
  `AppConfig/Staging/GoogleService-Info.plist`; prod includes `AppConfig/Production/…`. This is the
  main advantage — no per-config copy script needed.
- Add `STAGING` to `SWIFT_ACTIVE_COMPILATION_CONDITIONS` on the staging target for `#if STAGING` gating.

### B3. Shared extensions
Extensions (Action/Share/Widget) are usually **shared across both targets** (SnapLedger does this) — add
each extension to both app targets' "Embed App Extensions" / dependencies. A new file added to an
extension is picked up by both envs automatically.

### B4. Scheme per target
Each target gets its own auto-created scheme (`SSMoney`, `SSMoneyStaging`). **Mark both Shared.** The
deploy lanes target these scheme names directly (`gym(scheme: "SSMoneyStaging")`).

---
## Verify (either pattern)
```bash
xcodebuild -list                 # confirm configs/targets + shared schemes appear
xcodebuild -scheme "<StagingScheme>" -showBuildSettings | grep -E "PRODUCT_BUNDLE_IDENTIFIER|API_BASE_URL|PRODUCT_NAME|SWIFT_ACTIVE_COMPILATION_CONDITIONS"
```
Then build each scheme via the `xcode-build` skill, and confirm bundle ids/plists differ as intended.

## Rules
- **Match the project's existing pattern** (SnapEdit=A configs, SnapLedger=B targets) — don't introduce
  the other style into a project that already chose one.
- Back up `project.pbxproj` before any scripted/manual pbxproj change.
- Always mark new schemes **Shared**, or CI/fastlane won't find them.
- Keep the staging bundle id (`.stag`) and its `match AdHoc` profiles in sync (see `signing-provisioning`).
- List every config/target/scheme/xcconfig you created and the per-env values set.
