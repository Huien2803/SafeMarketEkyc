# Tài liệu VẤN ĐÁP Khoá luận Tốt nghiệp — SafeMarket

> **Đề tài:** Xây dựng hệ thống Marketplace đồ cũ an toàn dựa trên mô hình định danh **eKYC** và **thuật toán xếp hạng tín nhiệm** người dùng.  
> **Nhóm:** Trương Trí Hiền (23DH111023) & Lê Tấn Lộc (23DH111948)  
> **GVHD:** ThS. Lê Thị Minh Nguyện — HUFLIT 2026  
>
> Tài liệu này đã **đối chiếu với mã nguồn hiện tại** (Flutter + NestJS + SQL Server + Firebase).  
> **In ra giấy mang theo lúc vấn đáp.** Nói đúng những gì code đang làm — không phóng đại.

---

## MỤC LỤC

| # | Nội dung |
|---|----------|
| A | Tổng quan đề tài & bài toán |
| B | Kiến trúc hệ thống |
| C | Cơ sở dữ liệu |
| D | Đăng ký OTP & Đăng nhập |
| E | Bảo mật |
| F | eKYC |
| G | Thuật toán điểm tín nhiệm & xếp hạng |
| H | Sản phẩm, tìm kiếm/lọc, ảnh |
| I | Đơn hàng & Ký quỹ (Escrow) |
| J | Thanh toán VNPay & Ví |
| K | Admin & kiểm duyệt |
| L | Chat realtime (Firebase) |
| M | Ứng dụng Flutter |
| N | API đầy đủ (checklist) |
| O | Triển khai & vận hành |
| P | Câu hỏi phản biện / edge case |
| Q | Hạn chế & hướng phát triển (thành thật) |
| R | Phân công nhóm |
| S | Câu hỏi bẫy & mẹo trả lời |
| T | Kịch bản demo |
| U | Checklist trước vấn đáp |

---

## A. TỔNG QUAN ĐỀ TÀI & BÀI TOÁN

### A1. "Em hãy trình bày bài toán đề tài giải quyết?"

> Thị trường mua bán đồ cũ (Chợ Tốt, hội nhóm Facebook) tồn tại **3 vấn đề lớn**:
> 1. **Người bán ẩn danh** — tài khoản ảo, sim rác; lừa đảo xong biến mất, khó truy vết.
> 2. **Không đo được lòng tin** — người mua không biết đối phương uy tín đến đâu.
> 3. **Tiền trao tay rủi ro** — chuyển khoản trước dễ mất tiền, thiếu bên trung gian.
>
> Đề tài giải quyết bằng: **(1) eKYC** (OCR CCCD + liveness chống giả mạo); **(2) điểm tín nhiệm 0–1000 + 4 hạng** dựa trên hành vi; **(3) ký quỹ (Escrow)** — hệ thống ghi nhận giữ tiền, chỉ giải ngân khi giao dịch hoàn tất (sandbox/demo + VNPay Sandbox).

### A2. "Điểm khác biệt so với Chợ Tốt?"

> 1. **Bắt buộc định danh thật (eKYC)** trước khi mua/bán — Chợ Tốt chủ yếu xác thực SĐT.
> 2. **Điểm tín nhiệm minh bạch** ghi vào `Point_Logs`, cập nhật hạng tự động.
> 3. **Ký quỹ trung gian (Escrow)** bảo vệ người mua/người bán — các chợ đồ cũ VN phổ biến chưa có cơ chế này.

### A3. "Đồ án đã hoàn thành những gì?" (trả lời trung thực)

> Đã hoàn thành **MVP chứng minh đề tài**, gồm:
> 1. ✅ eKYC: OCR CCCD (FPT.AI) + **Active Liveness on-device** (ML Kit quay đầu trái/phải) → admin duyệt.
> 2. ✅ Điểm tín nhiệm + 4 hạng (Bronze/Silver/Gold/Diamond) + bảng xếp hạng admin.
> 3. ✅ Backend NestJS REST: Auth, Users, eKYC, Products, Orders, Payments, Wallet, Reviews, Reports, Follows, Notifications, Admin, Chat upload.
> 4. ✅ Flutter app đầy đủ luồng: đăng ký/đăng nhập, chợ, đăng bán (nhiều ảnh), đơn hàng, ví, chat, admin.
> 5. ✅ Chat realtime Firebase + bình luận sản phẩm Firebase.
> 6. ✅ Thanh toán: VNPay Sandbox **hoặc** `simulate-pay` khi chưa cấu hình cổng.
>
> **Chưa phải production đầy đủ:** escrow chưa nối dòng tiền ngân hàng thật; Face Match FPT có trên backend nhưng **luồng Flutter hiện tại không gọi**; favorites chỉ lưu local thiết bị.

