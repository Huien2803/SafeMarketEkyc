# Tài liệu QA Vấn đáp Khoá luận Tốt nghiệp — SafeMarket

> Tài liệu này chứa các câu hỏi hội đồng KLTN thường hỏi và câu trả lời mẫu.  
> **In ra giấy mang theo lúc vấn đáp**.  
> Trương Trí Hiền (23DH111023) & Lê Tấn Lộc (23DH111948) — HUFLIT 2026

---

## A. Câu hỏi về kiến trúc hệ thống

### A1. "Em hãy mô tả kiến trúc tổng quan của hệ thống?"

> Hệ thống của em sử dụng kiến trúc 3 tầng (3-tier architecture) phổ biến trong các app marketplace hiện đại:
>
> 1. **Tầng giao diện (Presentation)**: Ứng dụng di động viết bằng **Flutter** với Dart, chạy trên Android (và iOS nếu cần).
> 2. **Tầng nghiệp vụ (Business Logic)**: Backend REST API viết bằng **NestJS** (Node.js + TypeScript) chạy ở port 3000.
> 3. **Tầng dữ liệu (Data)**: **Microsoft SQL Server**, database tên `SafeMarketDB`.
>
> Giao tiếp giữa các tầng:
> - Flutter ↔ NestJS: qua HTTP/JSON, có xác thực JWT
> - NestJS ↔ SQL Server: qua driver `mssql` + TypeORM

### A2. "Tại sao em không cho Flutter kết nối thẳng vào SQL Server?"

> Em không làm vậy vì 3 lý do:
>
> 1. **Bảo mật**: Connection string phải có user/password DB. Nếu nằm trong code Flutter, khi app bị decompile sẽ lộ password, ai cũng truy cập được database.
> 2. **Mạng**: Port 1433 của SQL Server thường bị firewall chặn trên mạng di động 4G/5G.
> 3. **Khả năng mở rộng**: Có lớp API trung gian giúp em thêm tính năng JWT auth, validate input, rate limit... mà không cần sửa app client.

### A3. "Em chọn NestJS thay vì Express hoặc Spring Boot vì lý do gì?"

> Em chọn NestJS vì 4 lý do:
>
> 1. **Kiến trúc module hoá** rõ ràng (Module → Controller → Service), giống Angular và Spring Boot mà em đã học.
> 2. **TypeScript bắt buộc** giúp type-safe, ít bug khi viết code lớn.
> 3. **Swagger tự sinh** từ decorator, đỡ phải viết tài liệu API thủ công.
> 4. **Dependency Injection** tích hợp sẵn, dễ test và bảo trì.

### A4. "Em không dùng MongoDB như đề cương ghi, tại sao?"

> Trong đề cương ban đầu em đề xuất MongoDB để lưu log hành vi. Nhưng khi triển khai thực tế em đã quyết định dùng **SQL Server thuần** vì:
>
> 1. **Quản lý 1 hệ quản trị duy nhất** giảm độ phức tạp khi triển khai và demo.
> 2. **Bảng `Point_Logs`** trong SQL Server đã đáp ứng đủ nhu cầu lưu log với index tối ưu.
> 3. **ACID guarantees** của SQL Server quan trọng với các giao dịch tài chính.
> 4. Với quy mô đồ án, MongoDB không tạo ra lợi ích đáng kể.

---

## B. Câu hỏi về cơ sở dữ liệu

### B1. "Em hãy giải thích sơ đồ database?"

> Database `SafeMarketDB` em chia làm 5 schema theo nguyên tắc **Bounded Context** trong Domain-Driven Design:
>
> | Schema | Bảng | Vai trò |
> |--------|------|---------|
> | `Identity` | Users, eKYC_Profiles | Xác thực và định danh |
> | `Market` | Categories, Products, Product_Images | Sản phẩm rao bán |
> | `Finance` | Orders, Payments | Đơn hàng và thanh toán |
> | `Reputation` | Scores, Point_Logs, Reviews | Điểm tín nhiệm và đánh giá |
> | `Moderation` | Reports | Quản lý báo cáo vi phạm |
>
> Tổng cộng 11 bảng, có quan hệ 1-1, 1-n và n-n thông qua foreign key.

