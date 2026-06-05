import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum PhotoFilter: String, CaseIterable, Identifiable {
    case none  = "Gốc"
    case vivid = "Rực rỡ"
    case mono  = "Đen trắng"
    case sepia = "Sepia"
    case noir  = "Noir"

    var id: String { rawValue }
}

protocol FilterServing {
    /// Công thức GPU thuần `CIImage → CIImage` (lazy) — dùng cho cả MTKView.
    func apply(_ filter: PhotoFilter, to input: CIImage) -> CIImage
    /// Trả về `UIImage` đã render (materialize) — dùng cho preview tĩnh / export.
    func apply(_ filter: PhotoFilter, to image: UIImage) -> UIImage?
}

/// Áp filter bằng Core Image trên GPU.
///
/// Điểm then chốt về hiệu năng: **dùng lại MỘT `CIContext`**. Tạo `CIContext` mới
/// cho mỗi khung hình là lỗi kinh điển khiến app giật và ngốn bộ nhớ — vì mỗi
/// context biên dịch lại pipeline Metal.
final class FilterService: FilterServing {

    static let shared = FilterService()

    private let context = CIContext(options: [.useSoftwareRenderer: false])

    /// `CIImage → CIImage`: chỉ là *công thức*, chưa render. Rẻ, lazy, tile được.
    func apply(_ filter: PhotoFilter, to input: CIImage) -> CIImage {
        switch filter {
        case .none:
            return input
        case .vivid:
            let f = CIFilter.vibrance()
            f.inputImage = input
            f.amount = 1
            return f.outputImage ?? input
        case .mono:
            let f = CIFilter.photoEffectMono()
            f.inputImage = input
            return f.outputImage ?? input
        case .sepia:
            let f = CIFilter.sepiaTone()
            f.inputImage = input
            f.intensity = 0.9
            return f.outputImage ?? input
        case .noir:
            let f = CIFilter.photoEffectNoir()
            f.inputImage = input
            return f.outputImage ?? input
        }
    }

    /// `UIImage → UIImage`: render công thức trên qua `CIContext` dùng chung.
    func apply(_ filter: PhotoFilter, to image: UIImage) -> UIImage? {
        guard filter != .none else { return image }
        guard let input = CIImage(image: image) else { return image }
        let output = apply(filter, to: input)
        guard let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}
