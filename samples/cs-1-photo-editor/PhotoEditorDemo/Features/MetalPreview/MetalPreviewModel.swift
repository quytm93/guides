import SwiftUI
import CoreImage

@MainActor
@Observable
final class MetalPreviewModel {

    var filter: PhotoFilter = .none

    /// Bản nhẹ để xem vừa khung / zoom thấp (render nhanh).
    private(set) var displayImage: CIImage?
    /// Ảnh gốc lazy — chỉ dùng khi zoom sâu.
    private(set) var fullImage: CIImage?

    private(set) var isGenerating = false
    private(set) var info = "Chưa có ảnh. Chọn ảnh test để xem Metal render."
    private(set) var footprintText = ""

    /// Cạnh dài nhất của bản display — đủ nét cho zoom thấp, đủ nhẹ cho RAM/CPU.
    private let displayMaxPixel: CGFloat = 2048

    var hasImage: Bool { fullImage != nil || displayImage != nil }

    // MARK: - Nạp ảnh test thật

    func load(testImage: TestImage) async {
        isGenerating = true
        defer { isGenerating = false }

        // Chờ một nhịp để sheet picker đóng mượt TRƯỚC khi xử lý.
        try? await Task.sleep(for: .milliseconds(250))

        let url = testImage.url
        let maxPixel = displayMaxPixel
        let (display, full) = await Task.detached(priority: .userInitiated) { () -> (CIImage?, CIImage?) in
            // Bản display: ImageIO downsample (không bung full-res), bọc thành CIImage.
            let display = ImageLoader.downsample(url: url, maxPixel: maxPixel).flatMap { CIImage(image: $0) }
            // Bản full: lazy, tôn trọng orientation để khớp với bản display.
            let full = CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
            return (display, full)
        }.value

        displayImage = display ?? full
        fullImage = full
        info = "\(testImage.name) · \(testImage.subtitle) · Metal (zoom sâu = full-res)"
        updateFootprint()
    }

    func updateFootprint() {
        let text = "Footprint hiện tại: " + MemoryReporter.mb(MemoryReporter.footprint())
        if text != footprintText { footprintText = text }   // tránh recompute thừa
    }
}
