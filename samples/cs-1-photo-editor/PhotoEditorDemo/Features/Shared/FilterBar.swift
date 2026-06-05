import SwiftUI

/// Thanh chọn filter dùng chung cho cả tab Chỉnh ảnh và Metal Preview.
struct FilterBar: View {
    let selection: PhotoFilter
    let onSelect: (PhotoFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PhotoFilter.allCases) { filter in
                    Button {
                        onSelect(filter)
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selection == filter ? Color.accentColor : Color(.secondarySystemBackground),
                                        in: Capsule())
                            .foregroundStyle(selection == filter ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
