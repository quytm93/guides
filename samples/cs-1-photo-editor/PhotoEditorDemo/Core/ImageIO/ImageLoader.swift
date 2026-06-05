import UIKit
import ImageIO

/// Giải mã ảnh ở **đúng kích thước cần hiển thị** bằng ImageIO, KHÔNG bao giờ bung
/// bitmap full-res vào RAM. Đây là chìa khóa tránh "memory spike" với ảnh 48MP.
///
/// So sánh:
/// - `UIImage(data:)` → giữ nguyên dữ liệu, nhưng khi *vẽ* sẽ bung bitmap full-res
///   (rộng × cao × 4 byte). Ảnh 48MP ≈ 190 MB chỉ riêng bitmap.
/// - `downsample(...)` → ImageIO tạo thumbnail trực tiếp, chỉ tốn RAM cho ảnh nhỏ.
enum ImageLoader {

    /// Tạo ảnh đã thu nhỏ với cạnh dài nhất = `maxPixel` (pixel thực).
    static func downsample(data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        return downsample(source: source, maxPixel: maxPixel)
    }

    /// Phiên bản đọc từ URL — vẫn không bung full-res vào RAM.
    static func downsample(url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }
        return downsample(source: source, maxPixel: maxPixel)
    }

    private static func downsample(source: CGImageSource, maxPixel: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // tôn trọng EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,         // giải mã ngay, ngoài main thread
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }
}
