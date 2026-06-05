import SwiftUI
import CoreImage

@MainActor
@Observable
final class MetalPreviewModel {

    var sourceMegapixels: Double = 48
    var filter: PhotoFilter = .none

    private(set) var image: CIImage?
    private(set) var isGenerating = false
    private(set) var info = "Chưa có ảnh. Tạo một ảnh lớn để Metal render."
    private(set) var footprintText = ""

    var hasImage: Bool { image != nil }

    /// Tạo ảnh lớn rồi bọc thành `CIImage` **lazy** — KHÔNG bung bitmap full-res.
    func generate() async {
        isGenerating = true
        defer { isGenerating = false }

        let mp = sourceMegapixels
        let data = await Task.detached(priority: .userInitiated) {
            SyntheticImage.makeJPEG(megapixels: mp)
        }.value

        // `CIImage(data:)` chỉ giữ data nén + công thức giải mã; Core Image sẽ tile
        // khi render. Đây là lý do footprint không tăng theo độ phân giải nguồn.
        image = CIImage(data: data)

        let size = SyntheticImage.pixelSize(megapixels: mp)
        info = String(format: "Nguồn %.0f MP · %d×%d px · render bằng Metal (CIContext)",
                      mp, Int(size.width), Int(size.height))
        updateFootprint()
    }

    func updateFootprint() {
        footprintText = "Footprint hiện tại: " + MemoryReporter.mb(MemoryReporter.footprint())
    }
}
