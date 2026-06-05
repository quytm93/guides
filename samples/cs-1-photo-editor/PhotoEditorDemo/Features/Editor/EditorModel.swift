import SwiftUI
import PhotosUI

@MainActor
@Observable
final class EditorModel {

    /// Ảnh xem trước đã **downsample** — đây là thứ ta hiển thị, không phải full-res.
    private(set) var preview: UIImage?
    private(set) var isWorking = false
    private(set) var status: String = "Chọn ảnh hoặc dùng ảnh mẫu để bắt đầu."

    var filter: PhotoFilter = .none {
        didSet { Task { await reapplyFilter() } }
    }

    /// Ảnh gốc (đã downsample) — nguồn để áp filter, giữ riêng để áp lại nhanh.
    private var base: UIImage?

    private let filters: FilterServing = FilterService.shared
    /// Cạnh dài nhất cho preview: đủ nét cho màn hình, đủ nhỏ cho RAM.
    private let previewMaxPixel: CGFloat = 1600

    // MARK: - Nguồn ảnh

    func load(item: PhotosPickerItem?) async {
        guard let item else { return }
        isWorking = true
        status = "Đang tải ảnh…"
        defer { isWorking = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            status = "Không đọc được ảnh."
            return
        }
        // Downsample NGAY khi nạp — không bao giờ giữ bitmap full-res.
        let maxPixel = previewMaxPixel
        let downsized = await Task.detached(priority: .userInitiated) {
            ImageLoader.downsample(data: data, maxPixel: maxPixel)
        }.value

        guard let downsized else {
            status = "Định dạng ảnh không hỗ trợ."
            return
        }
        base = downsized
        status = "Ảnh \(Int(downsized.size.width))×\(Int(downsized.size.height)) px (đã downsample để xem trước)."
        await reapplyFilter()
    }

    func useSampleImage() async {
        isWorking = true
        status = "Đang tạo ảnh mẫu…"
        defer { isWorking = false }

        let maxPixel = previewMaxPixel
        let image = await Task.detached(priority: .userInitiated) {
            // Tạo ảnh ~12MP rồi downsample như ảnh thật.
            let big = SyntheticImage.makeImage(megapixels: 12)
            guard let data = big.jpegData(compressionQuality: 0.9) else { return big }
            return ImageLoader.downsample(data: data, maxPixel: maxPixel) ?? big
        }.value
        base = image
        status = "Ảnh mẫu \(Int(image.size.width))×\(Int(image.size.height)) px."
        await reapplyFilter()
    }

    // MARK: - Filter (luôn chạy ngoài main thread)

    private func reapplyFilter() async {
        guard let base else { return }
        isWorking = true
        defer { isWorking = false }

        let chosen = filter
        let service = filters
        let result = await Task.detached(priority: .userInitiated) {
            service.apply(chosen, to: base)
        }.value
        preview = result ?? base
    }
}
