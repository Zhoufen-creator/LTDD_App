# Parental Control - Ứng dụng Quản lý & Bảo vệ Trẻ em (Flutter App)

Ứng dụng di động đa nền tảng (ưu tiên Android) phục vụ hệ thống giám sát, quản lý và bảo vệ an toàn cho trẻ em (Parental Control). Được phát triển bằng **Flutter 3.47.4** & **Dart 3.13.3**, hỗ trợ hai chế độ hoạt động tách biệt: **Chế độ Phụ huynh (Parent Mode)** và **Chế độ Trẻ em (Child Mode)**.

---

## Mục lục

1. [Tính năng nổi bật](#1-tính-năng-nổi-bật)
2. [Yêu cầu hệ thống](#2-yêu-cầu-hệ-thống)
3. [Cấu trúc mã nguồn](#3-cấu-trúc-mã-nguồn)
4. [Clone repository & Cài đặt thư viện](#4-clone-repository--cài-đặt-thư-viện)
5. [Cấu hình API Base URL](#5-cấu-hình-api-base-url)
6. [Chạy ứng dụng trong môi trường phát triển (Debug)](#6-chạy-ứng-dụng-trong-môi-trường-phát-triển-debug)
7. [Build file APK Release cho Android](#7-build-file-apk-release-cho-android)
8. [Cài đặt file APK lên điện thoại thật](#8-cài-đặt-file-apk-lên-điện-thoại-thật)
9. [Kiểm thử tự động (Linting & Tests)](#9-kiểm-thử-tự-động-linting--tests)
10. [Xử lý sự cố thường gặp (Troubleshooting)](#10-xử-lý-sự-cố-thường-gặp-troubleshooting)

---

## 1. Tính năng nổi bật

### 👨‍👩‍👧 Chế độ Phụ huynh (Parent Mode)
- **Đa dạng hình thức xác thực**: Đăng nhập Email/Password, xác thực OTP qua email, đăng nhập nhanh với tài khoản Google (Google Sign-In), đăng nhập bằng vân tay/khuôn mặt (Sinh trắc học - Biometrics).
- **Quản lý hồ sơ trẻ em**: Thêm mới, chỉnh sửa thông tin hồ sơ và ảnh đại diện của từng trẻ.
- **Ghép đôi thiết bị bằng mã QR**: Sinh mã QR vé liên kết (`Pairing Ticket`) động có thời hạn 5 phút để quét và kích hoạt máy trẻ em.
- **Định vị GPS thời gian thực**: Xem vị trí hiện tại của thiết bị trẻ em trên bản đồ, xem lịch sử di chuyển và gửi yêu cầu làm mới vị trí tức thời.
- **Theo dõi pin & trạng thái**: Cập nhật phần trăm pin và tình trạng sạc thời gian thực.
- **Quản lý quy tắc sử dụng (Monitoring Rules)**: Thiết lập giới hạn thời lượng mở app mỗi ngày, cấu hình khung giờ giới nghiêm (Bedtime), và chặn ứng dụng theo lịch tuần.
- **Phê duyệt yêu cầu từ xa**: Nhận thông báo và phê duyệt/từ chối khi trẻ em yêu cầu đổi chế độ, gỡ ứng dụng hoặc mở khóa tạm thời. Hỗ trợ mã PIN / Sinh trắc học để mở khóa trực tiếp (`Direct Unlock`).
- **Cố vấn an toàn (Safety Advisor)**: Phân tích thói quen sử dụng, đưa ra cảnh báo khi phát hiện bất thường và khuyến nghị cấu hình phù hợp.

### 🧒 Chế độ Trẻ em (Child Mode)
- **Kích hoạt tự động**: Quét mã QR từ máy phụ huynh để tự động ghi danh và nhận thiết bị token an toàn.
- **Khóa bảo vệ chế độ**: Sau khi kích hoạt, thiết bị tự động lưu cấu hình và khóa chặt trong Chế độ Trẻ em qua `flutter_secure_storage`. Trẻ không thể tự ý thoát nếu không có sự phê duyệt của phụ huynh.
- **Đồng bộ ngầm định kỳ**: Chạy service nền định kỳ 20 phút tự động ghi nhận và gửi tọa độ GPS, mức pin, và log đóng/mở ứng dụng theo lô lên máy chủ.
- **Thực thi quy tắc cục bộ**: Tự động cảnh báo và ngăn chặn khi trẻ vượt quá thời lượng sử dụng hoặc truy cập vào khung giờ bị cấm.

---

## 2. Yêu cầu hệ thống

Trước khi chạy hoặc build ứng dụng, đảm bảo môi trường phát triển của bạn đáp ứng:

- **Flutter SDK**: Phiên bản **3.47.4** (kênh `stable`)  
  *Kiểm tra:* `flutter --version`
- **Dart SDK**: Phiên bản **3.13.3** (tự động đi kèm theo Flutter)
- **Java Development Kit (JDK)**: OpenJDK 17 hoặc 21 (khuyến nghị JDK tích hợp sẵn trong Android Studio)
- **Android Studio / Android SDK**:
  - Android SDK Platform: API level **34** hoặc **35**
  - Android SDK Build-Tools: `34.0.0` hoặc `35.0.0`
  - Android SDK Command-line Tools
- **Thiết bị kiểm thử**:
  - Android Emulator (API 30+) **hoặc**
  - Điện thoại Android thật (Android 8.0 trở lên, bật USB Debugging)

---

## 3. Cấu trúc mã nguồn

```text
tran_nguyen_vi_khang_app/
├── android/                      # Native Android project (Gradle, AndroidManifest, icons)
├── ios/                          # Native iOS project
├── lib/
│   ├── constants/
│   │   └── api_constants.dart    # Quản lý Base URL, Endpoints, Compile-time variables
│   ├── models/                   # Data models (User, Child, Device, Activity, Location, Rule,...)
│   ├── providers/                # Quản lý trạng thái (State Management) bằng Provider:
│   │   ├── auth_provider.dart    # Quản lý Auth, Session, Google Sign-In, Biometrics
│   │   ├── child_provider.dart   # Quản lý Trẻ em, Thiết bị, Vị trí, Hoạt động, Quy tắc
│   │   └── theme_provider.dart   # Quản lý Dark/Light mode
│   ├── screens/                  # Giao diện các màn hình (Auth, Parent Dashboard, Child Mode,...)
│   ├── services/                 # Xử lý gọi API HTTP, Local Storage, GPS, Pin, Biometrics
│   ├── widgets/                  # Các UI components tái sử dụng (Dialogs, Cards, Badges,...)
│   └── main.dart                 # Điểm khởi chạy ứng dụng Flutter
├── test/                         # 136 automated unit & widget tests
├── pubspec.yaml                  # Khai báo dependencies, assets và siêu dữ liệu
└── README.md                     # Hướng dẫn chi tiết dự án
```

---

## 4. Clone repository & Cài đặt thư viện

### Bước 4.1: Clone repository

```powershell
git clone <URL_FLUTTER_REPOSITORY> tran_nguyen_vi_khang_app
cd tran_nguyen_vi_khang_app
```

### Bước 4.2: Tải các gói phụ thuộc (Dependencies)

```powershell
flutter pub get
```

### Bước 4.3: Kiểm tra môi trường phát triển

```powershell
flutter doctor
```

Đảm bảo các mục `Flutter`, `Android toolchain`, và `Connected device` đều có dấu tích xanh `[✓]`.

---

## 5. Cấu hình API Base URL

Ứng dụng sử dụng cơ chế compile-time variable của Flutter thông qua class `ApiConstants`:
```dart
static const String _envBaseUrl = String.fromEnvironment('BASE_URL');
```

Địa chỉ API của Backend được truyền vào thông qua cờ `--dart-define=BASE_URL=...` khi chạy hoặc build.

### URL Backend Internet hiện tại (Conveyor Tunnel)
```text
https://differentaquahouse65.conveyor.cloud
```

### Quy tắc chuẩn hóa URL tự động trong code
- Tự động cắt bỏ dấu gạch chéo `/` ở cuối URL để tránh lỗi `//`.
- Tự động cắt bỏ `/api` nếu người dùng lỡ nhập thừa, vì toàn bộ endpoint trong ứng dụng đã có sẵn tiền tố `/api/`.
- **Trong chế độ Release**: Bắt buộc phải truyền `--dart-define=BASE_URL=...`. Nếu thiếu, ứng dụng sẽ ném ngoại lệ `StateError` và dừng lại ngay lập tức (không âm thầm quay về `localhost`).

> [!IMPORTANT]
> **Lưu ý về `localhost` trên điện thoại Android thật:**  
> Nếu bạn nhập `http://localhost:5153` trên điện thoại thật, địa chỉ này sẽ trỏ về chính con chip trên chiếc điện thoại (`127.0.0.1`), chứ **không phải máy tính đang chạy backend**. Do đó, khi chạy hoặc build cho điện thoại thật, **bắt buộc** phải sử dụng URL Conveyor (`https://differentaquahouse65.conveyor.cloud`) hoặc địa chỉ IP LAN của máy tính.

---

## 6. Chạy ứng dụng trong môi trường phát triển (Debug)

### 6.1. Kiểm tra danh sách thiết bị đang kết nối

```powershell
flutter devices
```

### 6.2. Chạy trên Android Emulator

Nếu backend đang chạy trên máy tính cùng cổng `5153`, Android Emulator có thể truy cập qua loopback nội bộ `http://10.0.2.2:5153`:

```powershell
# Cách 1: Sử dụng fallback mặc định của Emulator
flutter run

# Cách 2: Trỏ thẳng qua Conveyor Internet (Khuyến nghị để đồng nhất với điện thoại thật)
flutter run --dart-define=BASE_URL=https://differentaquahouse65.conveyor.cloud
```

### 6.3. Chạy trên Điện thoại Android thật qua cáp USB

1. Trên điện thoại, vào **Cài đặt** -> **Thông tin điện thoại** -> Nhấn 7 lần vào **Số bản dựng (Build Number)** để mở khóa *Tùy chọn cho nhà phát triển*.
2. Bật mục **Gỡ lỗi USB (USB Debugging)**.
3. Cắm cáp USB nối điện thoại với máy tính. Trên màn hình điện thoại, chọn **Cho phép gỡ lỗi USB từ máy tính này**.
4. Chạy lệnh:
   ```powershell
   flutter run --dart-define=BASE_URL=https://differentaquahouse65.conveyor.cloud
   ```

---

## 7. Build file APK Release cho Android

Để cài đặt ứng dụng độc lập lên hai điện thoại thật (một máy đóng vai trò Phụ huynh, một máy đóng vai trò Trẻ em), hãy build file APK Release hoàn chỉnh:

```powershell
flutter build apk --release --dart-define=BASE_URL=https://differentaquahouse65.conveyor.cloud
```

Quá trình biên dịch sẽ tối ưu hóa bytecode, nén assets, tạo file APK Release tại đường dẫn:

```text
build/app/outputs/flutter-apk/app-release.apk
```

> [!WARNING]
> Giá trị `--dart-define=BASE_URL` được biên dịch trực tiếp vào nhị phân của APK. Nếu URL Conveyor thay đổi (ví dụ khi khởi động lại tunnel được cấp URL mới), bạn phải chạy lại lệnh build APK ở trên với URL mới.

---

## 8. Cài đặt file APK lên điện thoại thật

### Cách 1: Cài đặt trực tiếp qua cáp USB bằng lệnh ADB (Nhanh nhất)

Khi điện thoại đang cắm cáp USB và đã bật USB Debugging:

```powershell
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Cách 2: Sao chép thủ công file APK sang điện thoại

1. Cắm điện thoại vào máy tính qua chế độ *Truyền file (File Transfer / MTP)*.
2. Sao chép file `build/app/outputs/flutter-apk/app-release.apk` vào thư mục **Download** của điện thoại (hoặc gửi qua Zalo / Google Drive / Telegram).
3. Mở ứng dụng **Quản lý file (Files)** trên điện thoại, bấm vào file `app-release.apk` để cài đặt.
4. Nếu Android hiển thị cảnh báo bảo mật, chọn **Cài đặt từ nguồn không xác định** và bấm **Tiếp tục cài đặt**.

### Kịch bản kiểm thử Demo 2 máy:
1. **Máy 1 (Máy bố mẹ)**: Cài APK, mở app, đăng nhập tài khoản Phụ huynh, tạo một hồ sơ Trẻ em, bấm vào nút **Mã QR ghép đôi**.
2. **Máy 2 (Máy trẻ em)**: Cài APK, mở app, chọn chế độ **Trẻ em**, bấm nút quét mã và quét mã QR đang hiển thị trên Máy 1.
3. Cả hai thiết bị sẽ tự động liên kết thành công, Máy 1 hiển thị ngay vị trí GPS và tình trạng pin của Máy 2!

---

## 9. Kiểm thử tự động (Linting & Tests)

Dự án tuân thủ nghiêm ngặt chuẩn code chất lượng cao, có sẵn 136 bài test tự động bao phủ toàn bộ luồng nghiệp vụ.

### Kiểm tra phân tích tĩnh (Static Analysis)
```powershell
flutter analyze
```
*Kết quả yêu cầu:* `No issues found!`

### Chạy toàn bộ Test Suite
```powershell
flutter test
```
*Kết quả yêu cầu:* `All 136 tests passed!`

Các bộ test chính:
- `safety_advisor_test.dart`: Kiểm thử thuật toán phân tích và hiển thị thẻ Cố vấn an toàn
- `qr_child_mode_test.dart`: Kiểm thử vòng đời quét QR, ghi danh thiết bị và đồng bộ ngầm
- `biometric_login_test.dart`: Kiểm thử đăng nhập sinh trắc học và xử lý thiết bị chưa cài đặt vân tay

---

## 10. Xử lý sự cố thường gặp (Troubleshooting)

| Hiện tượng | Nguyên nhân | Cách khắc phục |
|---|---|---|
| Mở app bị crash ngay ở bản Release | Quên truyền `BASE_URL` khi build | Kiểm tra lại lệnh build. Bắt buộc phải có `--dart-define=BASE_URL=https://...` |
| Lỗi `Connection refused` hoặc mạng xoay vòng | Điện thoại dùng `localhost` hoặc backend chưa chạy | Kiểm tra xem backend và Conveyor có đang chạy không. Mở trình duyệt điện thoại truy cập thử `https://differentaquahouse65.conveyor.cloud/health` |
| Lệnh `flutter run` báo `No connected devices found` | Chưa bật USB Debugging hoặc dây cáp lỏng | Đổi cổng USB, bật lại Gỡ lỗi USB, chạy lệnh `adb devices` để kiểm tra máy nhận chưa |
| Quét QR không nhận | Camera chưa cấp quyền hoặc mã QR hết hạn | Vào Cài đặt cấp quyền Camera cho app; trên máy bố mẹ bấm sinh mã QR mới (mỗi mã có hạn 5 phút) |
| Không mở được xác thực vân tay | Máy chưa cài vân tay trong Cài đặt Android | Vào *Cài đặt hệ thống của điện thoại* -> *Bảo mật* -> Thêm ít nhất 1 dấu vân tay trước khi bật trong app |
