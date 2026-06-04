---
name: swift-review
description: Review Swift / SwiftUI code against iOS best-practice criteria — concurrency safety, ARC retain cycles, force-unwrap safety, SwiftUI state correctness, performance, accessibility. Use when asked to review Swift code, audit a screen, check for retain cycles/leaks, or before merging iOS changes.
---

# swift-review

Review Swift / SwiftUI code (a diff, a file, or a feature) against the criteria below. Report findings ranked by severity; cite `file:line`. Don't rewrite everything — flag what matters and suggest the fix.

## Scope
- Default to reviewing the current diff (`git diff` / `git diff --staged`). If the user names files, review those.
- This is a quality + correctness review, not a rewrite. Be specific and actionable.

## Review criteria (check each; skip silently if N/A)

### 1. Concurrency safety (high priority)
- UI-touching state mutated off the main actor → should be `@MainActor`.
- Completion-handler APIs where `async/await` exists.
- `Task {}` that should be `.task {}` (no cancellation tie to view lifecycle), or un-cancelled long-running tasks.
- `Sendable` / Swift 6 strict-concurrency violations; shared mutable state without an `actor`.
- Blocking calls (sync network, heavy compute, `Thread.sleep`) on the main thread.

### 2. Memory / ARC (high priority)
- Escaping closures, `Task`, `Timer`, Combine `sink`, delegates capturing `self` strongly → retain cycle. Want `[weak self]` / `unowned` / `weak var delegate`.
- Closures stored as properties capturing `self`.
- `NotificationCenter` / KVO observers not removed.

### 3. Safety idioms
- Force-unwrap `!`, `try!`, force-cast `as!` in app code → prefer `guard let` / `if let` / typed errors.
- Implicitly-unwrapped optionals outside IBOutlet/init patterns.
- Empty `catch {}` that swallows errors.

### 4. SwiftUI state correctness
- Wrong property wrapper: `@State` for value owned here; `@Bindable`/`@Binding` for passed-in; `@Environment` for app-wide. No duplicated source of truth.
- Legacy `ObservableObject`/`@Published` where `@Observable` fits (iOS 17+ house default).
- Heavy work or side effects inside `body`.
- List/ForEach using array index as id instead of stable `Identifiable`.

### 5. Performance
- `VStack`/`HStack` with large data that should be `LazyVStack`/`List`.
- Recomputing expensive values every render (no caching/`@State`).
- Full-size images without downsampling; missing `.task(id:)` debounce.

### 6. Accessibility & localization
- Hardcoded user-facing strings that should be localized (course Bài 14).
- Images/icon buttons without `.accessibilityLabel`.
- Fixed font sizes that break Dynamic Type; layout that breaks under large text / RTL.

### 7. API & lifecycle hygiene
- Deprecated-for-iOS-17 APIs (`NavigationView` → `NavigationStack`, etc.).
- Resources/observers/tasks not cleaned up on disappear / scene-phase change.

## Procedure
1. Get the code under review (diff or named files).
2. Walk the criteria. For each finding: severity (🔴 bug/leak / 🟡 should-fix / 🔵 nit), `file:line`, one-line why, suggested fix.
3. If you find no real issues, say so plainly — don't manufacture nits.

## Output format
```
## swift-review — <N> findings

🔴 file.swift:42 — Retain cycle: `Task` captures `self` strongly in stored closure. → use `[weak self]`.
🟡 FooView.swift:18 — `ObservableObject` here; project targets iOS 17+, use `@Observable`.
🔵 ...
```
Keep it scannable. Lead with the highest-severity items.
