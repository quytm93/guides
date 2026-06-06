import SwiftUI

struct MetalPreviewView: View {
    @State private var model = MetalPreviewModel()

    // Trạng thái zoom/pan (UI state).
    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showTestPicker = false
    @State private var isInteracting = false

    private let maxZoom: CGFloat = 16

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                canvas
                FilterBar(selection: model.filter) { model.filter = $0 }
                if model.hasImage { zoomControls }
                controls
                footer
            }
            .padding()
            .navigationTitle("Metal Preview")
            .sheet(isPresented: $showTestPicker) {
                TestImagePickerSheet { testImage in
                    resetZoom()
                    Task { await model.load(testImage: testImage) }
                }
            }
            // Footprint cập nhật theo SỰ KIỆN (không poll liên tục): khi zoom đổi và
            // sau mỗi lần nạp ảnh (chờ render xong mới đọc). Tránh ép render lại liên tục.
            .task { model.updateFootprint() }
            // Cập nhật footprint khi NGỪNG tương tác (sau lần render full-res) — tránh
            // đọc/recompute mỗi frame lúc đang kéo slider.
            .onChange(of: isInteracting) { _, interacting in
                if !interacting {
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        model.updateFootprint()
                    }
                }
            }
            .onChange(of: model.info) { _, _ in
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    model.updateFootprint()
                }
            }
        }
    }

    private var canvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
            if model.hasImage {
                MetalImageView(displayImage: model.displayImage,
                               fullImage: model.fullImage,
                               filter: model.filter,
                               zoom: zoom,
                               offset: offset,
                               interactive: isInteracting)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .gesture(magnify.simultaneously(with: pan))
                    .onTapGesture(count: 2) { resetZoom() }
            } else {
                ContentUnavailableView(
                    "Chưa có ảnh",
                    systemImage: "cpu",
                    description: Text("Tạo ảnh lớn để xem Metal render mà vẫn ít RAM.")
                )
            }
            if model.isGenerating {
                ProgressView().controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cử chỉ

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                isInteracting = true
                zoom = min(max(lastZoom * value.magnification, 1), maxZoom)
            }
            .onEnded { _ in
                lastZoom = zoom
                if zoom == 1 { offset = .zero; lastOffset = .zero }
                isInteracting = false   // render full-res một lần cho nét
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard zoom > 1 else { return }   // chỉ kéo khi đã phóng to
                isInteracting = true
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in
                lastOffset = offset
                isInteracting = false
            }
    }

    private func resetZoom() {
        withAnimation(.easeOut(duration: 0.2)) {
            zoom = 1; lastZoom = 1; offset = .zero; lastOffset = .zero
        }
    }

    // MARK: - Điều khiển

    private var zoomControls: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "minus.magnifyingglass")
                Slider(value: $zoom, in: 1...maxZoom) { editing in
                    isInteracting = editing
                    if !editing { lastZoom = zoom; if zoom == 1 { offset = .zero; lastOffset = .zero } }
                }
                Image(systemName: "plus.magnifyingglass")
                Text(String(format: "%.0f×", zoom))
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
                    .foregroundStyle(.secondary)
            }
            Text("Pinch hoặc kéo thanh để zoom · kéo ảnh để di chuyển · chạm 2 lần để reset")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Độ phân giải nguồn")
                Spacer()
                Text("\(Int(model.sourceMegapixels)) MP")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $model.sourceMegapixels, in: 12...48, step: 4)
            Button {
                resetZoom()
                Task { await model.generate() }
            } label: {
                if model.isGenerating {
                    ProgressView()
                } else {
                    Label("Tạo & render ảnh \(Int(model.sourceMegapixels))MP", systemImage: "cpu")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isGenerating)

            Button {
                showTestPicker = true
            } label: {
                Label("Chọn ảnh test (ảnh thật)", systemImage: "photo.stack")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(model.isGenerating)
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text(model.info)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !model.footprintText.isEmpty {
                Label(model.footprintText, systemImage: "memorychip")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.green)
            }
        }
    }
}

#Preview {
    MetalPreviewView()
}