---

## B. KIẾN TRÚC HỆ THỐNG

### B1. "Mô tả kiến trúc tổng quan?"

> **Kiến trúc 3 tầng:**
>
> | Tầng | Công nghệ | Vai trò |
> |------|-----------|---------|
> | Trình bày | Flutter (Dart), Material 3 | Android / iOS / Web |
> | Nghiệp vụ | NestJS 10 (TypeScript), port **3000**, prefix `/api` | REST API, JWT, logic giao dịch |
> | Dữ liệu | SQL Server — DB `SafeMarketDB` | Lưu bền vững, trigger, CHECK |
>
> **Dịch vụ ngoài:**
> - FPT.AI Vision — OCR CCCD (+ Face Match API còn trên backend)
> - Firebase Realtime Database — chat + bình luận sản phẩm
> - VNPay Sandbox — thanh toán ký quỹ online
> - SMTP/Nodemailer — OTP (dev: OTP in console nếu chưa cấu hình SMTP)
>
> **Luồng:** Flutter ⟷ NestJS (HTTP/JSON + JWT) ⟷ SQL Server (TypeORM + `mssql`). Chat/comment: Flutter ⟷ Firebase RTDB.

### B2. "Vì sao không cho Flutter kết nối thẳng SQL Server?"

> 1. **Bảo mật:** connection string chứa mật khẩu DB — lộ nếu decompile APK.  
> 2. **Mạng:** port 1433 thường bị chặn từ 4G/Internet.  
> 3. **Kiểm soát:** API trung gian thêm JWT, validate, phân quyền, rate-limit.

### B3. "Vì sao chọn NestJS?"

> Module hoá (Controller → Service → Repository), TypeScript type-safe, DI sẵn, Swagger tự sinh (`/api/docs`), hệ sinh thái Node (bcrypt, axios, nodemailer…).

### B4. "TypeORM dùng thế nào?"

> Entity ánh xạ bảng SQL. `synchronize: false` — **không tự sửa schema**; schema do script SQL/migration kiểm soát (giữ trigger/constraint).

### B5. "Backend có những module nào?"

> **Có REST controller:** Auth, Users, Ekyc, Products, Orders, Payments, Wallet, Chat, Reviews, Reports, Follows, Notifications, Admin.  
> **Service-only (không REST riêng):** Mail (OTP), Reputation (được Orders/Admin/Reviews gọi).

---

## C. CƠ SỞ DỮ LIỆU

### C1. "Giải thích schema?"

> DB `SafeMarketDB` chia **5 schema** (bounded context):
>
> | Schema | Bảng chính | Vai trò |
> |--------|------------|---------|
> | `Identity` | `Users`, `eKYC_Profiles`, `RefreshTokens` | Định danh, CCCD, refresh token |
> | `Market` | `Categories`, `Products`, `Product_Images`, `Chat_*`, `User_Follows`, `Notifications` | Sản phẩm, chat SQL (legacy), follow, thông báo |
> | `Finance` | `Orders`, `Payments`, `Wallets`, `Wallet_Transactions`, `Withdrawals` | Đơn, escrow, ví, rút tiền |
> | `Reputation` | `Scores`, `Point_Logs`, `Reviews` | Điểm, log điểm, đánh giá |
> | `Moderation` | `Reports` | Báo cáo vi phạm |
>
> Schema gốc trong `eKYC Market.sql` (11 bảng cốt lõi); các file `backend/db/migrate-*.sql` bổ sung refresh token, ví, moderation, follow/notifications, chat tables, v.v.

### C2. "Các trigger quan trọng?"

> 1. **`trg_InitializeReputation`** — user mới → `Scores` = **500 / Bronze**.  
> 2. **`trg_UpdateScoreAndRank`** — sau INSERT `Point_Logs` → cập nhật điểm (clamp 0–1000) + hạng.  
> 3. **`trg_SyncKycStatusOnVerify`** — khi set `verified_at` → `Users.kyc_status = Verified`.  
> 4. **`trg_ReportHighSeverityPenalty`** — báo cáo `severity=high` → `Point_Logs` **−50** (`REPORT_HIGH`).

