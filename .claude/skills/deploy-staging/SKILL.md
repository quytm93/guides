---
name: deploy-staging
description: Build and ship the STAGING iOS build via the org's fastlane pipeline. Canonical path = ad-hoc build of a staging scheme (.stag bundle id, AdHoc profiles) → Firebase App Distribution (SnapLedger/SnapEdit). SReel interim = app-store build → TestFlight (no Firebase yet). Use when asked to deploy/ship staging, push a staging/beta/QA build, or run the staging lane (deploy_stg).
---

# deploy-staging

Ship the **staging** build. Claude drives fastlane lanes; pair with `signing-provisioning` for certs and
`deploy-production` for the prod counterpart.

> **The org norm: staging → Firebase App Distribution, ad-hoc build.** SnapLedger (`deploy_stg`) and
> SnapEdit both build a **separate staging scheme** with a `.stag` bundle id, sign it with **AdHoc**
> profiles, and ship it to **Firebase App Distribution** (not TestFlight). Production is the separate
> `app-store` → TestFlight path (see `deploy-production`). Use Form A below — it's the canonical shape.
>
> **SReel exception (current).** SReel has no Firebase project, no staging scheme/config, a single bundle
> id `com.silverai.sreel`, and its `deploy_all` calls a `deploy_stg` lane that **doesn't exist yet**. Until
> it gets a real staging env, the pragmatic interim is Form B (staging → TestFlight). You asked for
> TestFlight-for-now — that's Form B; Form A is what to grow into.

## Form A — staging → Firebase App Distribution (canonical, SnapLedger reference)
The real, working `deploy_stg` from SnapLedger (`SSMoney` / `com.silverai.smoney`). Note the differences
vs production: **separate staging scheme**, **`.stag` bundle id**, **`ad-hoc` export**, **AdHoc match
profiles for every target incl. extensions**, **Staging GoogleService plist**, **Firebase upload (no
`pilot`)**, **no `validate_application_info_plist`**.
```ruby
desc "Deploy Staging build to Firebase App Distribution"
lane :deploy_stg do
  sync_version_number
  old_build_number = get_build_number()
  next_build = next_build_number_from_snaplaunch          # same SnapLaunchOps counter, track=ios
  increment_build_number(build_number: next_build)

  gym(
    workspace: "<App>.xcworkspace", scheme: "<App>Staging", clean: true,
    output_directory: "./Builds", output_name: "<App>Staging.ipa",
    export_options: {
      method: "ad-hoc", manageAppVersionAndBuildNumber: false,
      provisioningProfiles: {                              # AdHoc for app + every extension
        "com.silverai.<app>.stag"                 => "match AdHoc com.silverai.<app>.stag",
        "com.silverai.<app>.ShareExtension"       => "match AdHoc com.silverai.<app>.ShareExtension",
        "com.silverai.<app>.WidgetExtension"      => "match AdHoc com.silverai.<app>.WidgetExtension"
      }
    }
  )
  increment_build_number(build_number: old_build_number)   # reset so the bump isn't committed

  upload_symbols_to_crashlytics(
    gsp_path: "./<App>/AppConfig/Staging/GoogleService-Info.plist",
    dsym_path: "./Builds/<App>Staging.app.dSYM.zip", debug: false
  )
  firebase_app_distribution(
    app: "<firebase-ios-app-id>", groups: "Beta",
    ipa_path: "./Builds/<App>Staging.ipa",
    release_notes_file: "./fastlane/release-note",
    service_credentials_file: ENV["FIREBASE_SERVICE_KEY_PATH"]
  )
end
```
Prerequisites (use `build-configurations` / `update-bundle-id` skills): a staging scheme + `.stag` bundle
id with `match AdHoc` profiles synced, a Firebase iOS app + staging `GoogleService-Info.plist`, the
`firebase_app_distribution` plugin (Pluginfile), and `FIREBASE_SERVICE_KEY_PATH` set in env.

## Form B — staging → TestFlight (SReel interim, what you asked for now)
Same as `deploy-production` but treated as staging. Add this `deploy_stg` to SReel's Fastfile so its
`deploy_all` (= `deploy_stg` + `deploy_testflight`) stops crashing:
```ruby
desc "Deploy Staging build to TestFlight (interim — SReel has no Firebase/staging env yet)"
lane :deploy_stg do
  sync_version_number
  old_build = get_build_number()
  increment_build_number(build_number: next_build_number_from_snaplaunch)
  gym(
    workspace: "SReel.xcworkspace", scheme: "SReel", clean: true,
    output_directory: "./Builds", output_name: "SReel-Staging.ipa",
    export_options: { method: "app-store", manageAppVersionAndBuildNumber: false,
      provisioningProfiles: { "com.silverai.sreel" => "match AppStore com.silverai.sreel" } }
  )
  increment_build_number(build_number: old_build)
  pilot(ipa: "./Builds/SReel-Staging.ipa", skip_waiting_for_build_processing: true,
        api_key: create_appstore_api_key())
end
```
Caveat: with one bundle id + one TestFlight app, staging and prod builds land in the **same** TestFlight.
Use a distinct internal tester group to tell them apart, and consider a separate SnapLaunchOps
`track=ios-staging` so they don't share a build-number counter. This is interim — migrate to Form A.

## Procedure
0. **Fingerprint the fastlane setup** — decide Form A vs B from what actually exists:
   ```bash
   bash .claude/skills/signing-provisioning/scripts/detect-fastlane.sh /path/to/project-root
   ```
   - A staging lane with `dest=Firebase` (e.g. SnapLedger `deploy_stg` → `SSMoneyStaging`/ad-hoc) → **Form A**, run it.
   - No staging lane / no Firebase (e.g. SReel) → **Form B**: add the interim `deploy_stg` below, then run.
   Use the scheme/bundle ids the detector reports; don't hardcode.
1. Pre-flight: clean tree, right branch, `cat version`, `bundle exec fastlane list` (confirm a staging lane exists).
2. Sync signing if needed (`bundle exec fastlane sync_certs`; see `signing-provisioning` — keep `force_legacy_encryption: true` for SReel).
3. **Confirm with the user** (outward-facing), then run the staging lane in the background, polling the log.
4. Report: build number, version, destination result (Firebase release link for Form A, or TestFlight for Form B), dSYM upload.

## Rules
- Confirm before running — a TestFlight/Firebase build is visible to testers.
- Never commit the bumped build number; preserve the reset.
- Treat `SNAPLAUNCH_API_KEY`, `.p8`, and GoogleService plists as secrets (gitignore them).
- Don't silently make staging and production fight over the same build-number track if separation matters — flag it.
