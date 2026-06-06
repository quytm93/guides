import SwiftUI
import MetalKit
import CoreImage

/// **Tùy chọn 2 — pipeline GPU, render NẶNG trên hàng đợi riêng (actual-res khi kéo).**
///
/// Hai nguồn ảnh:
/// - `displayImage`: bản downsample (vd. 2048px) — xem vừa khung / zoom thấp, tức thì.
/// - `fullImage`: ảnh gốc `CIImage` **lazy** — khi **zoom sâu**, render đúng độ phân
///   giải thật (ROI lúc đó chỉ là một mẩu nhỏ).
///
/// Cách giữ slider mượt mà vẫn full-res (bản tối giản):
/// 1. `draw(in:)` chạy trên MAIN: lấy `currentDrawable` + tính ma trận (rẻ).
/// 2. Đẩy **đúng phần nặng** — `ciContext.render` (gồm giải mã JPEG) + `present` +
///    `commit` — sang **một serial queue riêng**. Main thread rảnh → slider mượt.
/// 3. Mỗi lúc chỉ có **một** drawable đang xử lý (`inFlight`); các giá trị zoom đến
///    trong lúc đó được **gộp** (`pending`) rồi render lại với giá trị mới nhất. Bắt
///    buộc, vì pool chỉ có 3 drawable — nếu không sẽ cạn → `currentDrawable` nil/treo.
///
/// > ⚠️ iOS **Simulator** dùng Metal phần mềm, present-từ-queue-khác có thể KHÔNG
/// > hiển thị (màn xám). Hãy chạy trên **máy thật**. Trên `main` là bản proxy (mượt ở
/// > cả simulator).
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
        view.framebufferOnly = false        // CIContext ghi trực tiếp vào texture
        view.isOpaque = true
        view.isPaused = true
        view.enableSetNeedsDisplay = true   // ta gọi setNeedsDisplay() để kích hoạt draw
        view.clearColor = MTLClearColor(red: 0.04, green: 0.05, blue: 0.11, alpha: 1)
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        let c = context.coordinator
        let changed =
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

        if changed { view.setNeedsDisplay() }
    }

    // MARK: - Renderer

    final class Renderer: NSObject, MTKViewDelegate {
        let device: MTLDevice?
        private let commandQueue: MTLCommandQueue?
        private let ciContext: CIContext?
        private let colorSpace = CGColorSpaceCreateDeviceRGB()
        private let filters: FilterServing
        private let renderQueue = DispatchQueue(label: "PhotoEditorDemo.metalRender", qos: .userInteractive)

        /// Trên ngưỡng zoom này thì dùng ảnh full-res (ROI đã đủ nhỏ để render nhanh).
        private let fullResZoomThreshold: CGFloat = 2.5

        weak var view: MTKView?
        var displayImage: CIImage?
        var fullImage: CIImage?
        var filter: PhotoFilter = .none
        var zoom: CGFloat = 1
        var offset: CGSize = .zero

        // Cờ điều phối — chỉ chạm trên MAIN thread.
        private var inFlight = false
        private var pending = false

        init(filters: FilterServing) {
            self.filters = filters
            let device = MTLCreateSystemDefaultDevice()
            self.device = device
            self.commandQueue = device?.makeCommandQueue()
            self.ciContext = device.map {
                CIContext(mtlDevice: $0, options: [.cacheIntermediates: false])
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            view.setNeedsDisplay()
        }

        /// Chạy trên MAIN (do setNeedsDisplay kích hoạt). Phần nặng đẩy sang renderQueue.
        func draw(in view: MTKView) {
            // Đang render dở → ghi nhận "có yêu cầu mới" rồi thoát (gộp về mới nhất).
            guard !inFlight else { pending = true; return }

            // Chọn nguồn theo zoom (LOD): thấp → display (nhẹ), sâu → full-res (nét thật).
            let useFull = zoom > fullResZoomThreshold
            let source = (useFull ? fullImage : displayImage) ?? fullImage ?? displayImage

            guard let source,
                  let ciContext,
                  let commandQueue,
                  let drawable = view.currentDrawable,            // lấy trên MAIN
                  let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            let dst = view.drawableSize
            guard dst.width > 0, dst.height > 0 else { return }

            // Tính ma trận (rẻ) trên main — chưa giải mã pixel nào (CIImage lazy).
            let filtered = filters.apply(filter, to: source)
            let src = filtered.extent
            guard src.width > 0, src.height > 0 else { return }

            let baseScale = min(dst.width / src.width, dst.height / src.height)
            let scale = baseScale * max(zoom, 1)
            let scaled = filtered.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let s = scaled.extent
            let pointScale = view.contentScaleFactor
            let dx = offset.width  * pointScale
            let dy = offset.height * pointScale
            let tx = (dst.width  - s.width)  / 2 - s.origin.x + dx
            let ty = (dst.height - s.height) / 2 - s.origin.y - dy
            let centered = scaled.transformed(by: CGAffineTransform(translationX: tx, y: ty))

            let colorSpace = self.colorSpace
            inFlight = true
            renderQueue.async { [weak self] in
                autoreleasepool {
                    // ⬇️ Phần NẶNG — giờ chạy NGOÀI main thread.
                    ciContext.render(
                        centered,
                        to: drawable.texture,
                        commandBuffer: commandBuffer,
                        bounds: CGRect(origin: .zero, size: dst),
                        colorSpace: colorSpace
                    )
                    commandBuffer.addCompletedHandler { _ in
                        DispatchQueue.main.async {
                            self?.inFlight = false
                            if self?.pending == true {
                                self?.pending = false
                                self?.view?.setNeedsDisplay()   // render lại với zoom mới nhất
                            }
                        }
                    }
                    commandBuffer.present(drawable)
                    commandBuffer.commit()
                }
            }
        }
    }
}