### B2. "Trigger SQL của em làm gì?"

> Em viết 4 trigger chính:
>
> 1. **`trg_InitializeReputation`** (AFTER INSERT trên Users): Khi đăng ký user mới, tự động tạo bản ghi `Scores` với 500 điểm, hạng Bronze.
> 2. **`trg_UpdateScoreAndRank`** (AFTER INSERT trên Point_Logs): Mỗi khi cộng/trừ điểm, tự cập nhật `Scores.current_point` (giới hạn 0-1000) và đổi hạng (Bronze < 300 < Silver < 600 < Gold < 850 < Diamond).
> 3. **`trg_SyncKycStatusOnVerify`** (AFTER UPDATE trên eKYC_Profiles): Khi admin set `verified_at`, tự đồng bộ `Users.kyc_status = 'Verified'`.
> 4. **`trg_ReportHighSeverityPenalty`** (AFTER INSERT trên Reports): Tự trừ 50 điểm khi user bị báo cáo nghiêm trọng.

### B3. "Tại sao em dùng trigger thay vì xử lý ở backend?"

> Em dùng trigger vì 3 lý do:
>
> 1. **Đảm bảo toàn vẹn dữ liệu**: Trigger chạy ngay trong transaction, không thể bị bỏ sót như nếu xử lý ở backend.
> 2. **Hiệu năng**: Trigger chạy trong database engine, không tốn round-trip mạng.
> 3. **Tách biệt nghiệp vụ**: Logic tính điểm thuộc về tầng dữ liệu (Reputation), nên đặt ở DB phù hợp hơn.

### B4. "Sao em chọn BIGINT cho user_id thay vì INT?"

> Vì BIGINT chứa được số lượng user lên đến 9.2 tỷ tỷ (2^63-1), đảm bảo hệ thống có thể scale sau này mà không phải migrate schema. INT chỉ chứa 2.1 tỷ là quá ít cho một marketplace.

---

## C. Câu hỏi về Authentication / Bảo mật

### C1. "Em lưu mật khẩu như thế nào?"

> Em **KHÔNG bao giờ lưu mật khẩu plaintext**. Trước khi lưu vào DB, em hash bằng **bcrypt** với 10 rounds.
>
> - Bcrypt là thuật toán hash mật khẩu chuẩn quốc tế, có **salt** ngẫu nhiên tự sinh.
> - 10 rounds nghĩa là thuật toán chạy 2^10 = 1024 vòng băm — đủ chậm để chống brute-force, vẫn đủ nhanh cho user.
> - Khi login, em dùng `bcrypt.compare()` so sánh mật khẩu nhập với hash đã lưu, không bao giờ decrypt.

### C2. "JWT là gì? Em dùng JWT làm gì?"

> JWT (JSON Web Token) là chuỗi token có 3 phần: **Header.Payload.Signature**, dùng để xác thực user mà không cần lưu session ở server.
>
> Luồng của em:
> 1. User login → server tạo JWT chứa `userId`, `email`, ký bằng secret key.
> 2. Server trả token về app, app lưu vào `SharedPreferences`.
> 3. Mọi request tiếp theo, app gửi kèm `Authorization: Bearer <token>`.
> 4. Server verify chữ ký bằng secret key → biết user là ai.
>
> Token của em hết hạn sau 7 ngày, sau đó user phải đăng nhập lại.

### C3. "JWT của em có an toàn không?"

> Em đảm bảo 3 điểm an toàn:
>
> 1. **Secret key dài, không hardcode trong code** mà nằm trong file `.env` (đã được gitignore).
> 2. **Hết hạn token** sau 7 ngày để giảm cửa sổ tấn công.
> 3. **Mỗi request kiểm tra `accountStatus`** — nếu admin đã khoá user, token cũ vẫn không dùng được nữa.

### C4. "Em chống được tấn công SQL Injection không?"

