---
name: swiftui-feature
description: Scaffold a new SwiftUI feature/screen the house way — a View + @Observable view model + service layer + #Preview, using iOS 17+ idioms. Use when asked to "add a screen", "create a feature", "build a view", or wire up MVVM for a new piece of UI.
---

# swiftui-feature

Scaffold a SwiftUI feature following the project conventions taught in this course:
**iOS 17+, Xcode 26, SwiftUI-first, MVVM with `@Observable`, async/await, `#Preview` for every view.**

## When to use
The user wants a new screen / feature / view set up, or wants existing UI refactored into the house MVVM shape.

## Conventions (non-negotiable)
1. **View model** uses the Observation framework: `@Observable final class FooModel`. Never `ObservableObject` / `@Published` unless the value is genuinely a Combine event stream (see Bài 12).
2. **View owns its model** with `@State private var model = FooModel()`. Pass shared models down with `@Bindable` / `@Binding`, read app-wide state via `@Environment`.
3. **Views are dumb** — no networking, parsing, or business logic in `body`. That lives in the model or a service.
4. **Networking / IO** goes in a separate `protocol`-backed service (`FooService`) so the model can be previewed/tested with a fake. Use `async throws` functions, not completion handlers.
5. **Concurrency**: model methods that touch UI state are `@MainActor` (or the whole model is). Launch work with `.task {}` (auto-cancels on disappear), not `.onAppear { Task {...} }`.
6. **Memory**: any escaping closure / long-lived `Task` capturing the model uses `[weak self]` (or capture only what's needed).
7. **Safety**: no force-unwrap `!`, `try!`, or force-cast in feature code. Use `guard let` / typed errors.
8. **Identity**: list rows are `Identifiable`; use stable IDs, never array index.
9. **Every view ends with a `#Preview`** seeded with sample/fake data.
10. **Accessibility**: user-facing strings are `LocalizedStringKey` (string literals are fine, they bridge automatically); interactive non-text elements get `.accessibilityLabel`.

## Procedure
1. Find the feature folder convention in the target project (e.g. `Screen/Feature/...` in SnapEdit, or `Screens/` in Timestamp). Match it. If unsure, ask where the feature should live.
2. Create the files. Default layout for a feature called `Foo`:
   - `FooModel.swift` — the `@Observable` view model (state + intents).
   - `FooService.swift` — `protocol FooServicing` + a live impl, only if the feature does IO.
   - `FooView.swift` — the SwiftUI view + `#Preview`.
3. Wire navigation: prefer `NavigationStack` + value-based `.navigationDestination` (Bài 5).
4. Build to confirm it compiles (use the `xcode-build` skill).

## Template (adapt names; trim the service if no IO)

```swift
// FooModel.swift
import Foundation

@MainActor
@Observable
final class FooModel {
    private(set) var items: [Item] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let service: FooServicing
    init(service: FooServicing = FooService()) { self.service = service }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do { items = try await service.fetchItems() }
        catch { errorMessage = error.localizedDescription }
    }
}
```

```swift
// FooService.swift
import Foundation

protocol FooServicing: Sendable {
    func fetchItems() async throws -> [Item]
}

struct FooService: FooServicing {
    func fetchItems() async throws -> [Item] {
        // URLSession async API; decode with Codable
        fatalError("implement")
    }
}
```

```swift
// FooView.swift
import SwiftUI

struct FooView: View {
    @State private var model = FooModel()

    var body: some View {
        List(model.items) { item in
            Text(item.title)
        }
        .overlay { if model.isLoading { ProgressView() } }
        .task { await model.load() }
        .navigationTitle("Foo")
    }
}

#Preview {
    NavigationStack { FooView() }
}
```

## Output
Report the files created and the one-line build result. Don't over-explain the boilerplate.
