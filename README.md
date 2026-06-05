# iOS Workshop

A teaching workshop for iOS development, made of two parts:

1. **A course** — a browser-based slideshow (HTML) that teaches Swift + SwiftUI from zero, in **Vietnamese**, targeting **Xcode 26 / iOS 17+**.
2. **Claude Code skills** — a set of project-local skills in [.claude/skills/](.claude/skills/) that help build, configure, sign, and ship real iOS apps following the same conventions the course teaches.

---

## 1. The course

Open [index.html](index.html) in a browser for the lesson index. Slides live in [lessons/](lessons/).

**Swift foundations** (`swift-1`…`swift-4`): data types & functions · optionals · collections & control flow · closures, struct/class & protocol.

**iOS track** (`bai-1`…`bai-18`):

| # | Topic | # | Topic |
|---|---|---|---|
| 1 | Getting started | 10 | SwiftData |
| 2 | Install & learn Xcode 26 | 11 | Run on a real iPhone & publish |
| 3 | First interactive app | 12 | Combine with SwiftUI |
| 4 | Layout & lists | 13 | Animations & effects |
| 5 | Multi-screen navigation | 14 | Localization |
| 6 | Persisting data with `@AppStorage` | 15 | Push notifications |
| 7 | Data models with `struct` & `Identifiable` | 16 | Concurrency & actors |
| 8 | Calling a network API | 17 | App lifecycle |
| 9 | MVVM with `@Observable` | 18 | Memory management (ARC) |

Plus [tong-ket.html](lessons/tong-ket.html) — wrap-up & roadmap.

**Case studies** — [case-studies.md](case-studies.md): 20 real-app case-study lessons (in **Vietnamese**), one app per lesson in ≤3 "slides" with key concepts, terms, factors, and a Mermaid architecture diagram. Spans technical, business, and domain aspects (photo editor, fintech, ride-hailing, AR, IoT, AI chat, …).

**Performance & critical issues** — [performance-critical-issues.md](performance-critical-issues.md) + slide deck [lessons/perf-1.html](lessons/perf-1.html) ("Phần 3"): a concept catalog of what makes iOS apps **crash, get terminated, leak memory, hang, hitch, and drain CPU/battery/disk/network** — grouped by **symptom**, aligned with Apple's Xcode Organizer metric categories. Focuses on *what to watch for in production* (not syntax).

**House style** (taught throughout, and enforced by the skills): iOS 17+, Xcode 26, SwiftUI-first, **MVVM with `@Observable`**, `async/await` + actors, SwiftData, Combine reserved for event streams. Every code lesson ends with a complete copy-paste-runnable sample.

---

## 2. Claude Code skills

These live in [.claude/skills/](.claude/skills/) and are **project-local** — they activate when Claude Code runs from this repo. They double as **reusable templates** for real iOS projects; several can fingerprint a project and adapt to its existing setup. The deploy/signing skills are modelled on the real org pipelines (SnapEdit, SnapLedger, SReel — fastlane `match` + App Store Connect API key + SnapLaunchOps build numbers).

### Build & code

| Skill | What it does |
|---|---|
| [swiftui-feature](.claude/skills/swiftui-feature/SKILL.md) | Scaffold a new feature the house way: a SwiftUI `View` + `@Observable` view model + a protocol-backed service + `#Preview`, using iOS 17+ idioms (`.task`, `[weak self]`, no force-unwraps). |
| [swift-review](.claude/skills/swift-review/SKILL.md) | Review Swift/SwiftUI code against 9 criteria — concurrency safety, ARC retain cycles, force-unwrap safety, SwiftUI state correctness, performance, accessibility/localization, lifecycle — with severity-ranked, `file:line` findings. |
| [init-mvvm-project](.claude/skills/init-mvvm-project/SKILL.md) | Lay down a new SwiftUI app skeleton: `@main` entry, feature-folder layout, a sample `@Observable` feature, and a project-file strategy (native vs XcodeGen/Tuist). |
| [xcode-build](.claude/skills/xcode-build/SKILL.md) | Build / test / run on a simulator from the CLI via `xcodebuild` + `xcrun simctl`, with concise error parsing. |

### Project configuration

| Skill | What it does |
|---|---|
| [build-configurations](.claude/skills/build-configurations/SKILL.md) | Set up STAGING/PRODUCTION environment separation — **detects** the project's pattern first (`scripts/detect-env-pattern.sh`) and routes to either **Pattern A** (multi-config single target, SnapEdit-style) or **Pattern B** (separate target per env, SnapLedger-style); never mixes the two. |
| [update-deployment-target](.claude/skills/update-deployment-target/SKILL.md) | Change `IPHONEOS_DEPLOYMENT_TARGET` consistently across all targets/xcconfig/SPM, and flag the `#available` APIs the new floor allows or forbids. |
| [update-bundle-id](.claude/skills/update-bundle-id/SKILL.md) | Change `PRODUCT_BUNDLE_IDENTIFIER` everywhere — preserving extension suffix hierarchy — and follow the references that break silently (entitlements, App Groups, Info.plist, hardcoded ids). |
| [update-app-name](.claude/skills/update-app-name/SKILL.md) | Change the app name, distinguishing the home-screen **display name** (`CFBundleDisplayName`) from the **product name** (`PRODUCT_NAME`, which is the `.app`/`.ipa` filename). |

### Signing & deployment

| Skill | What it does |
|---|---|
| [signing-provisioning](.claude/skills/signing-provisioning/SKILL.md) | Inspect & configure code signing. Drives fastlane **match** (Claude can't touch keychain keys or the developer portal). `scripts/detect-fastlane.sh` (shared) fingerprints the fastlane setup — identity, teams, match config, lanes, bundle ids, a per-lane scheme/method/destination table, and a committed-secrets check. |
| [deploy-staging](.claude/skills/deploy-staging/SKILL.md) | Ship the **staging** build. Canonical = ad-hoc build of a staging scheme (`.stag` id, AdHoc profiles) → **Firebase App Distribution** (SnapLedger/SnapEdit). Interim for apps without Firebase = app-store → TestFlight. |
| [deploy-production](.claude/skills/deploy-production/SKILL.md) | Ship the **production** build: version from a `version` file → build number from the SnapLaunchOps API → app-store `gym` archive → validate IPA Info.plist → `pilot` to TestFlight → dSYM to Crashlytics. |

### Helper scripts

- [build-configurations/scripts/detect-env-pattern.sh](.claude/skills/build-configurations/scripts/detect-env-pattern.sh) — classifies a project's env-separation architecture (`PATTERN_A` / `PATTERN_B` / `NONE` / `MIXED`).
- [signing-provisioning/scripts/detect-fastlane.sh](.claude/skills/signing-provisioning/scripts/detect-fastlane.sh) — fingerprints a project's fastlane lanes, signing, and deploy destinations.

> **Note:** these skills are project-local to this workshop. To use them inside another iOS repo, copy the relevant skill folder into that repo's `.claude/skills/` (or into `~/.claude/skills/` to make it global).
