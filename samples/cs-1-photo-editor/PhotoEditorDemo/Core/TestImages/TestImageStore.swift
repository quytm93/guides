import UIKit
import ImageIO

/// Một ảnh test được đóng gói (bundle) kèm app — đọc kích thước thật qua ImageIO
/// mà KHÔNG giải mã full-res.
struct TestImage: Identifiable, Hashable, Sendable {
    let url: URL
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSizeBytes: Int

    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
    var megapixels: Double { Double(pixelWidth * pixelHeight) / 1_000_000 }

    var subtitle: String {
        let mb = Double(fileSizeBytes) / 1_048_576
        return String(format: "%.0f MP · %d×%d · %.1f MB", megapixels, pixelWidth, pixelHeight, mb)
    }
}

/// Tìm & mô tả các ảnh test nằm trong bundle (thư mục Resources/TestImages).
enum TestImageStore {

    static func all() -> [TestImage] {
        let bundle = Bundle.main
        // Resource copy thường "phẳng hóa" file về gốc bundle; thử cả subdirectory.
        var urls = bundle.urls(forResourcesWithExtension: "jpg", subdirectory: nil) ?? []
        if urls.isEmpty {
            urls = bundle.urls(forResourcesWithExtension: "jpg", subdirectory: "TestImages") ?? []
        }
        return urls
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap(describe(url:))
    }

    /// Đọc metadata (pixel size) qua ImageIO — chỉ đọc header, không bung bitmap.
    static func describe(url: URL) -> TestImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }
        let width = (props[kCGImagePropertyPixelWidth] as? Int) ?? 0
        let height = (props[kCGImagePropertyPixelHeight] as? Int) ?? 0
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return TestImage(url: url, pixelWidth: width, pixelHeight: height, fileSizeBytes: size)
    }

    /// Thumbnail nhỏ cho UI picker — downsample nên không tốn RAM.
    static func thumbnail(for image: TestImage, maxPixel: CGFloat = 240) -> UIImage? {
        ImageLoader.downsample(url: image.url, maxPixel: maxPixel)
    }
}