### C3. "Constraint đáng nhớ?"

> UNIQUE: email, phone, `Scores.user_id`, `eKYC_Profiles.user_id`, **`Orders.product_id`** (mỗi món đồ cũ chỉ 1 đơn active theo thiết kế).  
> CHECK: điểm 0–1000, `condition_pct` 0–100, status hợp lệ…

### C4. "Chat lưu ở đâu — SQL hay Firebase?"

> **Tin nhắn realtime chính: Firebase RTDB** (`safemarket/messages`, `threads`, `userThreads`).  
> Nest còn module Chat SQL (legacy) — app Flutter **không dùng** API messages SQL; chỉ dùng Nest để **upload ảnh chat** và tạo đơn từ chat (OrderService).

---

## D. ĐĂNG KÝ OTP & ĐĂNG NHẬP

### D1. "Luồng đăng ký?"

> **Bước 1** `POST /api/auth/register/request-otp`:
> - Chuẩn hoá email, chặn domain disposable (~23 domain).
> - Kiểm tra email/SĐT chưa tồn tại.
> - Cooldown gửi lại **30 giây**.
> - OTP **6 số**, TTL **5 phút**, lưu **RAM**; gửi SMTP (hoặc in console/devOtp khi chưa cấu hình).
>
> **Bước 2** `POST /api/auth/register/verify-otp`:
> - Sai tối đa **5 lần**.
> - Đúng → tạo user (bcrypt), trigger tạo Scores 500 Bronze → cấp **access JWT + refresh token**.

### D2. "Đăng nhập?"

> `POST /api/auth/login` với email **hoặc** SĐT + mật khẩu → `bcrypt.compare` → check `account_status = Active` → trả access + refresh.  
> Thông báo lỗi **mơ hồ** (chống enumeration).

### D3. "Tài khoản demo?"

> | Email | Mật khẩu (dev) | Ghi chú |
> |-------|----------------|---------|
> | `admin@safemarket.vn` | `admin123` | Admin, Verified |
> | `an.nguyen@email.com` | `123456` | Verified, seed ~850 Gold |
> | `b.tran@email.com` | `123456` | Pending KYC |
> | `c.le@email.com` | `123456` | Verified |
> | `d.pham@email.com` | `123456` | Locked (demo) |
>
> Backend nhận diện hash placeholder: `HASH_DEMO` ↔ `123456`; `HASH_REPLACE_IN_PRODUCTION` ↔ `admin123`.

### D4. "Quên mật khẩu?"

> `password/forgot` → OTP email → `password/reset` → đổi mật khẩu bcrypt + **revoke mọi refresh token**.

---

## E. BẢO MẬT

### E1. "Mật khẩu lưu thế nào?"

> **bcrypt, 10 rounds**, có salt. Không lưu plaintext. So khớp bằng `bcrypt.compare`.

### E2. "JWT + Refresh token?" ⭐ (đừng nói sai như bản QA cũ)

> - **Access token JWT:** mặc định hết hạn **15 phút** (`JWT_EXPIRES_IN=15m`). Payload: `sub`, `email`, `isAdmin`.  
> - **Refresh token:** opaque (48 bytes hex), hash **SHA-256** lưu bảng `Identity.RefreshTokens`, mặc định **7 ngày**, **rotate** mỗi lần refresh.  
> - Logout → revoke refresh.  
> - Flutter lưu token trong **`flutter_secure_storage`** (keys `safemarket.access_token` / `safemarket.refresh_token`); profile user có thể còn SharedPreferences. App tự refresh khi 401.

### E3. "JWT stateless thì khoá user thế nào?"

> Mỗi request, `JwtStrategy.validate()` **đọc lại DB**: user tồn tại + `account_status === Active`. Suspend hết hạn (`locked_until`) có thể tự mở. Admin khoá/cấm → token cũ **vô hiệu ngay**.

### E4. "Phân quyền admin?"

> `AuthGuard('jwt')` + kiểm tra `isAdmin`. Service chặn thao tác lên chính admin.

### E5. "Chống SQL Injection / mass assignment?"

> TypeORM parameterized query; `ValidationPipe` whitelist + forbidNonWhitelisted; DTO + class-validator.

