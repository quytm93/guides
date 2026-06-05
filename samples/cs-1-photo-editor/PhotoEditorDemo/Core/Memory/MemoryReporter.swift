import Foundation
import Darwin

/// Đọc *physical memory footprint* của tiến trình — đúng con số mà thước đo bộ
/// nhớ trong Xcode hiển thị. Dùng để chứng minh sự khác biệt giữa cách xử lý ảnh
/// "naive" và "downsample".
enum MemoryReporter {

    /// Footprint hiện tại (bytes). Trả 0 nếu truy vấn thất bại.
    static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return info.phys_footprint
    }

    /// "123,4 MB"
    static func mb(_ bytes: UInt64) -> String {
        String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}
