import SwiftUI

struct MetalPreviewView: View {
    @State private var model = MetalPreviewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                canvas
                FilterBar(selection: model.filter) { filter in
                    model.filter = filter
                    model.updateFootprint()
                }
                controls
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
            .padding()
            .navigationTitle("Metal Preview")
            .task { model.updateFootprint() }
        }
    }

    private var canvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
            if let image = model.image {
                MetalImageView(image: image, filter: model.filter)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
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
        }
    }
}

#Preview {
    MetalPreviewView()
}