### E6. "Rate limit?"

> `@nestjs/throttler` global: **100 request / 60 giây** mỗi IP (mặc định).

### E7. "Upload an toàn?"

> Multer: chỉ ảnh, giới hạn dung lượng (vd sản phẩm ≤5MB/ảnh), lưu `uploads/`. Chưa quét virus — ghi là hạn chế.

---

## F. eKYC (XÁC THỰC DANH TÍNH) ⭐

### F1. "Luồng eKYC thực tế trong app?"

> **Luồng Flutter hiện tại:**
> 1. Chụp **mặt trước CCCD** → `POST /api/ekyc/scan-id-front` (FPT.AI OCR).  
> 2. (Có thể) chụp **mặt sau** → `POST /api/ekyc/scan-id-back`.  
> 3. **Active Liveness on-device** (`liveness_challenge_screen.dart` + ML Kit): nhìn thẳng → quay trái → quay phải.  
> 4. `POST /api/ekyc/submit` với `livenessToken` + `recognitionPoints` (≥ 4) → `kyc_status = Pending`.  
> 5. **Admin duyệt** → `verified_at` → trigger đồng bộ `Verified`.
>
> ⚠️ **Face Match (`POST /api/ekyc/face-match`) có trên backend nhưng UI hiện không gọi.** Khi hội đồng hỏi: em dùng OCR FPT + liveness chủ động on-device + admin duyệt; Face Match là API dự phòng/tương thích.

### F2. "Liveness chống giả mạo thế nào?"

> Không chỉ selfie tĩnh. Dùng **Google ML Kit Face Detection**:
> - Đúng 1 khuôn mặt, mắt mở.  
> - Góc yaw: thẳng ≤ ~12° → trái ≥ ~20° → phải ≤ ~−20°.  
> - Ảnh tĩnh / ảnh in khó vượt vì phải **xoay đầu theo lệnh**.  
> Backend khi submit kiểm tra có `livenessToken` + đủ `recognitionPoints`.  
> *(Lưu ý: `POST /ekyc/liveness-check` phía server hiện demo always-pass; token liveness chủ yếu sinh phía client — đây là hạn chế nếu bị hỏi sâu.)*

### F3. "Vì sao liveness on-device?"

> Realtime (không gửi từng frame lên server), tiết kiệm quota FPT, riêng tư hơn.

### F4. "Ai duyệt eKYC?"

> Admin: `POST /api/admin/ekyc/:userId/approve` hoặc `reject` (+ lý do).

### F5. "eKYC bắt buộc ở đâu?"

> **Đăng bán** và **đặt mua** đều yêu cầu `kyc_status = Verified` (backend + Flutter `ensureEkycVerified`).

### F6. "Dữ liệu CCCD bảo vệ thế nào?"

> API mask số CCCD (ví dụ chỉ hiện một phần); ảnh lưu server `/uploads`. Chưa mã hoá at-rest — hướng phát triển theo Nghị định 13/2023.

### F7. "Duyệt eKYC có cộng điểm không?"

> **Hiện tại: KHÔNG.** Không có `KYC_SUCCESS +100` trong code. Điểm chỉ đổi theo giao dịch / review / báo cáo / admin.  
> *(Nếu hội đồng hỏi vì sao: có thể nói đây là hạn chế MVP — ưu tiên “định danh rồi mới được giao dịch”; cộng điểm KYC là hướng mở rộng.)*

---

## G. THUẬT TOÁN ĐIỂM TÍN NHIỆM & XẾP HẠNG ⭐

### G1. "Tính điểm thế nào?" (NÓI ĐÚNG CODE)

> Điểm khởi tạo **500 / Bronze**. Mỗi thay đổi ghi `Point_Logs` (`delta`, `reason_code`, `note`).  
> **Bảng Δ thực tế trong code:**
>
> | Sự kiện | `reason_code` | Δ |
> |---------|---------------|---|
> | Đăng ký (trigger) | — | = **500** |
> | Hoàn tất đơn (buyer & seller) | `ORDER_COMPLETE` | **+20** mỗi bên |
> | Nhận đánh giá 5★ | `REVIEW_5_STAR` | **+30** |
> | Bị báo cáo `severity=high` | `REPORT_HIGH` | **−50** (SQL trigger) |
> | Admin phạt | `ADMIN_PENALTY` | −(1..500) |
> | Admin cảnh cáo | `ADMIN_WARNING` | **0** (chỉ ghi log) |
> | Phạt khi xử lý tranh chấp | `DISPUTE_PENALTY` | mặc định **−50** (có thể tắt) |
>
> ❌ **Không có trong code:** `KYC_SUCCESS +100`, trừ điểm khi hủy đơn, reason `ORDER_CANCELLED`.  
> ❌ Một số text trên UI cũ (order detail) có thể **lệch** — khi vấn đáp **ưu tiên bảng trên**.

