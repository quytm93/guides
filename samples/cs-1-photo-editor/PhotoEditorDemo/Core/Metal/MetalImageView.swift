import SwiftUI
import MetalKit
import CoreImage

/// **Tùy chọn 2 — pipeline GPU.** Render ảnh lớn bằng `MTKView` + `CIContext`.
///
/// Hai nguồn ảnh (Level-of-Detail):
/// - `displayImage`: bản downsample (vd. 2048px) — xem vừa khung / zoom thấp, tức thì.
/// - `fullImage`: ảnh gốc `CIImage` **lazy** — khi **zoom sâu**, render đúng độ phân
///   giải thật (ROI lúc đó chỉ là một mẩu nhỏ).
///
/// **Hai đường render tùy môi trường:**
/// - **Máy thật:** đẩy `ciContext.render` (nặng) sang **serial queue riêng**, blit/
///   present ngoài main → kéo slider vẫn mượt mà giữ *full-res* khi zoom.
/// - **Simulator:** Metal phần mềm không hiển thị được đường present-ngoài-main, nên
///   render **trên main** + dùng bản display lúc đang tương tác (`interactive`) cho
///   khỏi lag. (Đó là lý do còn tham số `interactive`.)
struct MetalImageView: UIViewRepresentable {
    let displayImage: CIImage?
    let fullImage: CIImage?
    let filter: PhotoFilter
    /// 1 = vừa khung (aspect-fit). >1 = phóng to.
    var zoom: CGFloat = 1
    /// Độ dịch khi kéo (points, theo hệ UIKit).
    var offset: CGSize = .zero
    /// Đang kéo slider / pinch / pan? Chỉ dùng cho đường Simulator (render trên main).
    var interactive: Bool = false

    func makeCoordinator() -> Renderer {
        Renderer(filters: FilterService.shared)
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = context.coordinator.device
        view.delegate = context.coordinator
        view.framebufferOnly = false
        view.isOpaque = true
        view.isPaused = true
        view.enableSetNeedsDisplay = true
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
            c.offset != offset ||
            c.interactive != interactive

        c.displayImage = displayImage
        c.fullImage = fullImage
        c.filter = filter
        c.zoom = zoom
        c.offset = offset
        c.interactive = interactive

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
        var interactive = false

        // Cờ điều phối đường off-main (device) — chỉ chạm trên MAIN.
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

        func draw(in view: MTKView) {
//            #if targetEnvironment(simulator)
//            drawOnMain(in: view)
//            #else
//            drawOffMain(in: view)
//            #endif
            drawOffMain(in: view)
        }

        // MARK: Nguồn + ma trận (chung)

        private func currentSource() -> CIImage? {
            #if targetEnvironment(simulator)
            // Đang tương tác → dùng display cho nhẹ (Metal phần mềm chậm).
            let useFull = !interactive && zoom > fullResZoomThreshold
            #else
            let useFull = zoom > fullResZoomThreshold
            #endif
            return (useFull ? fullImage : displayImage) ?? fullImage ?? displayImage
        }

        /// Aspect-fit + zoom + pan → CIImage đã đặt đúng vị trí trong khung `dst`.
        private func centeredImage(source: CIImage, dst: CGSize, pointScale: CGFloat) -> CIImage? {
            let filtered = filters.apply(filter, to: source)
            let src = filtered.extent
            guard src.width > 0, src.height > 0 else { return nil }

            let baseScale = min(dst.width / src.width, dst.height / src.height)
            let scale = baseScale * max(zoom, 1)
            let scaled = filtered.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let s = scaled.extent
            let dx = offset.width  * pointScale
            let dy = offset.height * pointScale
            let tx = (dst.width  - s.width)  / 2 - s.origin.x + dx
            let ty = (dst.height - s.height) / 2 - s.origin.y - dy
            return scaled.transformed(by: CGAffineTransform(translationX: tx, y: ty))
        }

        // MARK: Đường Simulator — render trên MAIN

        private func drawOnMain(in view: MTKView) {
            guard let source = currentSource(),
                  let ciContext,
                  let commandQueue,
                  let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            let dst = view.drawableSize
            guard dst.width > 0, dst.height > 0,
                  let centered = centeredImage(source: source, dst: dst, pointScale: view.contentScaleFactor)
            else { return }

            ciContext.render(centered, to: drawable.texture, commandBuffer: commandBuffer,
                             bounds: CGRect(origin: .zero, size: dst), colorSpace: colorSpace)
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        // MARK: Đường máy thật — render NẶNG ngoài MAIN (gộp về mới nhất)

        private func drawOffMain(in view: MTKView) {
            guard !inFlight else { pending = true; return }
            guard let source = currentSource(),
                  let ciContext,
                  let commandQueue,
                  let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            let dst = view.drawableSize
            guard dst.width > 0, dst.height > 0,
                  let centered = centeredImage(source: source, dst: dst, pointScale: view.contentScaleFactor)
            else { return }

            let colorSpace = self.colorSpace
            inFlight = true
            renderQueue.async { [weak self] in
                autoreleasepool {
                    ciContext.render(centered, to: drawable.texture, commandBuffer: commandBuffer,
                                     bounds: CGRect(origin: .zero, size: dst), colorSpace: colorSpace)
                    commandBuffer.addCompletedHandler { _ in
                        DispatchQueue.main.async {
                            self?.inFlight = false
                            if self?.pending == true {
                                self?.pending = false
                                self?.view?.setNeedsDisplay()
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
