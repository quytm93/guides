import SwiftUI
import PhotosUI

struct EditorView: View {
    @State private var model = EditorModel()
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                imageArea
                FilterBar(selection: model.filter) { model.filter = $0 }
                sourceButtons
                Text(model.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Chỉnh ảnh")
            .toolbar {
                if let image = model.preview {
                    ToolbarItem(placement: .topBarTrailing) {
                        // Export = chia sẻ ảnh đã xử lý (chạy trên simulator).
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview("Ảnh đã chỉnh", image: Image(uiImage: image))
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private var imageArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary)
            if let image = model.preview {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ContentUnavailableView(
                    "Chưa có ảnh",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Chọn từ thư viện hoặc dùng ảnh mẫu.")
                )
            }
            if model.isWorking {
                ProgressView().controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sourceButtons: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Chọn ảnh", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                Task { await model.useSampleImage() }
            } label: {
                Label("Ảnh mẫu", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .onChange(of: pickerItem) { _, newItem in
            Task { await model.load(item: newItem) }
        }
    }
}

#Preview {
    EditorView()
}
