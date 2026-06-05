import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            EditorView()
                .tabItem { Label("Chỉnh ảnh", systemImage: "wand.and.stars") }

            MemoryLabView()
                .tabItem { Label("Memory Lab", systemImage: "gauge.with.dots.needle.67percent") }

            MetalPreviewView()
                .tabItem { Label("Metal", systemImage: "cpu") }

            AboutView()
                .tabItem { Label("Bài học", systemImage: "graduationcap") }
        }
    }
}

#Preview {
    RootView()
}
