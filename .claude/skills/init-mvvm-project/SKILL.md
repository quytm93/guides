---
name: init-mvvm-project
description: Scaffold a brand-new SwiftUI app project structured the house way — iOS 17+, @Observable MVVM, feature-folder layout, App entry point, sample feature, and #Preview. Use when starting a new iOS app from scratch or laying down the initial folder/architecture skeleton.
---

# init-mvvm-project

Lay down a clean SwiftUI app skeleton: **iOS 17+, Xcode 26, MVVM with `@Observable`, async/await.**

Two modes — choose based on what exists:

## Mode A — a fresh Xcode project already exists
The user created an App in Xcode (File ▸ New ▸ Project ▸ App, SwiftUI, Swift). You add the architecture on top. **Do not hand-edit `.pbxproj` to add files** unless using a tool that manages it (e.g. the `xcodeproj` Ruby gem or XcodeGen) — instead create the `.swift` files in the right folders and tell the user to drag them in, OR confirm the project uses Xcode 16+ "folders are groups" (synchronized file system groups) where files on disk are picked up automatically.

## Mode B — generating project structure on disk
Create the folder tree and Swift files. If they want a buildable `.xcodeproj`, recommend **XcodeGen** (`project.yml`) or **Tuist** so the project file is reproducible and diff-friendly.

## Folder layout
```
<AppName>/
  App/
    <AppName>App.swift        // @main entry, NavigationStack root
    RootView.swift
  Core/
    Networking/               // APIClient, endpoints
    Persistence/              // SwiftData container / @AppStorage helpers
    Extensions/
  Features/
    <Feature>/
      <Feature>View.swift
      <Feature>Model.swift    // @Observable
      <Feature>Service.swift  // protocol-backed
  Resources/
    Assets.xcassets
    Localizable.xcstrings     // String Catalog (Bài 14)
  Preview Content/
```

## Files to generate
1. **App entry**
```swift
import SwiftUI

@main
struct <AppName>App: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack { RootView() }
        }
    }
}
```
2. **RootView** — a simple landing view with a `#Preview`.
3. **One sample feature** using the `swiftui-feature` skill conventions (View + `@Observable` Model + Service + `#Preview`), so the architecture is demonstrated, not just described.
4. If they want persistence, set up SwiftData (`@Model` + `.modelContainer` on the WindowGroup) per Bài 10; if app-level settings, an `@AppStorage` helper per Bài 6.

## Decisions to confirm before scaffolding
- App name & bundle id (offer the `update-bundle-id` skill).
- Deployment target (default **iOS 17.0**; offer `update-deployment-target`).
- Project-file strategy: native Xcode project (manual file add) vs XcodeGen/Tuist (reproducible).
- Persistence: SwiftData / `@AppStorage` / none.

## After scaffolding
Build once via the `xcode-build` skill and report the result.
