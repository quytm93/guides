# CS-1 · AI Photo Editor — Sample Project

Dự án mẫu chạy được cho **Case Study #1** trong khóa học. Một trình chỉnh ảnh
**on-device** kiểu SnapEdit, dùng để minh họa các **cạm bẫy hiệu năng & bộ nhớ**
khi xử lý ảnh độ phân giải cao trên iOS — và cách làm đúng.

> Toàn bộ chạy ngay trên máy: **không cần server, không API key, không tài khoản.**
> Chạy được trên **Simulator**.

---

## Tải về & chạy

```bash
git clone <repo>
cd samples/cs-1-photo-editor
open PhotoEditorDemo.xcodeproj
```

Trong Xcode (cần **Xcode 16+**, project nhắm **iOS 17.0+**):

1. Chọn simulator bất kỳ (vd. *iPhone 17 Pro*).
2. Bấm **Run** (⌘R).

Hoặc build bằng dòng lệnh:

```bash
xcodebuild -scheme PhotoEditorDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

> Chạy trên máy thật: chọn target → tab *Signing & Capabilities* → đặt **Team** của bạn.

---

## 3 tab trong app

| Tab | Mục đích |
|---|---|
| **Chỉnh ảnh** | Chọn ảnh từ **thư viện**, **Ảnh test** (ảnh thật 17–51 MP kèm sẵn), hoặc *Ảnh mẫu*; áp filter Core Image, chia sẻ kết quả. Preview luôn được **downsample**. |
| **Memory Lab** | ⭐ Ngôi sao. Tạo ảnh tới **48MP** rồi so sánh **cách SAI vs cách ĐÚNG** — đo bộ nhớ tăng & thời gian xử lý ngay trên màn hình. |
| **Metal** | Tùy chọn 2: render ảnh **48MP** (synthetic) hoặc **Ảnh test** thật bằng `MTKView` + `CIContext`. **Pinch/kéo/slider để zoom** — chi tiết full-res hiện ra mà footprint chỉ ~vài chục MB. |
| **Bài học** | Tóm tắt 4 bài học + khi nào dùng ImageIO vs Metal. |

### Hai cách giữ footprint thấp với ảnh lớn
| Cách | Kỹ thuật | Dùng khi |
|---|---|---|
| **1 · Downsample (CPU)** — `ImageLoader` | ImageIO tạo thumbnail đúng kích thước | Cần ảnh **tĩnh** để hiển thị/share/lưu, thumbnail/lưới. Mất chi tiết gốc. |
| **2 · Metal (GPU)** — `MetalImageView` | `CIImage` lazy → `CIContext.render` vào drawable của `MTKView`, tile trên GPU | Cần **canvas tương tác**: zoom/pan thấy chi tiết full-res + filter realtime, vẫn ít RAM. |

> Editor thật dùng **cả hai**: Metal cho canvas khi chỉnh, rồi render full-res ra file chỉ ở bước **export**.
>
> **❌ Cách sai** (để đối chiếu): `UIImage(data:)` rồi vẽ full-res trên main thread → bitmap ~190 MB + UI đứng hình.

### Thử nghiệm zoom (tab Metal)
Tạo ảnh 48MP → kéo slider zoom lên **16×** → quan sát dòng *Footprint*: nó **nhích** lên
(render tile full-res vùng đang xem) nhưng vẫn nhỏ hơn nhiều so với bung cả ảnh.

### Cách dùng Memory Lab
1. Kéo thanh trượt lên **48 MP**, bấm **Tạo ảnh nguồn**.
2. Bấm **❌ Cách sai: full-res, main thread** → thử chạm/kéo màn hình: **UI đứng hình**, bộ nhớ tăng vọt (~+190 MB).
3. Bấm **✅ Cách đúng: downsample, off-main** → mượt, bộ nhớ gần như không đổi.
4. So hai dòng kết quả.

---

## Bài học rút ra (CS-1)

| # | Bài học | Code minh họa |
|---|---|---|
| 1 | **Downsample khi nạp** — đừng giữ bitmap full-res | [`ImageLoader.swift`](PhotoEditorDemo/Core/ImageIO/ImageLoader.swift) (ImageIO thumbnail) |
| 2 | **Xử lý ngoài main thread** — tránh hang | `Task.detached` trong [`MemoryLabModel`](PhotoEditorDemo/Features/MemoryLab/MemoryLabModel.swift) & [`EditorModel`](PhotoEditorDemo/Features/Editor/EditorModel.swift) |
| 3 | **Dùng lại một `CIContext`** | [`FilterService.swift`](PhotoEditorDemo/Features/Editor/FilterService.swift) |
| 4 | **Full-res chỉ khi export** — preview ở độ phân giải thấp | `previewMaxPixel` trong `EditorModel` |

Đo bộ nhớ thật bằng `phys_footprint`: [`MemoryReporter.swift`](PhotoEditorDemo/Core/Memory/MemoryReporter.swift).

---

## Kiến trúc

MVVM theo chuẩn nhà trường: **iOS 17+ · SwiftUI · `@Observable` · async/await · service tách protocol.**

```
PhotoEditorDemo/
  App/                  PhotoEditorDemoApp.swift · RootView.swift (TabView)
  Core/
    Memory/             MemoryReporter.swift      — đọc footprint
    ImageIO/            ImageLoader.swift          — downsample (cách 1)
                        SyntheticImage.swift       — tạo ảnh nặng để demo
    Metal/              MetalImageView.swift       — MTKView + CIContext (cách 2)
    TestImages/         TestImageStore.swift       — tìm ảnh test trong bundle
  Features/
    Editor/             EditorView · EditorModel · FilterService
    MemoryLab/          MemoryLabView · MemoryLabModel
    MetalPreview/       MetalPreviewView · MetalPreviewModel
    Shared/             FilterBar · TestImagePickerSheet (dùng chung)
    About/              AboutView
  Resources/
    TestImages/         ảnh thật .jpg kèm sẵn (17–51 MP)
  Resources/            Assets.xcassets
```

> Project dùng **synchronized folders** (Xcode 16+): thêm file `.swift` vào thư mục
> là Xcode tự nhận, không cần sửa `.pbxproj`.

## Mở rộng (gợi ý bài tập)
- Thêm **Vision** (`VNGeneratePersonSegmentationRequest`) để xóa/đổi nền.
- Export full-res bằng **tiling** thay vì downsample.
- Thêm **StoreKit 2** paywall (watermark cho bản free) như slide CS-1.