### G2. "4 hạng?"

> | Hạng | Điểm |
> |------|------|
> | Bronze | 0–299 |
> | Silver | 300–599 |
> | Gold | 600–849 |
> | Diamond | ≥ 850 |
>
> Clamp **0–1000**. Hàm `rankFor()` ở backend + trigger SQL thống nhất ngưỡng.

### G3. "Xếp hạng admin?"

> `GET /api/admin/users/ranking?order=asc|desc`:  
> 1) **Verified trước** chưa Verified; 2) trong nhóm sort theo `trustScore`; 3) gắn số thứ hạng.

### G4. "Điểm dùng ở đâu trên marketplace?"

> Hiển thị trên hồ sơ / API user; admin ranking.  
> **Chưa** có sort sản phẩm theo điểm tín nhiệm.  
> *(Hạn chế so với tựa đề “xếp hạng” — nếu hỏi: thuật toán đã tính & xếp trên admin; gắn vào feed marketplace là hướng phát triển.)*

### G5. "Vì sao điểm 0–1000?"

> Trực quan, tránh âm vô hạn / farm vô hạn; CHECK + clamp bảo vệ.

---

## H. SẢN PHẨM, TÌM KIẾM/LỌC, ẢNH

### H1. "Trạng thái sản phẩm?"

> `Available` → `Reserved` (có đơn) → `Sold`; huỷ đơn → lại `Available`; admin/user ẩn → `Hidden`.  
> `condition_pct` 0–100 mô tả độ mới đồ cũ.

### H2. "Đăng bán nhiều ảnh?"

> Multipart field **`images`**, tối đa **8 ảnh**, ≤5MB/ảnh. Ảnh đầu = `thumbnail_url`; tất cả lưu `Product_Images` với `sort_order`. Chi tiết sản phẩm: PageView + chỉ số trang.

### H3. "Lọc / tìm kiếm?"

> `GET /api/products`: `categoryId`, `search`, `minPrice`/`maxPrice`, `location`, `verifiedOnly`, `sort` = `newest|oldest|price_asc|price_desc`.

### H4. "Bình luận sản phẩm?"

> Có — **Firebase** `safemarket/productComments/{productId}/` (hỏi đáp công khai dưới tin đăng).

### H5. "Yêu thích?"

> **Chỉ local** SharedPreferences (`safemarket.favorites`) — chưa API Nest. Nói rõ nếu bị hỏi.

---

## I. ĐƠN HÀNG & KÝ QUỸ (ESCROW) ⭐

### I1. "Vòng đời đơn hàng?"

> `Pending` → `Paid` → (`Shipped` nếu SHIP) → `Completed`  
> Rẽ nhánh: `Cancelled` | `Disputed` → admin `REFUND_BUYER` / `RELEASE_SELLER`.

### I2. "Phương thức thanh toán / giao hàng?"

> **Thanh toán:** `BANK_TRANSFER` | `CASH` | `ONLINE_ESCROW`.  
> **Giao:** `SHIP` | `DIRECT` (bàn giao tận tay).

### I3. "Escrow hoạt động thế nào?"

> Với `ONLINE_ESCROW`:
> 1. Checkout / thanh toán → `escrow_status = Holding`, đơn `Paid`.  
> 2. Người bán giao hàng / xác nhận bàn giao.  
> 3. Người mua **complete** → escrow `Released` + **cộng ví người bán** + cộng điểm `ORDER_COMPLETE`.  
> 4. Huỷ / admin hoàn → `Refunded`.
>
> **Trung thực:** đây là **ký quỹ mức ứng dụng** (trạng thái + ví nội bộ), chưa phải giữ tiền tại ngân hàng thật.

### I4. "Hai người mua cùng lúc?"

> UNIQUE `product_id` + check `Available` → người sau lỗi (vd 409).

---

## J. THANH TOÁN VNPAY & VÍ