> Có, em chống được nhờ:
>
> 1. **TypeORM dùng parameterized query** mặc định. Mọi tham số đều được escape tự động.
> 2. **Class-validator** kiểm tra mọi input trước khi đến service: regex SĐT, định dạng email, độ dài mật khẩu.
> 3. **ValidationPipe(`whitelist: true`)** loại bỏ các field không khai báo trong DTO, tránh user gửi thêm trường gây lỗi.

### C5. "Sao em không dùng `flutter_secure_storage` mà dùng `SharedPreferences`?"

> Đúng là `flutter_secure_storage` (lưu vào Android Keystore) bảo mật hơn. Trong phạm vi đồ án em dùng `SharedPreferences` vì đơn giản hơn và đủ cho mức demo. Đây là **hướng phát triển em đã ghi trong báo cáo** — khi triển khai thật sẽ chuyển sang secure storage.

---

## D. Câu hỏi về eKYC

### D1. "eKYC của em hoạt động thế nào?"

> Luồng eKYC gồm 3 bước:
>
> 1. **Quét CCCD/Hộ chiếu**: User chụp ảnh CCCD mặt trước và mặt sau.
> 2. **OCR**: App gửi ảnh lên backend, backend gọi **FPT.AI Vision API** để trích xuất thông tin (họ tên, số CCCD, ngày sinh, địa chỉ).
> 3. **Face matching**: User chụp selfie. Backend gọi FPT.AI Face Match so khớp khuôn mặt selfie với ảnh trên CCCD. Trả về độ tương đồng (0-1), em quy định ngưỡng > 0.8 mới chấp nhận.
> 4. Lưu kết quả vào bảng `Identity.eKYC_Profiles`. Khi admin duyệt, trigger SQL tự đổi `Users.kyc_status = 'Verified'`.

### D2. "Sao em chọn FPT.AI?"

> Em chọn FPT.AI vì 4 lý do:
>
> 1. **API tiếng Việt**: Nhận diện CCCD/CMND Việt Nam chính xác > 95%.
> 2. **Có free tier**: 500 lượt OCR + 500 Face Match miễn phí mỗi tháng, đủ cho đồ án.
> 3. **Tài liệu tiếng Việt**: Dễ tra cứu khi gặp lỗi.
> 4. **Được tin dùng**: Các app như MoMo, ViettelPay đều sử dụng FPT.AI.

### D3. "Nếu không có internet thì sao?"

> Đây là **hạn chế của hệ thống em**. eKYC yêu cầu kết nối internet để gọi FPT.AI. Hướng phát triển trong báo cáo của em đề xuất:
>
> 1. Dùng **Google ML Kit** chạy on-device cho OCR cơ bản khi offline.
> 2. Cache kết quả OCR, khi có mạng mới upload.

### D4. "Em làm sao chống ảnh giả (deepfake, ảnh chụp lại màn hình)?"

> Em phụ thuộc vào **liveness detection** của FPT.AI — service yêu cầu user quay đầu, chớp mắt, đảm bảo là người thật chứ không phải ảnh chụp. Đây là tính năng tích hợp sẵn của FPT.AI Face Match Premium.

---

## E. Câu hỏi về Thuật toán Tín nhiệm

### E1. "Em tính điểm tín nhiệm thế nào?"

> Em không tính bằng công thức cố định, mà dựa trên **lịch sử hành vi** lưu trong bảng `Point_Logs`:
>
> | Sự kiện | Delta điểm |
> |---------|------------|
> | Đăng ký tài khoản | +500 (mặc định) |
> | Hoàn thành eKYC | +100 |
> | Hoàn thành 1 giao dịch | +20 |
> | Nhận đánh giá 5⭐ | +30 |
> | Hủy đơn không lý do | -50 |
> | Bị báo cáo nghiêm trọng | -50 (qua trigger) |
> | Bị admin khóa | -200 |
>
> Trigger SQL `trg_UpdateScoreAndRank` tự tính lại tổng và phân hạng.

