# Hiệu năng & Sự cố nghiêm trọng — Danh mục theo triệu chứng

> AI viết được **cú pháp** trong vài giây. Việc khó là biết **app sẽ hỏng ở đâu**. Bản tra cứu các khái niệm gây **crash, bị hệ thống giết, ngốn bộ nhớ, treo UI, giật khung hình, tốn CPU/pin/đĩa/mạng** — xếp theo *triệu chứng*, khớp 7 nhóm số liệu của Xcode Organizer. Dùng để review code (của bạn hoặc do AI sinh ra). Không tập trung cú pháp.

## 🔍 Bộ công cụ phát hiện

| Công cụ | Bắt được gì |
|---|---|
| **Xcode Organizer** | 7 nhóm số liệu máy thật: Launches · Hangs · Hitches · Memory · Disk · Battery · Terminations |
| **MetricKit** | MXHangDiagnostic · MXDiskWriteExceptionDiagnostic · MXCPUExceptionDiagnostic · hitch · exit reasons |
| **Instruments** | Time Profiler · Allocations/Leaks · Animation Hitches · Hangs · Energy Log · Core Animation |
| **Main Thread Checker** | bắt cập nhật UI sai thread (bật khi Debug) |
| **Thread / Address Sanitizer** | bắt data race & truy cập bộ nhớ hỏng |
| **Memory Graph Debugger** | tìm retain cycle (đối tượng không giải phóng) |
| **Debug overlays** | Color Offscreen-Rendered Yellow · Color Blended Layers (soi hitch) |
| **ProcessInfo** | `thermalState` · `isLowPowerModeEnabled` để thích ứng |

## 📏 Số liệu Apple đo (ngưỡng đáng nhớ)

| Số liệu | Ngưỡng / ý nghĩa |
|---|---|
| **Hang rate** | main thread đơ; `>250ms` tính là 1 hang. |
| **Hitch rate** | ms khung rớt/giây: `<5` mượt · `5–10` tạm · `>10` tệ. |
| **Disk writes** | MetricKit cảnh báo khi `>1GB/ngày`. |
| **Launch time** | thời gian tới khung hình đầu (time-to-first-draw). |
| **Memory at suspend** | RAM khi vào nền — cao dễ bị jetsam. |
| **Terminations** | lý do thoát: crash · jetsam (OOM) · watchdog. |

## 🔴 Crash — app văng

**Phát hiện bằng:** Crash log (Xcode Organizer), Main Thread Checker, Thread Sanitizer

| Khái niệm | Vì sao nguy hiểm | Dấu hiệu | Cách tránh |
|---|---|---|---|
| Force-unwrap nil (`!`) | Văng tức thì “unexpectedly found nil”. | Crash log: Fatal error | Dùng `if let`/`guard let`/`??`; tránh `!` & `try!`. |
| Index ngoài mảng | “Index out of range” khi mảng rỗng/đổi. | Crash khi list rỗng | Kiểm tra `indices.contains`, dùng `first`/`last`. |
| Cập nhật UI ngoài main thread | UI hỏng/văng khó đoán. | Main Thread Checker (cảnh báo tím) | Đưa cập nhật UI về `@MainActor`. |
| Data race (đọc/ghi đồng thời) | EXC_BAD_ACCESS ngẫu nhiên, khó tái hiện. | Thread Sanitizer | Dùng `actor`/serial queue; bật strict concurrency. |
| `try!` / `as!` / `fatalError` | Văng khi giả định sai. | Crash log | Dùng `try?`/`do-catch`, `as?`. |

## ⚫ Bị hệ thống giết (terminations)

**Phát hiện bằng:** Xcode Organizer › Terminations, MetricKit exit reasons

| Khái niệm | Vì sao nguy hiểm | Dấu hiệu | Cách tránh |
|---|---|---|---|
| Watchdog `0x8badf00d` | Main thread bị chặn quá lâu lúc launch/resume/suspend → bị giết. | Termination reason 0x8badf00d | Không chặn main thread ở các mốc vòng đời; việc nặng làm async. |
| `0xdead10cc` (giữ lock khi vào nền) | Giữ file lock / SQLite lock lúc app bị treo ở nền. | Termination reason 0xdead10cc | Đóng/giải phóng lock & hoàn tất ghi trước khi vào nền; xin background task. |
| Jetsam (hết RAM) | Vượt giới hạn bộ nhớ → hệ thống thu hồi. | Không có stack, memory cao trước khi thoát | Giảm peak memory (xem nhóm Bộ nhớ): downsample, cache có hạn. |
| CPU cao khi ở nền | Chạy nặng lúc nền → bị chấm dứt. | Energy log nền cao | Dừng việc khi vào nền; dùng background task đúng cách. |

## 🟠 Rò rỉ & ngốn bộ nhớ

**Phát hiện bằng:** Memory Graph Debugger, Instruments › Leaks / Allocations

