import SwiftUI

/// CS-1 · AI Photo Editor (kiểu SnapEdit) — bản demo chạy hoàn toàn on-device.
///
/// Mục tiêu dạy học: cho thấy *cạm bẫy hiệu năng & bộ nhớ* khi xử lý ảnh độ phân
/// giải cao trên iOS — và cách làm đúng (downsample + xử lý ngoài main thread).
@main
struct PhotoEditorDemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