### E2. "Phân hạng dựa vào điểm thế nào?"

> Em dùng 4 mức:
>
> | Hạng | Điểm | UI |
> |------|------|-----|
> | Bronze (Đồng) | 0-299 | Người mới |
> | Silver (Bạc) | 300-599 | Khá uy tín |
> | Gold (Vàng) | 600-849 | Uy tín cao |
> | Diamond (Kim cương) | 850-1000 | Top trader |
>
> Hạng càng cao, sản phẩm càng được ưu tiên hiển thị trên Marketplace.

### E3. "Sao điểm bị giới hạn 0-1000?"

> Em dùng `CHECK constraint` ở SQL Server và logic trong trigger để giới hạn điểm trong [0, 1000]. Mục đích:
>
> 1. **Tránh điểm âm**: Nếu một user toàn nhận điểm trừ, không nên xuống dưới 0.
> 2. **Tránh điểm vô hạn**: Có giới hạn trên giúp việc phân hạng nhất quán.
> 3. **Dễ trực quan hóa**: 1000 là số tròn, dễ hiển thị progress bar 0-100%.

---

## F. Câu hỏi về Flutter

### F1. "Em chọn Flutter vì lý do gì?"

> 3 lý do:
>
> 1. **Cross-platform**: 1 codebase chạy được cả Android và iOS.
> 2. **Hot reload**: Sửa code → app refresh trong 1 giây, tăng tốc dev.
> 3. **Material Design 3**: Sẵn theme đẹp, đỡ phải tự thiết kế.

### F2. "App của em xử lý state thế nào?"

> Em dùng **state đơn giản** vì đồ án không phức tạp:
>
> - **Local state**: `StatefulWidget` + `setState()` cho từng màn.
> - **Auth state toàn cục**: Singleton `AuthService` extends `ChangeNotifier`. Khi login/logout, gọi `notifyListeners()` để rebuild các widget đang lắng nghe.
> - **Lưu trữ persistent**: `SharedPreferences` cho token và user JSON.
>
> Khi mở rộng, có thể chuyển sang Provider hoặc Riverpod.

### F3. "Sao trên Android Emulator phải dùng `10.0.2.2` mà không phải `localhost`?"

> Vì Android Emulator là một máy ảo riêng biệt:
>
> - Emulator coi `localhost` (127.0.0.1) là **chính nó**, không phải máy host (PC của em).
> - Để gọi máy host từ emulator, Google đã định nghĩa địa chỉ ảo **`10.0.2.2`** ánh xạ tới `localhost` của host.
> - Trên điện thoại thật, em dùng IP LAN (ví dụ `192.168.1.10`).
>
> File `lib/services/api_config.dart` của em tự detect platform để chọn đúng URL.

### F4. "FutureBuilder hoạt động thế nào?"

> `FutureBuilder` là widget của Flutter để hiển thị UI **dựa trên kết quả async**:
>
> 1. Khi widget build, nó subscribe vào `Future`.
> 2. `builder()` được gọi nhiều lần với `snapshot` khác nhau:
>    - `ConnectionState.waiting` → hiện loading
>    - `snapshot.hasError` → hiện lỗi
>    - `snapshot.hasData` → hiện dữ liệu
> 3. Khi user kéo refresh, em tạo `Future` mới và `setState()`.
>
> Em dùng FutureBuilder ở màn Profile để gọi `/users/me`.

---

## G. Câu hỏi về Code và Triển khai

### G1. "Em deploy backend lên đâu khi demo?"

> Em chạy trên máy tính cá nhân với **PM2 process manager**. PM2 là tool chuẩn để chạy Node.js app trong production:
>
> 1. Backend chạy ngầm dưới dạng daemon, đóng terminal không tắt app.
> 2. Tự restart nếu crash.
> 3. Có dashboard `pm2 monit` show CPU/RAM realtime.
> 4. Auto-start khi máy boot.
>
> Nếu deploy thật, em sẽ đưa lên VPS Ubuntu + PM2 + Nginx reverse proxy.

