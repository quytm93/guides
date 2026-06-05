import UIKit

/// Tạo ảnh độ phân giải cao *ngay trong app* để demo — không cần kèm file ảnh nặng
/// vào repo, và người dùng trên simulator (chưa có ảnh nào) vẫn chạy được.
enum SyntheticImage {

    /// Kích thước pixel cho số megapixel cho trước (khung dọc 3:4).
    static func pixelSize(megapixels: Double, aspect: CGFloat = 0.75) -> CGSize {
        let pixels = max(0.1, megapixels) * 1_000_000
        let height = (pixels / Double(aspect)).squareRoot()
        let width = height * Double(aspect)
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    /// JPEG nén sẵn trong RAM (mô phỏng ảnh chụp từ máy ảnh).
    static func makeJPEG(megapixels: Double) -> Data {
        makeImage(megapixels: megapixels).jpegData(compressionQuality: 0.9) ?? Data()
    }

    /// Vẽ một ảnh gradient nhiều màu + chi tiết tần số cao (để JPEG không nén về 0).
    static func makeImage(megapixels: Double, aspect: CGFloat = 0.75) -> UIImage {
        let size = pixelSize(megapixels: megapixels, aspect: aspect)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor.systemTeal, UIColor.systemIndigo,
                UIColor.systemPink, UIColor.systemOrange
            ].map { $0.cgColor }
            if let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors as CFArray,
                locations: [0, 0.4, 0.7, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
            // Vòng tròn rải đều tạo chi tiết để JPEG có dung lượng thật.
            let step = max(40, Int(size.width / 36))
            for x in stride(from: 0, to: Int(size.width), by: step) {
                let radius = CGFloat(x % 220) + 24
                UIColor(white: 1, alpha: 0.05).setFill()
                cg.fillEllipse(in: CGRect(x: CGFloat(x), y: CGFloat(x) * 0.6,
                                          width: radius, height: radius))
            }
        }
    }
}
