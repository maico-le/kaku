# Kaku (書く)

Ứng dụng Flutter cá nhân luyện viết chữ Nhật (Hiragana, Katakana, Kanji JLPT N5 & N4) bằng cách **vẽ bằng ngón tay**, so khớp với thứ tự và hướng nét chuẩn từ **KanjiVG** rồi chấm đúng/sai từng nét theo thời gian thực.

Hoạt động hoàn toàn **offline**, không phụ thuộc backend.

---

## Tính năng chính
1. **3 hệ chữ Nhật Bản**:
   - **Hiragana**: 75 ký tự (Gojūon, Dakuten, Handakuten, âm ghép/ký tự nhỏ).
   - **Katakana**: 76 ký tự (Gojūon, Dakuten, Handakuten, trường âm ー, ký tự nhỏ).
   - **Kanji**: 245 Hán tự JLPT N5 & N4 với âm On, âm Kun, nghĩa tiếng Anh và số nét.
2. **3 chế độ luyện tập**:
   - **Xem mẫu (Demo)**: Hoạt ảnh vẽ từng nét theo thứ tự chuẩn, số thứ tự nét, nét đang vẽ có màu nổi bật, nút phát lại & điều chỉnh tốc độ (0.5x / 1.0x).
   - **Tô theo (Trace)**: Chữ mờ làm nền, gợi ý nhẹ điểm bắt đầu nhấp nháy cho nét kế tiếp.
   - **Tự viết (Recall)**: Ô trống hoàn toàn để kiểm tra trí nhớ.
3. **Chấm điểm thông minh & phân loại lỗi chi tiết**:
   - **Đúng nét**: Đổi sang màu xanh lá, thay bằng đường nét chuẩn mịn, rung nhẹ và phát âm thanh phản hồi.
   - **Sai thứ tự**: Phát hiện nét vẽ thuộc về một nét tương lai và thông báo: *"nét này là nét số X, phải viết sau"*.
   - **Sai hướng**: Phát hiện vẽ ngược chiều (ví dụ từ dưới lên thay vì từ trên xuống).
   - **Sai hình dạng / vị trí**: Báo nét chưa đúng vị trí hoặc hình dáng.
   - **Chạm nhầm**: Tự động bỏ qua các cú chạm quá ngắn vô ý.
   - **Tự động gợi ý sau 3 lần sai liên tiếp** ở cùng một nét.
4. **Tiến độ & Thống kê**:
   - Lưu trữ qua SharedPreferences theo từng ký tự: số lần luyện, số lần hoàn thành sạch, tỉ lệ nét đúng, ngày giờ luyện.
   - Mức thành thạo: Chưa luyện (viền xám), Đang luyện (viền vàng), Thuộc (viền xanh lá khi hoàn thành sạch ở chế độ Tự viết ít nhất 3 lần).
   - Màn hình thống kê: số chữ đã luyện hôm nay, số chữ thuộc từng hệ chữ, danh sách các chữ hay sai nhất kèm nút "Luyện các chữ này".
5. **Cài đặt & Tùy biến**:
   - 3 cấp độ khó chấm nét: Dễ (Easy), Vừa (Medium - Mặc định), Chặt (Strict).
   - 4 kiểu lưới tham chiếu: Chữ thập + chéo (Mễ tự cách), Chỉ chữ thập, Lưới 9 ô (Cửu cung cách), Không lưới.
   - Độ dày nét vẽ (3px - 9px).
   - Bật/tắt rung (Haptic feedback) và âm thanh.
   - Chế độ Sáng / Tối (Dark / Light) hoặc theo hệ thống.
   - Xóa toàn bộ dữ liệu tiến độ.

---

## Cách chạy dự án

### 1. Cài đặt môi trường
- Flutter SDK (>= 3.13)
- Python 3.10+ (cho script tiền xử lý nếu cần tạo lại dữ liệu)

### 2. Chạy ứng dụng
```bash
flutter pub get
flutter run
```

### 3. Kiểm tra code & Chạy kiểm thử
```bash
flutter analyze
flutter test
```

---

## Hướng dẫn Tiền xử lý & Thêm tập chữ mới

Dữ liệu nét vẽ đã được trích xuất sẵn vào thư mục `assets/data/`:
- `hiragana.json` (75 chữ, 148 KB)
- `katakana.json` (76 chữ, 147 KB)
- `kanji_n5.json` (79 chữ, 303 KB)
- `kanji_n4.json` (166 chữ, 926 KB)

### Cách chạy script tiền xử lý:
Cần cài đặt thư viện python:
```bash
pip install svg.path requests
python tools/build_data.py
```
Script sẽ tự động tải bản phát hành KanjiVG mới nhất, parse các đường cong Bezier trong SVG thành polyline 40 điểm đều theo độ dài cung (arc length) trong tọa độ 109x109 và xuất file JSON tối ưu.

### Cách thêm một cấp Kanji mới (ví dụ JLPT N3, N2, N1):
1. Trong file `tools/build_data.py`, thêm level mong muốn (ví dụ `N3`) và endpoint danh sách kanji tương ứng từ `kanjiapi.dev/v1/kanji/jlpt-3`.
2. Chạy `python tools/build_data.py` để sinh ra file `assets/data/kanji_n3.json`.
3. Thêm `'N3'` vào mảng `kanjiLevels` trong `lib/data/character_repository.dart`:
   ```dart
   const kanjiLevels = ['N5', 'N4', 'N3'];
   ```
Ứng dụng sẽ tự động nạp cấp mới và cho phép lọc trên giao diện Kanji.

---

## Cách điều chỉnh ngưỡng chấm nét

Các ngưỡng so khớp được đặt trong file [`lib/core/constants.dart`](lib/core/constants.dart) tại class `MatchThresholds`:
- `maxStartEndDist`: Khoảng cách tối đa cho phép của điểm đầu và điểm cuối (tọa độ chuẩn 109x109).
- `maxMeanDist`: Khoảng cách trung bình giữa các điểm tương ứng.
- `maxFrechetDist`: Khoảng cách Fréchet rời rạc tối đa (chặt chẽ theo hình dáng đường cong).
- `minLengthRatio` & `maxLengthRatio`: Khoảng tỉ lệ độ dài cung cho phép.
- `maxAngleDiffRad`: Độ lệch góc vector định hướng tối đa.

Người dùng có thể chuyển đổi giữa 3 cấp độ (Dễ / Vừa / Chặt) trực tiếp trong menu **Cài đặt**.

---

## Ghi công dữ liệu & Bản quyền (Credits)

Dự án tuân thủ nghiêm ngặt giấy phép dữ liệu mở:
- **KanjiVG**: Bản quyền © 2009-2026 Ulrich Apel. Dữ liệu nét chữ SVG phát hành theo giấy phép [Creative Commons Attribution-Share Alike 3.0 (CC BY-SA 3.0)](https://creativecommons.org/licenses/by-sa/3.0/). Trang chủ: [https://kanjivg.tagaini.net/](https://kanjivg.tagaini.net/).
- **KANJIDIC2 & kanjiapi.dev**: Bản quyền Electronic Dictionary Research and Development Group (EDRDG). Phát hành theo giấy phép CC BY-SA 3.0.
- **Font Noto Sans JP**: Bản quyền Google Fonts, phát hành theo giấy phép SIL Open Font License (OFL).
