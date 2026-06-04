---
name: signing-provisioning
description: Inspect and configure iOS code signing & provisioning — automatic vs manual signing, DEVELOPMENT_TEAM / PROVISIONING_PROFILE_SPECIFIER / CODE_SIGN_IDENTITY build settings, and driving fastlane match/sigh to sync certs & profiles non-interactively. Use when asked about signing, certificates, provisioning profiles, "no profile found", team id, or preparing a signed archive/IPA.
---

# signing-provisioning

## What Claude can and cannot do here (read this first)
- **Cannot**: access private keys in your login keychain, generate/revoke certs by hand, or click through
  developer.apple.com. Signing crypto and portal state are off-limits to the model.
- **Can**: read & report current signing config; change signing build settings; and **drive `fastlane match`
  / `sigh`**, which create/fetch certs + profiles non-interactively using your App Store Connect API key.
  So the workflow is *orchestrate fastlane*, not do crypto.

## Org signing model (shared across SnapEdit & SReel)
All apps here use fastlane **match** with the **shared private cert repo** `sfunvn/ios-cert.git`
(`storage_mode("git")`) and **App Store Connect API-key** auth via a `create_appstore_api_key` private
lane (key id `Z265LALJR5`, issuer `d7fd38e1-84cb-466a-b7a5-342aaf78e0b3`, `AuthKey_Z265LALJR5.p8`).
Profiles are tagged `match AppStore <bundleid>` / `match AdHoc <bundleid>` / `match Development <bundleid>`.
Treat match as the source of truth — **don't** switch a match project to Xcode-automatic signing.

**Profile-type ↔ deploy-env convention (org-wide):**
- **Production** → `match AppStore` profiles, `app-store` export, TestFlight (`deploy-production`).
- **Staging** → `match AdHoc` profiles on the `.stag` bundle id, `ad-hoc` export, Firebase App Distribution (`deploy-staging`).
- The `appstore` match list **excludes** `.stag` ids; the `adhoc` + `development` lists **include** them
  (see SnapLedger/SnapEdit `sync_certs`). When syncing for a new staging id, add it to the adhoc/development match calls, not appstore.

Per-app specifics:
- **SnapEdit** — per-env bundle ids `com.sfun.snapedit` / `.stag` + 5 extensions, schemes `SnapEdit-Staging`/`-Production`. Each extension id needs its own profile.
- **SReel** — single bundle id `com.silverai.sreel`, no extensions, workspace `SReel.xcworkspace`, scheme `SReel`. ASC team `124777776`, dev-portal team `59M25NYVQV`. `sync_certs` syncs **development + appstore + adhoc** for the one id.

Match invocation gotchas seen in these repos:
- **`force_legacy_encryption: true`** (SReel) — the cert repo uses OpenSSL legacy encryption; omit it and decryption fails on newer OpenSSL. Keep it when running match for SReel.
- Matchfile sets **`clone_branch_directly(true)`** and **`force_for_new_devices(true)`** — adding a new device + non-readonly run auto-regenerates adhoc/dev profiles.
- `sync_certs` lane defaults to **`readonly: true`**; it only creates the API key (and can write) when called with `readonly:false`.

## 0. Fingerprint the fastlane setup FIRST
Don't assume — read the project's actual config with the bundled detector (next to this SKILL.md):
```bash
bash <this-skill-dir>/scripts/detect-fastlane.sh /path/to/project-root
# from Workshop: bash .claude/skills/signing-provisioning/scripts/detect-fastlane.sh /path/to/project-root
```
It reports app identity & teams (Appfile), match config (git_url, `force_legacy_encryption`, storage), the
lane list, match types + bundle ids, a per-lane scheme/method/destination table, the build-number source,
and a **committed-secrets check** (flags a tracked `.env` / `.p8`). Use its output to drive the steps below
instead of guessing bundle ids or whether match is in use. Same script powers `deploy-staging`/`deploy-production`.

## 1. Diagnose current state
```bash
# Signing settings per target/config:
xcodebuild -scheme "<Scheme>" -showBuildSettings | grep -E \
  "CODE_SIGN_STYLE|DEVELOPMENT_TEAM|PROVISIONING_PROFILE_SPECIFIER|CODE_SIGN_IDENTITY|PRODUCT_BUNDLE_IDENTIFIER"

# Installed signing certs:
security find-identity -v -p codesigning

# Installed provisioning profiles:
ls ~/Library/MobileDevice/Provisioning\ Profiles/ 2>/dev/null
# Decode one to inspect bundle id / expiry / devices:
security cms -D -i "<file>.mobileprovision" 2>/dev/null | plutil -p -
```
Report: signing style (Automatic/Manual), team id, which profile maps to which bundle id, expiry.

## 2A. Manual signing via match (the SnapEdit path — preferred)
1. Ensure API key + Matchfile present (`fastlane/AuthKey_*.p8`, `git_url` in `Matchfile`).
2. Sync certs/profiles (readonly on dev machines/CI, non-readonly only when adding new ones):
   ```bash
   bundle exec fastlane match appstore --readonly       # or: adhoc / development
   ```
   Or call the project's lane (SnapEdit has `sync_certs` / `sync_certs_ci`):
   ```bash
   bundle exec fastlane sync_certs_ci
   ```
3. Build/archive — match has already set `provisioningProfiles` for `gym`. Use the env lane (`gym(scheme: "SnapEdit-Production", ...)`).
4. New device for AdHoc: register it (`fastlane/devices`) then re-run match **non-readonly** with
   `force_for_new_devices: true` to regenerate the profile.

## 2B. Automatic signing (simpler projects only)
Set per target:
```
CODE_SIGN_STYLE = Automatic
DEVELOPMENT_TEAM = <TEAMID>
```
Xcode/`xcodebuild -allowProvisioningUpdates` will fetch profiles. Don't use on a match-managed project.

## 3. Manual signing build settings (when not using automatic)
```
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM = <TEAMID>
CODE_SIGN_IDENTITY = Apple Distribution        # or Apple Development
PROVISIONING_PROFILE_SPECIFIER = match AppStore com.sfun.snapedit
```
Each target/extension needs its own matching profile specifier per its bundle id.

## 4. Common errors → fix
- *"No profile for team … matching … found"* → run match for that bundle id / build type; confirm bundle id matches the profile tag.
- *"doesn't include signing certificate"* → cert missing from keychain; `fastlane match` (non-readonly) to install, or import from the cert repo.
- *Profile expired* → re-run match non-readonly to regenerate.
- *Extension fails but app passes* → an extension's bundle id has no profile; sync all bundle ids.
- Simulator builds need **no** signing — if only device/archive fails, it's purely a signing issue.

## Rules
- Never switch a match-managed project to automatic signing without explicit ask.
- Never commit `.p8` keys, certs, or profiles to a public repo; treat `AuthKey_*.p8` as a secret.
- Don't attempt portal actions (registering App IDs, revoking certs) — surface what the user must do there.
- Prefer `--readonly` match locally; only run non-readonly when intentionally adding certs/devices.
