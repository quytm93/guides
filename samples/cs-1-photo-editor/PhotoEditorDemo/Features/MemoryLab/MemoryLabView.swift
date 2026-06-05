import SwiftUI

struct MemoryLabView: View {
    @State private var model = MemoryLabModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Ảnh nguồn") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Độ phân giải")
                            Spacer()
                            Text("\(Int(model.sourceMegapixels)) MP")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $model.sourceMegapixels, in: 6...48, step: 2)
                        Text(model.sourceInfo)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await model.generateSource() }
                    } label: {
                        if model.isGenerating {
                            ProgressView()
                        } else {
                            Label("Tạo ảnh nguồn", systemImage: "photo.badge.plus")
                        }
                    }
                    .disabled(model.isGenerating)
                }

                Section("Chạy thử") {
                    Button(role: .destructive) {
                        model.runNaive()        // đồng bộ → UI sẽ đứng vài giây
                    } label: {
                        Label("❌ Cách sai: full-res, main thread", systemImage: "exclamationmark.triangle")
                    }
                    .disabled(!model.hasSource || model.isWorking)

                    Button {
                        Task { await model.runOptimized() }
                    } label: {
                        if model.isWorking {
                            ProgressView()
                        } else {
                            Label("✅ Cách đúng: downsample, off-main", systemImage: "checkmark.seal")
                        }
                    }
                    .disabled(!model.hasSource || model.isWorking)

                    Text("Mẹo: bấm nút \"sai\" và thử kéo/chạm màn hình — UI đứng hình. Nút \"đúng\" thì mượt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !model.results.isEmpty {
                    Section("Kết quả (mới nhất ở trên)") {
                        ForEach(model.results) { result in
                            ResultRow(result: result)
                        }
                    }
                }
            }
            .navigationTitle("Memory Lab")
        }
    }
}

private struct ResultRow: View {
    let result: MemoryLabModel.Result

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(result.isCorrectWay ? .green : .red)
            HStack {
                metric("Bộ nhớ tăng", String(format: "+%.0f MB", result.deltaMB))
                Spacer()
                metric("Thời gian", String(format: "%.0f ms", result.duration * 1000))
                Spacer()
                metric("Output", result.outputPixels)
            }
        }
        .padding(.vertical, 4)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium)).monospacedDigit()
        }
    }
}

#Preview {
    MemoryLabView()
}