### G2. "Em test backend bằng cách nào?"

> Em test bằng 3 cách:
>
> 1. **Swagger UI** tại `http://localhost:3000/api/docs` — test từng endpoint trực quan.
> 2. **File `requests.http`** với extension REST Client trong VS Code — script test nhanh.
> 3. **App Flutter trực tiếp** — test luồng end-to-end.
>
> Với KLTN, em không viết unit test toàn diện do giới hạn thời gian — đây là hướng phát triển em đã ghi trong báo cáo.

### G3. "Code của em có dùng pattern nào không?"

> Có một số pattern:
>
> 1. **Repository Pattern** (qua TypeORM): Service không truy cập DB trực tiếp, mà qua Repository.
> 2. **Dependency Injection**: NestJS tự inject service vào controller qua constructor.
> 3. **DTO Pattern**: Object truyền dữ liệu giữa client-server, validate ở DTO không phải service.
> 4. **Singleton**: `AuthService.instance` trong Flutter — chỉ 1 instance toàn app.

### G4. "Em viết code này một mình hay tham khảo?"

> Em tham khảo từ:
>
> 1. Tài liệu chính thức của NestJS, TypeORM, Flutter
> 2. Tutorial trên YouTube (freeCodeCamp, NetNinja)
> 3. Stack Overflow khi gặp lỗi cụ thể
> 4. Hỏi GVHD ThS. Lê Thị Minh Nguyện khi gặp vấn đề kiến trúc
>
> Em không copy nguyên mẫu, mà tổng hợp và viết lại theo nhu cầu đồ án.

---

## H. Câu hỏi về Demo và lỗi

### H1. "Tại sao backend tự tắt giữa chừng demo?"

> Có thể do 1 trong các nguyên nhân:
>
> 1. Em chưa chạy `pm2 start` mà chỉ chạy `npm run start:dev` — đóng terminal là tắt.
> 2. SQL Server service bị stop → backend không connect được → crash.
> 3. Hết quota FPT.AI (500 req/tháng) — không phải backend tắt mà là feature eKYC bị lỗi.

### H2. "Demo bị lỗi gì em xử lý thế nào?"

> Em đã chuẩn bị các phương án dự phòng:
>
> 1. Nếu eKYC API lỗi → có **mock mode** trong code, vẫn tạo được record giả lập.
> 2. Nếu mạng yếu → có **timeout 15s**, app báo lỗi rõ ràng.
> 3. Nếu DB lỗi → em show trực tiếp file SQL để giải thích schema.
> 4. Em luôn có **2 user mẫu** đã được verify sẵn trong database để demo không phụ thuộc đăng ký mới.

### H3. "Em demo nhiệm vụ phân chia thế nào với bạn Lộc?"

> Phân chia của nhóm em:
>
> | Hiền (em) | Lộc |
> |-----------|-----|
> | Backend NestJS, JWT Auth | Module eKYC + FPT.AI integration |
> | Database schema | Module Payment (VNPay) |
> | Flutter Auth UI | Module Scoring + Admin Dashboard |
> | Báo cáo phần Phân tích & Kiến trúc | Báo cáo phần Thuật toán & Test |

---

## I. Câu hỏi về Hướng phát triển

### I1. "Em đề xuất phát triển tiếp gì?"

> Theo đề cương em đã ghi:
>
> 1. **Chat real-time** giữa người mua-bán (Socket.io)
> 2. **Tích hợp đơn vị vận chuyển** (Giao Hàng Nhanh, Viettel Post API)
> 3. **Hệ thống Recommendation** dựa trên lịch sử mua sắm (Collaborative Filtering)
> 4. **Notification push** qua Firebase Cloud Messaging
> 5. **Đa ngôn ngữ** (English) cho người nước ngoài bán đồ
> 6. **Web Admin** thay vì chỉ Flutter (cho admin quản lý dễ hơn trên màn lớn)

### I2. "Đồ án này có thể đưa vào sản xuất thật được không?"

