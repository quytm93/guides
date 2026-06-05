import SwiftUI

/// Sheet chọn một ảnh test đóng gói sẵn — dùng chung cho tab Chỉnh ảnh & Metal.
struct TestImagePickerSheet: View {
    let onPick: (TestImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var images: [TestImage] = []

    var body: some View {
        NavigationStack {
            List(images) { image in
                Button {
                    onPick(image)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Thumbnail(image: image)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(image.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(image.subtitle)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Ảnh test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") { dismiss() }
                }
            }
            .overlay {
                if images.isEmpty {
                    ContentUnavailableView(
                        "Không có ảnh test",
                        systemImage: "photo.on.rectangle",
                        description: Text("Thêm file .jpg vào Resources/TestImages.")
                    )
                }
            }
        }
        .task { images = TestImageStore.all() }
    }
}

private struct Thumbnail: View {
    let image: TestImage
    @State private var ui: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let ui {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
        .task {
            let img = image
            ui = await Task.detached(priority: .userInitiated) {
                TestImageStore.thumbnail(for: img)
            }.value
        }
    }
}