### J1. "VNPay?"

> `POST /api/payments/orders/:orderId/checkout` tạo URL VNPay Sandbox nếu đã cấu hình `VNPAY_*`.  
> Return/IPN: `/api/payments/vnpay-return`, `/api/payments/vnpay-ipn`.  
> Chưa cấu hình → **devMode** + `POST .../simulate-pay` để demo.

### J2. "Ví người bán?"

> Module Wallet: số dư, lịch sử giao dịch, yêu cầu rút tiền (`Withdrawals`).  
> Admin: duyệt / từ chối rút tiền (+ ghi chú nếu có).

---

## K. ADMIN & KIỂM DUYỆT

### K1. "Admin làm được gì?"

> - KPI / thống kê  
> - Danh sách user, ranking tín nhiệm  
> - Duyệt / từ chối eKYC  
> - Cảnh cáo / khoá / đình chỉ có hạn (`locked_until`) / cấm / phạt điểm / xoá mềm / mở khoá  
> - Ẩn sản phẩm, xử lý báo cáo  
> - Xử lý tranh chấp đơn hàng  
> - Duyệt rút tiền  
> - (Flutter) xuất báo cáo PDF/CSV

### K2. "Báo cáo vi phạm?"

> User `POST /api/reports`. Severity `high` → trigger −50 điểm người bị báo cáo (có rủi ro spam — xem mục P).

---

## L. CHAT REALTIME (FIREBASE)

### L1. "Chat dùng công nghệ gì?"

> **Firebase Realtime Database** (không phải Firestore).  
> Project: `safemarketekyc-38009`, region `asia-southeast1`.

### L2. "Cây dữ liệu?"

> ```
> safemarket/
>   threads/{threadKey}          — metadata hội thoại
>   messages/{threadKey}/{msgId} — tin nhắn realtime
>   userThreads/{userId}/        — danh sách chat từng user
>   productComments/{productId}/ — bình luận sản phẩm
> ```
> Thread key deterministic: `{lowUserId}_{highUserId}_{productId}`.

### L3. "Loại tin nhắn?"

> TEXT, IMAGE (upload Nest `/api/chat/upload-image`), PRODUCT_CARD, PURCHASE_REQUEST, xác nhận bán…  
> Mở chat + gửi thẻ sản phẩm → đặt mua qua luồng Order Nest.

### L4. "Làm sao biết chat đã chạy?"

> Gửi tin trong app → Firebase Console → Realtime Database → bung node `safemarket` → `messages` thấy dữ liệu nhảy realtime.

---

## M. ỨNG DỤNG FLUTTER

### M1. "Các màn hình chính?"

> AuthGate, Login/Register/OTP/Forgot, Marketplace, Product detail, Đăng bán, Profile / Public profile, eKYC + Liveness, Đơn hàng, Chat list/screen, Ví, Thông báo, Favorites, Reviews, Admin dashboard.

### M2. "Quản lý trạng thái đăng nhập?"

> `AuthService` singleton + secure storage token + `AuthGate` quyết định vào app hay login. Auto refresh token khi 401.

### M3. "App tìm địa chỉ backend thế nào?"

> `ApiConfig.resolveBaseUrl()` ping lần lượt:
> - Android emulator → `10.0.2.2:3000`  
> - Web/Desktop → `localhost`  
> - Máy thật → IP LAN (`API_HOST` / `API_BASE_URL` qua `--dart-define`)

### M4. "Liveness dùng package gì?"

> `camera` + `google_mlkit_face_detection` (landmarks, classification, góc đầu).

---

## N. API ĐẦY ĐỦ (CHECKLIST HỘI ĐỒNG)

> Prefix: `/api` — Swagger: `http://localhost:3000/api/docs`

### Auth
`POST register/request-otp`, `register/verify-otp`, `login`, `refresh`, `logout`, `password/forgot`, `password/reset`, `GET me`

### Users
`GET/PUT me`, `POST me/avatar`, `GET me/sold-products`, `GET :id`, `GET :id/listings`

### eKYC
`POST scan-id-front`, `scan-id-back`, `face-match`, `liveness-check`, `submit`, `GET my-status`

### Products
`GET categories`, `GET /`, `GET :id`, `POST /` (multipart images), `PUT :id`, `POST :id/hide`, `DELETE :id`

