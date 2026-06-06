import SwiftUI
import MetalKit
import CoreImage

/// **Tùy chọn 2 — pipeline GPU, render NẶNG ngoài main thread (actual-res khi kéo).**
///
/// Hai nguồn ảnh:
/// - `displayImage`: bản downsample (vd. 2048px) — xem vừa khung / zoom thấp, tức thì.
/// - `fullImage`: ảnh gốc `CIImage` **lazy** — khi **zoom sâu**, render đúng độ phân
///   giải thật (ROI lúc đó chỉ là một mẩu nhỏ).
///
/// Vì sao kéo slider KHÔNG lag dù vẫn *full-res*:
/// 1. `CIContext.render` (gồm giải mã JPEG vùng nhìn thấy) chạy trên **hàng đợi nền**,
///    ghi vào **một texture trung gian** — KHÔNG khóa main thread.
/// 2. Render xong, main thread chỉ **blit** (copy texture → drawable) cực rẻ rồi
///    present. `currentDrawable` chỉ dùng trên main (đáng tin).
/// 3. Mọi giá trị zoom trung gian được **gộp** về giá trị mới nhất → không dồn frame.
///
/// > ⚠️ iOS **Simulator** dùng Metal phần mềm, đường render-ngoài-main này có thể
/// > không hiển thị. Hãy chạy trên **máy thật** để kiểm chứng. Trên main branch là
/// > bản proxy (mượt ở cả simulator).
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
        view.framebufferOnly = false        // drawable làm đích blit
        view.isOpaque = true
        view.isPaused = true
        view.enableSetNeedsDisplay = true   // ta gọi setNeedsDisplay() để blit trên main
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

        if changed { c.setNeedsRender() }
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

        /// Texture đã render xong (sẵn sàng blit). Chỉ chạm trên main.
        private var latestTexture: MTLTexture?
        private var isRendering = false
        private var pendingRender = false

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
            setNeedsRender()
        }

        // MARK: Render nặng (off-main) → texture trung gian

        /// Gọi trên MAIN. Gộp các yêu cầu liên tiếp về một lần render mới nhất.
        func setNeedsRender() {
            guard !isRendering else { pendingRender = true; return }

            guard let view, let device, let ciContext, let commandQueue else { return }
            let dst = view.drawableSize
            let w = Int(dst.width), h = Int(dst.height)
            guard w > 0, h > 0 else { return }

            let useFull = zoom > fullResZoomThreshold
            let source = (useFull ? fullImage : displayImage) ?? fullImage ?? displayImage
            guard let source else { return }

            let filter = self.filter
            let zoom = self.zoom
            let offset = self.offset
            let pointScale = view.contentScaleFactor

            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: view.colorPixelFormat, width: w, height: h, mipmapped: false)
            desc.usage = [.shaderRead, .renderTarget]
            desc.storageMode = .private
            guard let target = device.makeTexture(descriptor: desc) else { return }

            isRendering = true
            renderQueue.async { [weak self] in
                guard let self else { return }
                autoreleasepool {
                    let filtered = self.filters.apply(filter, to: source)
                    let src = filtered.extent
                    guard src.width > 0, src.height > 0,
                          let commandBuffer = commandQueue.makeCommandBuffer() else {
                        self.finishRender(nil)
                        return
                    }

                    let baseScale = min(CGFloat(w) / src.width, CGFloat(h) / src.height)
                    let scale = baseScale * max(zoom, 1)
                    let scaled = filtered.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    let s = scaled.extent
                    let dx = offset.width  * pointScale
                    let dy = offset.height * pointScale
                    let tx = (CGFloat(w) - s.width)  / 2 - s.origin.x + dx
                    let ty = (CGFloat(h) - s.height) / 2 - s.origin.y - dy
                    let centered = scaled.transformed(by: CGAffineTransform(translationX: tx, y: ty))

                    self.ciContext?.render(
                        centered,
                        to: target,
                        commandBuffer: commandBuffer,
                        bounds: CGRect(x: 0, y: 0, width: w, height: h),
                        colorSpace: self.colorSpace
                    )
                    commandBuffer.addCompletedHandler { [weak self] _ in
                        self?.finishRender(target)
                    }
                    commandBuffer.commit()
                }
            }
        }

        private func finishRender(_ texture: MTLTexture?) {
            DispatchQueue.main.async {
                if let texture {
                    self.latestTexture = texture
                    self.view?.setNeedsDisplay()
                }
                self.isRendering = false
                if self.pendingRender {
                    self.pendingRender = false
                    self.setNeedsRender()
                }
            }
        }

        // MARK: Blit lên drawable (MAIN, rất rẻ)

        func draw(in view: MTKView) {
            guard let commandQueue,
                  let texture = latestTexture,
                  let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            // Kích thước phải khớp để blit; nếu lệch (vừa đổi size) thì render lại.
            guard texture.width == drawable.texture.width,
                  texture.height == drawable.texture.height else {
                setNeedsRender()
                return
            }

            guard let blit = commandBuffer.makeBlitCommandEncoder() else { return }
            blit.copy(
                from: texture,
                sourceSlice: 0, sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                to: drawable.texture,
                destinationSlice: 0, destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
            )
            blit.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
