# iOS Workshop

A teaching workshop for iOS development, made of two parts:

1. **A course** — a browser-based slideshow (HTML) that teaches Swift + SwiftUI from zero, in **Vietnamese**, targeting **Xcode 26 / iOS 17+**.
2. **Claude Code skills** — a set of project-local skills in [.claude/skills/](.claude/skills/) that help build, configure, sign, and ship real iOS apps following the same conventions the course teaches.

---

## 1. The course

Open [index.html](index.html) in a browser for the course home. It's organized into a **prep step + 3 parts**; the decks live in [lessons/](lessons/), the glossaries at the site root.

**Prep · Chuẩn bị** — [lessons/bai-2.html](lessons/bai-2.html): install & get comfortable with Xcode 26 (download the right build, create a project, tour the UI, run on the Simulator).

**Phần 1 · Glossary** — quick-reference term pages:
- [glossary-ios.html](glossary-ios.html) — 60+ iOS & Swift terms (language, concurrency, memory & performance, data, frameworks, Xcode 26 tooling).
- [glossary-swiftui.html](glossary-swiftui.html) — 80+ SwiftUI terms (views & state, layout, lists, navigation, controls, style, animation & drawing).

**Phần 2 · Case studies** — [lessons/cs-1.html](lessons/cs-1.html) … [lessons/cs-20.html](lessons/cs-20.html): 20 real-app case-study decks (in **Vietnamese**), each in ≤5 slides with key concepts, terms, the business/domain factors, and a Mermaid architecture diagram. Files are numbered in **reading order** (`cs-N.html` = **CS-N**). Source notes: [case-studies.md](case-studies.md).

| # | App | # | App |
|---|---|---|---|
| 1 | AI Photo Editor | 11 | News / Reading |
| 2 | Short-Video Editor | 12 | Casual Game |
| 3 | Music Streaming | 13 | Habit & Fitness Tracker |
| 4 | Meditation / Sleep | 14 | Language Learning |
| 5 | E-commerce | 15 | Notes / Productivity |
| 6 | Personal Finance | 16 | Kids Education |
| 7 | Food Delivery | 17 | AR Furniture / Measure |
| 8 | Ride-Hailing | 18 | Smart-Home Companion |
| 9 | Social Photo Feed | 19 | Enterprise Field App |
| 10 | Dating | 20 | AI Chat Assistant |

**Phần 3 · Performance & critical issues** — [performance-critical-issues.md](performance-critical-issues.md) + slide deck [lessons/perf-1.html](lessons/perf-1.html): a concept catalog of what makes iOS apps **crash, get terminated, leak memory, hang, hitch, and drain CPU/battery/disk/network** — grouped by **symptom**, aligned with Apple's Xcode Organizer metric categories. Opens with a memory-model primer (value vs reference, stack vs heap, ARC) since that underlies the memory/CPU symptoms. Focuses on *what to watch for in production* (not syntax).

**Đọc thêm · Apple resources** — a small section at the end of the home page links out to Apple's App Store submission, platforms/ecosystem, sample code, and developer community (WWDC).

### Navigating the decks

Every lesson is a self-contained browser slideshow ([js/slideshow.js](js/slideshow.js)):

- **← / →** (or `Space` / `PageUp`·`PageDown`) move between slides; **Home / End** jump to first/last; **F** toggles fullscreen; **?** shows the shortcut help.
- The **☰** button (or **M** / **Esc**) opens a shared **content sidebar** listing every prep/glossary/case-study/performance page, built from a single source of truth in [js/sidebar.js](js/sidebar.js) and loaded on both the decks and the glossary pages.
- Styling is shared via [css/style.css](css/style.css); the home page also has a scroll-to-top button.

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