### Orders
`POST /`, `GET my`, `GET :orderId`, `payment-method`, `ship`, `confirm-payment`, `confirm-handover`, `complete`, `cancel`, `dispute`

### Payments
`checkout`, `simulate-pay`, `GET vnpay-return`, `GET vnpay-ipn`

### Wallet
`GET /`, `GET/POST withdrawals`

### Chat (Nest — chủ yếu upload; messages SQL legacy)
`open`, `threads`, messages CRUD, `purchase-request`, `confirm-sale`, **`upload-image`**

### Reviews / Reports / Follows / Notifications
Đầy đủ CRUD/status như controller tương ứng.

### Admin
`stats`, `users`, `users/ranking`, `reports`, `ekyc/pending`, `users/locked`, approve/reject eKYC, warn/lock/suspend/ban/punish/delete/unlock, hide product, disputes, withdrawals approve/reject.

> Khi nói “tích hợp API”: **các nghiệp vụ chính marketplace + eKYC + điểm + escrow + admin đều qua Nest**. Chat/comment realtime qua Firebase; favorites local — **nói rõ hybrid**, đừng nói “100% mọi thứ qua Nest”.

---

## O. TRIỂN KHAI & VẬN HÀNH

### O1. "Thứ tự chạy demo?"

> 1. SQL Server (DB `SafeMarketDB` + đã chạy migration `backend/db/migrate-*.sql`)  
> 2. Backend: `cd backend && npm run start:dev` → `http://localhost:3000/api`  
> 3. Flutter: `flutter run` (nhớ bật backend bằng `CHAY-BACKEND.bat` trước)

### O2. "Test API?"

> Swagger `/api/docs`, REST Client, hoặc end-to-end trên app.

### O3. "Biến môi trường `.env`?"

