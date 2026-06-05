import SwiftUI
import MetalKit
import CoreImage

/// **Tùy chọn 2 — pipeline GPU với Level-of-Detail (LOD).**
///
/// Hiển thị ảnh lớn bằng `MTKView` + `CIContext`, nhận HAI nguồn:
/// - `displayImage`: bản đã downsample (vd. 2048px) — dùng khi xem vừa khung / zoom
///   thấp. Render rất nhanh.
/// - `fullImage`: ảnh gốc dạng `CIImage` **lazy** — chỉ dùng khi **zoom sâu**, lúc đó
///   vùng nhìn thấy (ROI) chỉ là một mẩu nhỏ của ảnh nên Core Image cũng render nhanh
///   mà vẫn cho chi tiết thật.
///
/// Vì sao cách này vừa **ít RAM** vừa **mượt**:
/// - Ở zoom thấp, render cả khung = render `displayImage` nhỏ → nhanh.
/// - Ở zoom cao, render `fullImage` nhưng ROI nhỏ → nhanh; footprint chỉ tăng theo
///   *vùng hiển thị × zoom*, không theo cả ảnh.
/// - Không bao giờ bung bitmap full-res của ảnh gốc vào RAM.
struct MetalImageView: UIViewRepresentable {
    let displayImage: CIImage?
    let fullImage: CIImage?
    let filter: PhotoFilter
    /// 1 = vừa khung (aspect-fit). >1 = phóng to.
    var zoom: CGFloat = 1
    /// Độ dịch khi kéo (points, theo hệ UIKit).
    var offset: CGSize = .zero

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
        let c = context.coordinator
        // CHỈ vẽ lại khi thứ ảnh hưởng tới hình thật sự đổi. Nếu không, mỗi lần
        // SwiftUI tính lại body (vd. cập nhật footprint) sẽ kích hoạt một lần
        // CIContext.render trên main thread → treo máy + CPU cao.
        let needsRedraw =
            c.displayImage !== displayImage ||
            c.fullImage !== fullImage ||
            c.filter != filter ||
            c.zoom != zoom ||
            c.offset != offset

        c.displayImage = displayImage
        c.fullImage = fullImage
        c.filter = filter
        c.zoom = zoom
        c.offset = offset

        if needsRedraw { view.setNeedsDisplay() }
    }

    // MARK: - Renderer

    final class Renderer: NSObject, MTKViewDelegate {
        let device: MTLDevice?
        private let commandQueue: MTLCommandQueue?
        private let ciContext: CIContext?
        private let colorSpace = CGColorSpaceCreateDeviceRGB()
        private let filters: FilterServing

        /// Trên ngưỡng zoom này thì chuyển sang ảnh full-res (ROI đã đủ nhỏ để nhanh).
        private let fullResZoomThreshold: CGFloat = 2.5

        var displayImage: CIImage?
        var fullImage: CIImage?
        var filter: PhotoFilter = .none
        var zoom: CGFloat = 1
        var offset: CGSize = .zero

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
            // Chọn nguồn theo mức zoom: thấp → display (nhanh), sâu → full-res (chi tiết).
            let useFull = zoom > fullResZoomThreshold
            let source = (useFull ? fullImage : displayImage) ?? fullImage ?? displayImage

            guard let source,
                  let ciContext,
                  let commandQueue,
                  let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            let dst = view.drawableSize
            guard dst.width > 0, dst.height > 0 else { return }

            // Áp filter ở dạng công thức (vẫn lazy).
            let filtered = filters.apply(filter, to: source)
            let src = filtered.extent
            guard src.width > 0, src.height > 0 else { return }

            // Aspect-fit làm gốc (kích thước vừa khung KHÔNG đổi dù nguồn là display
            // hay full-res), rồi nhân thêm zoom.
            let baseScale = min(dst.width / src.width, dst.height / src.height)
            let scale = baseScale * max(zoom, 1)
            let scaled = filtered.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let s = scaled.extent

            // Canh giữa + áp pan (đổi point → pixel, lật trục Y cho hệ CIImage).
            let pointScale = view.contentScaleFactor
            let dx = offset.width  * pointScale
            let dy = offset.height * pointScale
            let tx = (dst.width  - s.width)  / 2 - s.origin.x + dx
            let ty = (dst.height - s.height) / 2 - s.origin.y - dy
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