| Khái niệm | Vì sao nguy hiểm | Dấu hiệu | Cách tránh |
|---|---|---|---|
| Retain cycle (self giữ nhau) | Đối tượng không giải phóng → RAM tăng dần. | Memory Graph: object count chỉ tăng | `[weak self]` trong closure; `weak`/`unowned` cho delegate/parent. |
| Closure trong Task/Combine/timer giữ self mạnh | Leak ViewModel/màn hình đã đóng. | Object còn sống sau khi rời màn hình | `[weak self]`; hủy `Task`/cancellable. |
| Ảnh load full-resolution | Ảnh 48MP → RAM vọt, dễ OOM. | Allocations tăng đột biến | Downsample về đúng kích thước hiển thị trước khi vẽ. |
| Cache không giới hạn | Bộ nhớ phình theo thời gian dùng. | Memory tăng đều không tụt | Dùng `NSCache` + giới hạn số lượng/dung lượng. |
| Giữ dữ liệu lớn trong RAM | OOM khi dữ liệu lớn dần. | Allocations | Phân trang, stream, giải phóng khi rời màn hình. |

## 🟡 Treo UI (hangs)

**Phát hiện bằng:** Instruments › Hangs; Xcode Organizer › Hangs (hang rate)

| Khái niệm | Vì sao nguy hiểm | Dấu hiệu | Cách tránh |
|---|---|---|---|
| Việc nặng trên main thread | UI đứng tới khi xong; >250ms = 1 “hang” theo Apple. | Time Profiler: main ~100% | Đẩy việc nặng sang background; main chỉ làm UI. |
| I/O mạng/đĩa đồng bộ trên main | Freeze cho tới khi tải/đọc xong. | Hang khi mở màn hình | `async/await`; đọc file/mạng off-main. |
| Giải mã ảnh lớn trên main | Đứng khi mở màn hình ảnh. | Hangs | Decode off-main; `prepareForDisplay`. |
| `body` SwiftUI làm việc nặng | Tính lại mỗi render → đơ. | body re-evaluated nhiều | Giữ body nhẹ; đừng tạo `DateFormatter` trong body. |
| Tác vụ đồng bộ dài trong nút bấm | Bấm xong app đơ vài giây. | Hang sau thao tác | Bọc `Task { }`, hiện `ProgressView`. |

## 🟤 Giật khung hình (hitches)

**Phát hiện bằng:** Instruments › Animation Hitches; overlay Offscreen-Rendered / Blended Layers

| Khái niệm | Vì sao nguy hiểm | Dấu hiệu | Cách tránh |
|---|---|---|---|
| Offscreen rendering | `cornerRadius` + `masksToBounds`, shadow thiếu path → render pass phụ. | Overlay “Offscreen-Rendered Yellow” | Đặt `shadowPath`; tránh mask; dùng `cornerCurve`. |
| Decode/scale ảnh trong cell khi cuộn | Rớt frame mỗi lần cell hiện. | Hitch khi scroll | Decode & downsample off-main, cache sẵn. |
| Overdraw / blending | Nhiều lớp trong suốt chồng nhau, quá fill-rate. | Overlay “Blended Layers” | Đặt nền `opaque`; giảm lớp mờ. |
| Auto Layout phức tạp trong cell | Layout pass đắt mỗi frame. | Hitch khi cuộn list | Đơn giản layout; cache chiều cao; ô tự dựng. |
| Hitch rate cao | `<5ms/s` mượt · `5–10` tạm · `>10` tệ. | Xcode Organizer › Hitches | Đo & hạ hitch rate ở màn hình cuộn chính. |

## 🔵 CPU, pin & nhiệt

**Phát hiện bằng:** Instruments › Time Profiler & Energy Log; ProcessInfo.thermalState

| Khái niệm | Vì sao nguy hiểm | Dấu hiệu | Cách tránh |
|---|---|---|---|
| Vẽ lại thừa (body churn) | CPU cao cả khi đứng yên. | SwiftUI re-render đếm cao | Thu hẹp state; tách view nhỏ; `@Observable` đúng phạm vi. |
| Timer/loop chạy quá dày | Đốt CPU & pin liên tục. | Time Profiler | Giảm tần suất; dừng khi không cần. |
| Polling thay vì event | Hỏi liên tục → hao CPU/pin/mạng. | Energy log dày | Dùng push / async stream / callback. |
| Location accuracy cao luôn bật | Pin tụt nhanh. | Energy Log; biểu tượng location | Giảm accuracy; significant-change; tắt khi nền. |
| Bỏ qua nhiệt & Low Power Mode | Máy nóng bị throttle, app vẫn chạy hết ga. | `thermalState` = .serious/.critical | Theo dõi `ProcessInfo.thermalState` & `isLowPowerModeEnabled`, giảm tải. |

## 💾 Đĩa & I/O

**Phát hiện bằng:** MetricKit (disk write exception), Instruments › File Activity

