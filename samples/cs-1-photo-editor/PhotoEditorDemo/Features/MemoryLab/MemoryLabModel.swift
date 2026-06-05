import SwiftUI
import UIKit

@MainActor
@Observable
final class MemoryLabModel {

    struct Result: Identifiable {
        let id = UUID()
        let label: String
        let isCorrectWay: Bool
        let baseline: UInt64
        let peak: UInt64
        let duration: TimeInterval
        let outputPixels: String

        var deltaMB: Double { Double(peak &- baseline) / 1_048_576 }
    }

    var sourceMegapixels: Double = 24
    private(set) var isGenerating = false
    private(set) var isWorking = false
    private(set) var sourceInfo = "Chưa có ảnh nguồn. Hãy tạo một ảnh để bắt đầu."
    private(set) var results: [Result] = []

    private var sourceData: Data?
    private let service = FilterService.shared

    var hasSource: Bool { sourceData != nil }

    // MARK: - Tạo ảnh nguồn

    func generateSource() async {
        isGenerating = true
        defer { isGenerating = false }

        let mp = sourceMegapixels
        let data = await Task.detached(priority: .userInitiated) {
            SyntheticImage.makeJPEG(megapixels: mp)
        }.value

        sourceData = data
        let size = SyntheticImage.pixelSize(megapixels: mp)
        sourceInfo = String(
            format: "Ảnh nguồn %.0f MP · %d×%d px · JPEG %.1f MB",
            mp, Int(size.width), Int(size.height), Double(data.count) / 1_048_576
        )
        results.removeAll()
    }

    // MARK: - ❌ Cách SAI: bung full-res + xử lý NGAY trên main thread

    /// Hàm này chạy đồng bộ trên main thread → UI **đứng hình** trong lúc xử lý,
    /// và footprint tăng vọt vì giữ bitmap full-res. Đó chính là bài học.
    func runNaive() {
        guard let data = sourceData, !data.isEmpty else { return }

        let baseline = MemoryReporter.footprint()
        let start = Date()
        var peak = baseline
        var pixels = "—"

        autoreleasepool {
            guard let image = UIImage(data: data) else { return }
            // Bung bitmap full-res vào RAM (rộng × cao × 4 byte) rồi áp filter.
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
            let fullRes = renderer.image { _ in image.draw(at: .zero) }
            let filtered = service.apply(.vivid, to: fullRes)
            peak = MemoryReporter.footprint()          // đo khi bitmap còn sống
            pixels = "\(Int(fullRes.size.width))×\(Int(fullRes.size.height))"
            _ = filtered                                // giữ alive tới đây
        }

        let duration = Date().timeIntervalSince(start)
        results.insert(
            Result(label: "❌ Full-res · main thread", isCorrectWay: false,
                   baseline: baseline, peak: peak, duration: duration, outputPixels: pixels),
            at: 0
        )
    }

    // MARK: - ✅ Cách ĐÚNG: downsample qua ImageIO + xử lý ngoài main thread

    func runOptimized() async {
        guard let data = sourceData, !data.isEmpty else { return }

        isWorking = true
        defer { isWorking = false }

        let baseline = MemoryReporter.footprint()
        var peak = baseline
        // Poller chạy trên main actor để lấy đỉnh footprint — chứng minh main
        // thread VẪN rảnh (không hề bị block) trong suốt quá trình xử lý.
        let poller = Task { @MainActor in
            while !Task.isCancelled {
                peak = max(peak, MemoryReporter.footprint())
                try? await Task.sleep(for: .milliseconds(8))
            }
        }

        let start = Date()
        let service = self.service
        let output = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let preview = ImageLoader.downsample(data: data, maxPixel: 1600) else { return nil }
            return service.apply(.vivid, to: preview)
        }.value
        let duration = Date().timeIntervalSince(start)

        poller.cancel()
        peak = max(peak, MemoryReporter.footprint())

        let pixels = output.map { "\(Int($0.size.width))×\(Int($0.size.height))" } ?? "—"
        results.insert(
            Result(label: "✅ Downsample · off-main", isCorrectWay: true,
                   baseline: baseline, peak: peak, duration: duration, outputPixels: pixels),
            at: 0
        )
    }
}
