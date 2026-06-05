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

    func apply(_ filter: PhotoFilter, to image: UIImage) -> UIImage? {
        guard filter != .none else { return image }
        guard let input = CIImage(image: image) else { return image }

        let output: CIImage?
        switch filter {
        case .none:
            output = input
        case .vivid:
            let f = CIFilter.vibrance()
            f.inputImage = input
            f.amount = 1
            output = f.outputImage
        case .mono:
            let f = CIFilter.photoEffectMono()
            f.inputImage = input
            output = f.outputImage
        case .sepia:
            let f = CIFilter.sepiaTone()
            f.inputImage = input
            f.intensity = 0.9
            output = f.outputImage
        case .noir:
            let f = CIFilter.photoEffectNoir()
            f.inputImage = input
            output = f.outputImage
        }

        guard let result = output,
              let cg = context.createCGImage(result, from: result.extent) else {
            return nil
        }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}
