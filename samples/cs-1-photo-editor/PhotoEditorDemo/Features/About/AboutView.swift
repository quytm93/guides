import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("CS-1 · AI Photo Editor") {
                    Text("Bản demo on-device cho case study #1. Mọi thứ chạy ngay trên máy — không cần server, API key hay tài khoản.")
                        .font(.callout)
                }

                Section("4 bài học hiệu năng") {
                    lesson("Downsample khi nạp",
                           "Đừng giữ bitmap full-res. Dùng ImageIO tạo thumbnail đúng kích thước màn hình → tiết kiệm hàng trăm MB.")
                    lesson("Xử lý ngoài main thread",
                           "Lọc ảnh nặng phải chạy trên background. Làm trên main thread = UI đứng hình (hang).")
                    lesson("Dùng lại CIContext",
                           "Tạo CIContext mới mỗi khung hình là lỗi kinh điển. Một context dùng chung cho cả app.")
                    lesson("Full-res chỉ khi export",
                           "Preview ở độ phân giải thấp; chỉ xử lý full-res (và nên tile) ở bước xuất ảnh cuối cùng.")
                }

                Section("Thử ngay") {
                    label("Memory Lab", "Tạo ảnh 48MP rồi so sánh cách sai vs đúng — xem bộ nhớ tăng bao nhiêu.")
                    label("Chỉnh ảnh", "Chọn ảnh hoặc dùng ảnh mẫu, áp filter Core Image, chia sẻ kết quả.")
                }

                Section {
                    Text("Khóa học iOS · Workshop")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Bài học")
        }
    }

    private func lesson(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(body)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func label(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.medium))
            Text(body).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AboutView()
}