> Chưa đủ. Để đưa vào production thật cần thêm:
>
> 1. **HTTPS** với SSL certificate
> 2. **Refresh token** thay vì chỉ access token
> 3. **Rate limiting** chống DDoS
> 4. **Logging tập trung** (ELK stack)
> 5. **Monitoring** (Prometheus + Grafana)
> 6. **CI/CD pipeline**
> 7. **Pen-test** bởi bên thứ 3 trước khi launch
>
> Đồ án này là **MVP (Minimum Viable Product)** chứng minh tính khả thi của giải pháp eKYC + Trust Score.

---

## J. Mẹo trả lời chung

| Tình huống | Cách xử lý |
|------------|------------|
| Không biết câu trả lời | "Dạ em chưa nghĩ tới góc độ này. Em sẽ tìm hiểu thêm và bổ sung vào báo cáo." |
| Hội đồng nói code sai | "Dạ em ghi nhận. Cụ thể là ở dòng nào ạ? Em xin xem lại và sửa." |
| Hỏi về phần Lộc làm | "Phần đó bạn Lộc phụ trách, em hiểu khái quát là [...]. Bạn ấy nắm chi tiết hơn em." |
| Quá khó | "Câu hỏi của thầy/cô sâu hơn phạm vi đồ án của em. Em xin được nghiên cứu thêm." |
| Hết giờ | "Dạ vì thời gian có hạn, em xin tóm tắt..." |

**Quy tắc vàng**: Nói chậm, rõ ràng, **biết gì nói nấy**, không cố bịa.

---

## K. Câu mở đầu và kết thúc

### Mở đầu (~2 phút)

> "Em xin kính chào quý thầy cô trong hội đồng. Em là Trương Trí Hiền, MSSV 23DH111023.
> Cùng với bạn Lê Tấn Lộc, chúng em thực hiện đề tài *Xây dựng hệ thống Marketplace đồ cũ an toàn dựa trên mô hình định danh eKYC và thuật toán xếp hạng tín nhiệm người dùng*, dưới sự hướng dẫn của ThS. Lê Thị Minh Nguyện.
>
> Đề tài giải quyết bài toán **lừa đảo và thiếu lòng tin** trên các sàn đồ cũ hiện nay bằng cách kết hợp **eKYC để xác thực danh tính thực** và **thuật toán xếp hạng tín nhiệm** dựa trên hành vi.
>
> Sau đây em xin demo hệ thống và trình bày các kết quả chính."

### Kết thúc (~30 giây)

> "Em xin tóm tắt: Đồ án đã hoàn thành 4/4 mục tiêu cụ thể: (1) tích hợp eKYC FPT.AI, (2) xây dựng thuật toán xếp hạng tín nhiệm 4 hạng, (3) backend đầy đủ Auth + CRUD, (4) tích hợp thanh toán VNPay sandbox.
>
> Em xin cảm ơn quý thầy cô đã lắng nghe. Em sẵn sàng trả lời câu hỏi của hội đồng."

---

## L. Checklist trước vấn đáp

| # | Việc | OK? |
|---|------|-----|
| 1 | SQL Server service đang chạy (kiểm tra trong Services.msc) | ☐ |
| 2 | PM2 backend đang `online` (chạy `pm2 list`) | ☐ |
| 3 | Mở Swagger thử: http://localhost:3000/api/docs | ☐ |
| 4 | Android Emulator boot xong | ☐ |
| 5 | Có ít nhất 2 user mẫu trong DB để demo | ☐ |
| 6 | Có ít nhất 5 sản phẩm mẫu | ☐ |
| 7 | FPT.AI API key còn quota (test 1 lần OCR ảnh mẫu) | ☐ |
| 8 | Internet ổn định | ☐ |
| 9 | Sạc đầy pin laptop hoặc cắm điện | ☐ |
| 10 | In tài liệu QA này mang theo | ☐ |
| 11 | In sẵn slide thuyết trình | ☐ |
| 12 | Có sẵn ảnh CCCD test (không phải CCCD thật của mình) | ☐ |

**Chúc nhóm vấn đáp thành công!**