| Khái niệm | Vì sao nguy hiểm | Dấu hiệu | Cách tránh |
|---|---|---|---|
| Ghi đĩa quá mức | MetricKit báo khi vượt `1GB/ngày`. | MXDiskWriteExceptionDiagnostic | Gộp/giảm ghi; chỉ ghi khi cần. |
| Log/analytics ghi liên tục | Hao đĩa & pin ngầm. | File Activity nhiều | Throttle/batch log; tắt log nặng ở Release. |
| Core Data/SwiftData autosave churn | Lưu quá thường xuyên. | Ghi DB liên tục | Batch thay đổi; lưu theo lô. |
| Ghi file lớn đồng bộ | Vừa block UI vừa tốn đĩa. | Hang + disk spike | Ghi nền, theo khối (chunk). |

## 🌐 Mạng

**Phát hiện bằng:** Instruments › Network; Energy Log (networking)

| Khái niệm | Vì sao nguy hiểm | Dấu hiệu | Cách tránh |
|---|---|---|---|
| Request lẻ tẻ liên tục | Mỗi lần bật sóng tốn overhead & pin. | Energy/Network log dày | Batch & gộp request; tải trước hợp lý. |
| Không nén / payload lớn | Tốn băng thông & thời gian. | Response lớn | Nén (gzip), ảnh đúng size, chỉ lấy field cần. |
| Không dùng cache (`URLCache`) | Tải lại dữ liệu không đổi. | Request lặp | Bật HTTP cache; `ETag`/`If-None-Match`. |
| Không timeout / không cancel | Treo chờ mạng; task thừa khi rời màn hình. | Spinner quay mãi | Đặt timeout; hủy `Task` khi view đóng. |
| Polling thay vì push | Đốt pin & mạng. | Request đều đặn | Dùng push / long-poll / socket khi hợp lý. |

## 🟣 Khởi động (launch)

**Phát hiện bằng:** Instruments › App Launch; Xcode Organizer › Launches

| Khái niệm | Vì sao nguy hiểm | Dấu hiệu | Cách tránh |
|---|---|---|---|
| Nhiều việc lúc launch | Trắng màn hình lâu; có thể bị watchdog kill khi launch. | App Launch instrument | Trì hoãn việc không cần; làm lười; nền hóa. |
| `init` View/Model nặng | Giật khi mở màn hình. | Hang khi push | Đưa việc nặng vào `.task`/`onAppear`. |
| Đọc/giải mã dữ liệu lớn đồng bộ khi mở | Freeze ngay đầu phiên. | Hangs đầu phiên | Async + placeholder trước. |
| Quá nhiều dynamic framework | Tăng thời gian pre-main. | Launch time cao | Giảm phụ thuộc; cân nhắc static link. |

## 🟢 Concurrency (Swift 6)

**Phát hiện bằng:** Thread Sanitizer; cảnh báo strict concurrency của trình biên dịch

| Khái niệm | Vì sao nguy hiểm | Dấu hiệu | Cách tránh |
|---|---|---|---|
| Thiếu `@MainActor` cho UI state | Cập nhật UI sai thread → lỗi/crash. | Cảnh báo Swift 6 | Đánh dấu `@MainActor` cho ViewModel/UI. |
| Sai actor isolation | Data race khi chia sẻ state. | Lỗi strict concurrency | Thiết kế theo `actor`; tuân thủ `Sendable`. |
| Không cancel `Task` khi view biến mất | Việc thừa, leak, cập nhật view chết. | Task còn chạy sau khi đóng | Dùng `.task` (tự hủy) hoặc `cancel()`. |
| Chia sẻ mutable state giữa task | Race khó tái hiện. | Thread Sanitizer | Bọc trong actor; tránh biến toàn cục mutable. |

## ✅ Dùng thế nào

Khi review một màn hình / một PR (hoặc code AI vừa sinh), quét nhanh theo triệu chứng:

1. **Crash / Terminations** — force-unwrap? cập nhật UI sai thread? giữ lock khi vào nền? hết RAM?
2. **Bộ nhớ** — closure có `[weak self]`? ảnh có downsample? cache có giới hạn?
3. **Treo (hang) / Giật (hitch)** — việc nặng/I/O trên main? offscreen rendering khi cuộn?
4. **CPU/pin/nhiệt** — vẽ lại thừa? timer dày? location? có theo dõi `thermalState`?
5. **Đĩa / Mạng** — ghi đĩa nhiều? request lặp/không cache/không timeout?
6. **Khởi động / Concurrency** — việc nặng lúc launch? UI state có `@MainActor`? Task tự hủy?

## 📚 Nguồn tham khảo

- [Apple — Performance and metrics](https://developer.apple.com/documentation/xcode/performance-and-metrics)
- [Apple — Addressing watchdog terminations](https://developer.apple.com/documentation/xcode/addressing-watchdog-terminations)
- [WWDC20 — Diagnose performance issues with the Xcode Organizer](https://developer.apple.com/videos/play/wwdc2020/10076/)
- [WWDC21 — Ultimate application performance survival guide](https://developer.apple.com/videos/play/wwdc2021/10181/)
- [Tech Talk — Demystify and eliminate hitches in the render phase](https://developer.apple.com/videos/play/tech-talks/10857/)
- [Apple — Energy Efficiency Guide for iOS Apps](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/index.html)
