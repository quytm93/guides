import SwiftUI
import MetalKit
import CoreImage

/// **Tùy chọn 2 — pipeline GPU.** Hiển thị một `CIImage` (có thể RẤT lớn) bằng
/// `MTKView` + `CIContext`.
///
/// Vì sao footprint vẫn thấp dù ảnh 48MP:
/// - `CIImage` chỉ là *công thức* (lazy), chưa bung bitmap nào vào RAM.
/// - `CIContext.render(...)` chỉ vẽ **đúng kích thước drawable** đang hiển thị và
///   **tự chia ô (tile)** trên GPU. Core Image không bao giờ giữ cả ảnh full-res
///   trong bộ nhớ một lúc.
/// - Ta KHÔNG bao giờ tạo `UIImage`/`CGImage` full-res trong code → không có "spike".
///
/// Đối lập với *Memory Lab · cách sai* (bung full-res bitmap vào RAM) và bổ sung
/// cho *cách đúng* (downsample CPU): đây là cách vẫn xem được ảnh gốc đầy đủ.
struct MetalImageView: UIViewRepresentable {
    let image: CIImage?
    let filter: PhotoFilter

    func makeCoordinator() -> Renderer {
        Renderer(filters: FilterService.shared)
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = context.coordinator.device
        view.delegate = context.coordinator
        view.framebufferOnly = false        // CIContext cần ghi trực tiếp vào texture
        view.isOpaque = true
        view.enableSetNeedsDisplay = true   // chỉ vẽ khi có thay đổi (tiết kiệm GPU/pin)
        view.isPaused = true
        view.clearColor = MTLClearColor(red: 0.04, green: 0.05, blue: 0.11, alpha: 1)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.image = image
        context.coordinator.filter = filter
        view.setNeedsDisplay()
    }

    // MARK: - Renderer

    final class Renderer: NSObject, MTKViewDelegate {
        let device: MTLDevice?
        private let commandQueue: MTLCommandQueue?
        private let ciContext: CIContext?
        private let colorSpace = CGColorSpaceCreateDeviceRGB()
        private let filters: FilterServing

        var image: CIImage?
        var filter: PhotoFilter = .none

        init(filters: FilterServing) {
            self.filters = filters
            let device = MTLCreateSystemDefaultDevice()
            self.device = device
            self.commandQueue = device?.makeCommandQueue()
            self.ciContext = device.map {
                CIContext(mtlDevice: $0, options: [.cacheIntermediates: false])
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let image,
                  let ciContext,
                  let commandQueue,
                  let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            let dst = view.drawableSize
            guard dst.width > 0, dst.height > 0 else { return }

            // Áp filter ở dạng công thức (vẫn lazy).
            let filtered = filters.apply(filter, to: image)
            let src = filtered.extent
            guard src.width > 0, src.height > 0 else { return }

            // Aspect-fit + canh giữa vào drawable.
            let scale = min(dst.width / src.width, dst.height / src.height)
            let scaled = filtered.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let tx = (dst.width  - scaled.extent.width)  / 2 - scaled.extent.origin.x
            let ty = (dst.height - scaled.extent.height) / 2 - scaled.extent.origin.y
            let centered = scaled.transformed(by: CGAffineTransform(translationX: tx, y: ty))

            // Render thẳng vào texture của drawable, chỉ ở kích thước hiển thị.
            ciContext.render(
                centered,
                to: drawable.texture,
                commandBuffer: commandBuffer,
                bounds: CGRect(origin: .zero, size: dst),
                colorSpace: colorSpace
            )
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
