---
name: deploy-production
description: Build and ship the PRODUCTION iOS build to TestFlight via the org's fastlane pipeline — version from a version file, build number from the SnapLaunchOps API, app-store gym archive, pilot upload, dSYM to Crashlytics. Use when asked to deploy/release production, ship a production build, cut a release, or push prod to TestFlight. For the staging build use deploy-staging.
---

# deploy-production

Orchestrate the org's fastlane release pipeline. Claude drives fastlane lanes; it does not sign or
upload by hand. Pair with the `signing-provisioning` skill for cert/profile prep.

> **Lane name vs skill name.** This skill is the *production* deploy. In **SReel** the production lane is
> literally named `deploy_testflight` (named for its destination, not its env) — invoke that. In **SnapEdit**
> it's `deploy_production`. Both export `app-store` and upload to TestFlight via `pilot`. For the staging
> build, use the **deploy-staging** skill.

## Pipeline shape (as implemented in SReel `deploy_testflight`)
1. **Version** — `sync_version_number` reads the repo `version` file (`cat ../version`) and writes it into
   the xcodeproj (`increment_version_number_in_xcodeproj`). Marketing version is file-driven, not manual.
2. **Build number** — fetched from **SnapLaunchOps**, an external atomic counter:
   `POST https://snaplaunchops.vercel.app/api/buildnumber?projectId=<id>&track=ios` with header
   `X-API-Key: $SNAPLAUNCH_API_KEY`, returns `{ track, buildNumber, previous }`. Set via
   `increment_build_number`. **The bump is then reset** to the old value after archiving so the inflated
   build number is never committed back to the repo.
3. **Archive** — `gym(workspace: "<App>.xcworkspace", scheme: "<Scheme>", export method app-store,`
   `manageAppVersionAndBuildNumber: false, provisioningProfiles: { "<bundleid>" => "match AppStore <bundleid>" })`
   → `./Builds/<App>.ipa`.
4. **Validate** — `validate_application_info_plist` asserts the built IPA's `CFBundleDisplayName` /
   `CFBundleName` / `CFBundleIdentifier` match expected values; raises otherwise (catches wrong-config archives).
5. **Upload** — `pilot(ipa:, skip_waiting_for_build_processing: true, api_key:)` → TestFlight.
6. **Symbols** — `upload_symbols_to_crashlytics(gsp_path: <Production GoogleService-Info.plist>, dsym_path: "./Builds/<App>.app.dSYM.zip")`.

`deploy_all = deploy_stg + deploy_testflight` (staging→Firebase, then prod→TestFlight).

## Procedure
0. **Fingerprint the fastlane setup** — confirm the production lane/scheme/destination before running:
   ```bash
   bash .claude/skills/signing-provisioning/scripts/detect-fastlane.sh /path/to/project-root
   ```
   Pick the lane whose row shows `method=app-store dest=TestFlight` (SReel/SnapLedger: `deploy_testflight`;
   SnapEdit: `deploy_production`). Use the scheme it reports — don't hardcode.
1. **Pre-flight checks** (do these before running anything):
   ```bash
   cd <project-root>
   git status --short            # clean tree? archiving a dirty tree ships uncommitted work
   git rev-parse --abbrev-ref HEAD
   cat version                   # the marketing version that will ship
   bundle exec fastlane list     # confirm lanes exist (deploy_testflight, sync_certs, ...)
   ```
   Confirm `fastlane/.env` (or CI env) provides `SNAPLAUNCH_API_KEY`, and the ASC `.p8` key is present.
2. **Sync signing** if profiles may be stale (see `signing-provisioning`):
   ```bash
   bundle exec fastlane sync_certs            # readonly:true by default
   ```
3. **Run the deploy lane** — this is slow & outward-facing; confirm with the user first, then:
   ```bash
   bundle exec fastlane deploy_testflight | tee /tmp/deploy.log
   ```
   Prefer running in the background and polling `/tmp/deploy.log` rather than blocking.
4. **Report**: TestFlight build number uploaded, version, processing status, and the dSYM upload result.
   On failure, surface the failing fastlane action + the relevant error lines, don't dump the whole log.

## When asked to set up this pipeline for a NEW app
Replicate the lanes, then register the app with SnapLaunchOps so build numbers stay atomic:
- Get a `projectId` + `track=ios` and an API key; put `SNAPLAUNCH_API_KEY` in `fastlane/.env` (gitignored).
- Reuse `create_appstore_api_key` (shared key `Z265LALJR5`) and the shared match repo.
- Add a `version` file at repo root and the `sync_version_number` lane.
- Set the correct `provisioningProfiles` map for every bundle id (incl. extensions for SnapEdit-style apps).

## Failure modes to recognize
- **`deploy_stg` undefined** — SReel's `deploy_all` references a `deploy_stg` lane not present in its
  Fastfile; `deploy_all` will crash until that lane is defined (see the **deploy-staging** skill). Until
  then, run `deploy_testflight` (production) directly instead of `deploy_all`.
- **Info.plist validation mismatch (SReel, current)** — `validate_application_info_plist` expects
  `CFBundleDisplayName == "SReel"`, but the project sets it to `SVintage`. The validation step will raise
  until the project value and the expected value are reconciled. Flag, don't bypass.
- **SnapLaunchOps non-2xx / missing key** — lane aborts; check `SNAPLAUNCH_API_KEY` and the service is up.
- **Info.plist validation raises** — the wrong build config was archived (display name/id mismatch); fix
  the scheme's archive configuration, don't bypass the check.
- **`pilot` "missing compliance" / export rejected** — set `ITSAppUsesNonExemptEncryption` in Info.plist.
- **Decryption failed in match** — missing `force_legacy_encryption: true` (see `signing-provisioning`).

## Rules
- Deploying is outward-facing and hard to undo (a TestFlight build is visible to testers / triggers review).
  **Confirm with the user before running a deploy lane**, and confirm branch + clean tree first.
- Never commit a bumped build number; the lane intentionally resets it — preserve that behavior.
- Never echo or commit secrets (`SNAPLAUNCH_API_KEY`, `.p8`, GoogleService plists). Treat `fastlane/.env`
  and `AuthKey_*.p8` as secrets that belong in `.gitignore`.