> `PORT`, `DB_*`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`, `SMTP_*`, `FPT_AI_*`, `VNPAY_*`, `CORS_ORIGINS` (bắt buộc khi production).  
> Production enforce JWT mạnh + SMTP + CORS trong `main.ts`.

---

## P. CÂU HỎI PHẢN BIỆN / EDGE CASE

### P1. "Người mua trả tiền rồi không bấm nhận hàng?"

> Tiền còn Holding. Người bán/admin xử lý dispute. Hướng phát triển: auto-release sau X ngày.

### P2. "Spam báo cáo high để trừ điểm?"

> Hiện trừ ngay khi INSERT report high — **hạn chế**. Hướng: chỉ trừ sau khi admin xác nhận báo cáo đúng.

### P3. "OTP RAM mất khi restart backend?"

> Đúng — user xin OTP lại. Production: Redis TTL.

### P4. "Vì sao không MongoDB như đề cương?"

> Chọn SQL Server thống nhất: ACID cho tài chính, `Point_Logs` đủ log hành vi, giảm phức tạp vận hành.

### P5. "Điểm có thể cộng hai lần không?"

> Có rủi ro kỹ thuật: một số chỗ service **vừa update Scores vừa INSERT Point_Logs**, trong khi trigger cũng cập nhật điểm từ log → có thể **nhân đôi** nếu không kiểm soát.  
> Trả lời trung thực: đã nhận biết; hướng chuẩn là **chỉ ghi Point_Logs, để trigger cập nhật Scores** (single writer).

### P6. "Điểm yếu lớn nhất?" (thành thật)

> 1. Escrow/VNPay sandbox — chưa dòng tiền ngân hàng thật.  
> 2. eKYC: Face Match chưa gắn UI; liveness token phía client còn yếu nếu bị tấn công.  
> 3. Ranking tín nhiệm chưa gắn feed marketplace.  
> 4. Hybrid Firebase + Nest; favorites local.  
> 5. Unit/E2E test mỏng; OTP/pending checkout in-memory.

---

## Q. HẠN CHẾ & HƯỚNG PHÁT TRIỂN

### Q1. "Phát triển tiếp?"

> 1. Auto-release escrow + cổng thanh toán/ví thật.  
> 2. Gắn Face Match vào luồng eKYC; harden liveness server-side.  
> 3. Sort/filter marketplace theo trust score; đồng bộ text UI với công thức.  
> 4. Single-writer cho điểm (chỉ trigger hoặc chỉ service).  
> 5. Favorites API; push FCM; tích hợp vận chuyển GHN/Viettel.  
> 6. Mã hoá CCCD at-rest; CI/CD; pen-test; Redis cho OTP.

### Q2. "Đưa production được chưa?"

> **Chưa.** Đây là **MVP** chứng minh eKYC + Trust Score + Escrow trên marketplace đồ cũ. Production cần HTTPS, bí mật cứng, cổng thanh toán thật, pháp lý dữ liệu cá nhân, test tự động.

---

## R. PHÂN CÔNG NHÓM

> | Trương Trí Hiền (23DH111023) | Lê Tấn Lộc (23DH111948) |
> |------------------------------|--------------------------|
> | Backend NestJS, Auth OTP + JWT/refresh | eKYC (FPT OCR + Liveness ML Kit) |
> | Database + trigger + escrow/orders | Payment VNPay + Wallet |
> | Flutter Auth / Marketplace / Profile | Scoring + Admin + Kiểm duyệt |
> | Báo cáo: Phân tích & Kiến trúc | Báo cáo: Thuật toán & Kiểm thử |
>
> *(Điều chỉnh đúng phân công thực tế nhóm. Cả hai cần nắm tổng thể để trả lời chéo.)*

---

## S. CÂU HỎI BẪY & MẸO

| Tình huống | Cách xử lý |
|------------|------------|
| Không biết | "Em chưa nghiên cứu sâu góc này, xin ghi nhận và bổ sung." |
| Code bị chỉ sai | "Em ghi nhận. Thầy/cô cho em xem cụ thể phần nào để giải thích." |
| Phần bạn làm | "Bạn [tên] phụ trách chính; em hiểu khái quát là…" |
| Ngoài phạm vi | "Sâu hơn phạm vi đồ án, em xin nghiên cứu thêm." |
| Bị dồn bảo mật | Thành thật hạn chế + hướng khắc phục — **không bịa đã an toàn tuyệt đối**. |

**Quy tắc vàng:** chậm – rõ – đúng code – không bịa.

---

## T. KỊCH BẢN DEMO (5–8 phút)

1. **Đăng nhập** admin + 1 user Verified (hoặc đăng ký OTP nếu SMTP/console sẵn).  
2. **Marketplace** — lọc/tìm, mở chi tiết, vuốt nhiều ảnh (nếu tin mới).  
3. **eKYC** (nếu user Pending) — OCR + liveness → Pending → admin duyệt.  
4. **Đăng bán** — chọn nhiều ảnh → đăng.  
5. **Chat Firebase** — gửi tin / thẻ sản phẩm → đặt mua.  
6. **Thanh toán** — simulate-pay hoặc VNPay sandbox → complete → điểm + ví.  
7. **Admin** — ranking, báo cáo, dispute (nếu còn thời gian).  
8. (Tuỳ chọn) Mở Firebase Console bung `safemarket` chứng minh realtime.

---

## U. CHECKLIST TRƯỚC VẤN ĐÁP

- [ ] SQL Server chạy, DB đã migrate (`migrate-*.sql`).  
- [ ] Backend `npm run start:dev` → Swagger mở được.  
- [ ] Flutter chạy được, login demo OK.  
- [ ] Nhớ bảng điểm **đúng code** (G1) — không nói KYC +100 nếu chưa code.  
- [ ] Nhớ: JWT **15m** + refresh **7d** + secure storage.  
- [ ] Nhớ: chat = **Firebase**; Face Match = backend có, UI chưa gắn.  
- [ ] Nhớ: escrow = demo/sandbox, không phải ngân hàng thật.  
- [ ] In tài liệu này + mang sơ đồ kiến trúc / ERD.  
- [ ] Phân công: ai demo phần nào đã thống nhất.

---

## PHỤ LỤC — STACK PHIÊN BẢN (gợi ý nêu khi hỏi)

- **Flutter:** SDK ^3.12; `http`, `flutter_secure_storage`, `firebase_core`/`firebase_database`, `camera`, `google_mlkit_face_detection`, `image_picker`…  
- **Backend:** NestJS ^10.4, TypeORM ^0.3, mssql, JWT/passport, bcrypt, throttler, swagger, nodemailer, multer, helmet.  
- **DB:** Microsoft SQL Server — `SafeMarketDB`.  
- **Firebase project:** `safemarketekyc-38009`.

---

*Tài liệu cập nhật theo mã nguồn SafeMarket-Ekyc — dùng để học và bảo vệ. Khi code thay đổi, sửa lại các mục đánh dấu ⭐ trước.*
