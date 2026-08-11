# SafeMarket — Logic, Luồng chính & Thuật toán (Tài liệu ôn bảo vệ)

> **Đề tài:** Xây dựng hệ thống Marketplace đồ cũ an toàn dựa trên mô hình định danh **eKYC** và **thuật toán xếp hạng tín nhiệm** người dùng.  
> **Stack:** Flutter (mobile) + NestJS (API) + SQL Server + Firebase Realtime Database  
> **Repo:** https://github.com/Huien2803/SafeMarketEkyc  
> **Mục đích file này:** Nắm **đúng những gì code đang làm** — logic nghiệp vụ, luồng end-to-end, công thức/thuật toán, file nguồn chính — để trình bày và trả lời phản biện trong 7 ngày còn lại.  
> **Đối chiếu:** Mã nguồn hiện tại (không phóng đại tính năng chưa có).

---

## Mục lục

1. [Tổng quan đề tài & bài toán](#1-tổng-quan-đề-tài--bài-toán)
2. [Kiến trúc tổng thể](#2-kiến-trúc-tổng-thể)
3. [Cơ sở dữ liệu & ràng buộc](#3-cơ-sở-dữ-liệu--ràng-buộc)
4. [Các vai trò trong hệ thống](#4-các-vai-trò-trong-hệ-thống)
5. [Luồng 1 — Đăng ký OTP / Đăng nhập / JWT](#5-luồng-1--đăng-ký-otp--đăng-nhập--jwt)
6. [Luồng 2 — eKYC 3 bước (định danh)](#6-luồng-2--ekyc-3-bước-định-danh)
7. [Luồng 3 — Đăng bán & duyệt chợ](#7-luồng-3--đăng-bán--duyệt-chợ)
8. [Luồng 4 — Chat → Đặt mua → Escrow → Hoàn tất](#8-luồng-4--chat--đặt-mua--escrow--hoàn-tất)
9. [Luồng 5 — Thanh toán VNPay](#9-luồng-5--thanh-toán-vnpay)
10. [Luồng 6 — Ví & rút tiền ngân hàng](#10-luồng-6--ví--rút-tiền-ngân-hàng)
11. [Luồng 7 — Đánh giá, báo cáo, khiếu nại, Admin](#11-luồng-7--đánh-giá-báo-cáo-khiếu-nại-admin)
12. [Thuật toán & công thức cần thuộc](#12-thuật-toán--công-thức-cần-thuộc)
13. [Máy trạng thái (State Machine)](#13-máy-trạng-thái-state-machine)
14. [Bản đồ mã nguồn quan trọng](#14-bản-đồ-mã-nguồn-quan-trọng)
15. [Câu hỏi hay bị hỏi & cách trả lời ngắn](#15-câu-hỏi-hay-bị-hỏi--cách-trả-lời-ngắn)
16. [Hạn chế thật của đồ án (nói thẳng)](#16-hạn-chế-thật-của-đồ-án-nói-thẳng)
17. [Checklist ôn 7 ngày](#17-checklist-ôn-7-ngày)

---

## 1. Tổng quan đề tài & bài toán

### 1.1 Bài toán thực tế

Chợ đồ cũ (second-hand) trên mạng dễ gặp:

| Rủi ro | Hệ thống xử lý như thế nào |
|--------|----------------------------|
| Người bán giả / lừa đảo | Bắt buộc **eKYC** trước khi mua/bán |
| Tranh chấp giao hàng / không nhận được hàng | **Escrow (ký quỹ)** + ảnh chứng từ nhận hàng + khiếu nại Admin |
| Không biết đối phương đáng tin không | **Điểm tín nhiệm 0–1000** + hạng Bronze→Diamond |
| Chat mất ngữ cảnh đơn hàng | Chat realtime gắn **product + order status** |

### 1.2 Mục tiêu đồ án (có trong code)

1. Định danh người dùng qua **eKYC** (CCCD + liveness + face-match), Admin duyệt.
2. Marketplace đồ cũ: đăng tin, tìm/lọc, chat, đặt mua.
3. Thanh toán **ONLINE_ESCROW** qua VNPay (hoặc simulate-pay khi demo).
4. Giải ngân về **ví nội bộ** người bán → rút về ngân hàng (Admin duyệt).
5. Hệ điểm tín nhiệm + xếp hạng + kiểm duyệt (báo cáo, khóa, phạt, dispute).

### 1.3 Không phải đồ án AI/ML recommendation

Không có gợi ý sản phẩm kiểu collaborative filtering / deep learning.  
“Thuật toán” trong khóa luận chủ yếu là: **quy tắc cộng/trừ điểm + xếp hạng**, **khóa sản phẩm chống double-sell**, **chữ ký VNPay**, **session eKYC + ngưỡng face-match**, **OTP/JWT**.

---

## 2. Kiến trúc tổng thể

```
+---------------------+     HTTPS/JSON      +----------------------+
|  Flutter App        | ------------------> |  NestJS API (:3000)  |
|  (AuthGate -> Marketplace) | <------------- |  prefix: /api        |
+----------+----------+                     +----------+-----------+
           |                                            |
           | Firebase RTDB                              | TypeORM
           | (chat realtime)                            v
           v                                   +----------------------+
+---------------------+                       |  SQL Server          |
|  Firebase           |                       |  SafeMarketDB        |
|  threads/messages   |                       |  Identity/Market/... |
+---------------------+                       +----------------------+
                                                         |
                         VNPay / VNPT-eKYC / FPT.AI <----+
```

### 2.1 Phân tầng trách nhiệm

| Tầng | Công nghệ | Việc gì |
|------|-----------|---------|
| **Presentation** | Flutter | UI, validation form, liveness trên thiết bị, mở VNPay |
| **Application / API** | NestJS | Nghiệp vụ, phân quyền JWT, escrow, eKYC session, ví |
| **Persistence** | SQL Server | Người dùng, SP, đơn, điểm, ví — **source of truth** |
| **Realtime** | Firebase RTDB | Chat, thẻ đặt mua, sync `orderId`/`orderStatus` |

**Nguyên tắc quan trọng khi bảo vệ:**  
- Đơn hàng / tiền / điểm → **SQL + NestJS** là chuẩn.  
- Firebase chỉ là kênh chat + hiển thị trạng thái nhanh; không phải sổ cái tiền.

### 2.2 Module NestJS chính

| Module | Vai trò |
|--------|---------|
| `AuthModule` | OTP đăng ký, login, JWT, refresh, quên MK |
| `EkycModule` | Session eKYC, OCR, liveness token, face-match, submit |
| `ProductsModule` | Đăng/sửa/ẩn SP, tìm lọc |
| `OrdersModule` | Tạo đơn, khóa SP, ship/handover/complete/cancel/dispute |
| `PaymentsModule` | Checkout VNPay, IPN/return, simulate-pay |
| `WalletModule` | Số dư, rút tiền |
| `ReviewsModule` | Đánh giá sau Completed → cộng/trừ điểm |
| `ReputationModule` | Ghi Point_Logs (clamp/hạng do trigger + service) |
| `ChatModule` | REST chat SQL + upload ảnh (Flutter realtime dùng Firebase) |
| `FollowsModule` | Follow / followers / following |
| `ReportsModule` | Báo cáo vi phạm |
| `AdminModule` | Duyệt eKYC, ranking, dispute, rút tiền, khóa/ban |
| `NotificationsModule` | Thông báo in-app |
| `MailModule` | Gửi OTP / quên mật khẩu |

### 2.3 Cổng vào Flutter

- `main.dart` → resolve API host → init Firebase → `AuthGate`.
- `AuthGate` **không bắt buộc login** để xem chợ; mua/bán/chat mới bắt login + eKYC Verified (`ensureLoggedIn` / `ensureEkycVerified`).

---

## 3. Cơ sở dữ liệu & ràng buộc

File gốc: `eKYC Market.sql` (+ các file migrate ví/chat trong `backend/db/`).

### 3.1 Schema

| Schema | Nội dung |
|--------|----------|
| `Identity` | Users, eKYC_Profiles, (RefreshTokens qua migrate) |
| `Market` | Categories, Products, Product_Images |
| `Finance` | Orders, Payments, (Wallets, Withdrawals qua migrate) |
| `Reputation` | Scores, Point_Logs, Reviews |
| `Moderation` | Reports |

### 3.2 Ràng buộc then chốt (nên nhắc khi bảo vệ)

1. **Users.kyc_status** ∈ `{Unverified, Pending, Verified, Rejected}`  
2. **Users.account_status** ∈ `{Active, Locked, Banned, Deleted}`  
3. **Scores.current_point** ∈ `[0, 1000]`; rank ∈ `{Bronze, Silver, Gold, Diamond}`  
4. **Orders**: `UNIQUE(product_id)` → một sản phẩm chỉ gắn một dòng order “sống” (Cancelled được tái dùng trong code)  
5. **Payments.escrow_status** ∈ `{Holding, Released, Refunded}`  
6. **Products.status** ∈ `{Available, Reserved, Sold, Hidden}`

### 3.3 Trigger SQL quan trọng

| Trigger | Việc làm |
|---------|----------|
| `trg_InitializeReputation` | User mới → Score **500 / Bronze** |
| `trg_UpdateScoreAndRank` | Insert `Point_Logs` → cộng delta, **clamp 0–1000**, cập nhật hạng |
| `trg_SyncKycStatusOnVerify` | Có `verified_at` → `Users.kyc_status = Verified` |
| Report high (SQL) | Báo cáo severity high khi Open → có thể trừ điểm (`REPORT_HIGH` −50) |

**Ý nghĩa kiến trúc:** Service Nest chỉ **ghi log điểm** (`Point_Logs`); trigger bảo đảm không cộng vượt trần và hạng luôn đồng bộ — tránh “cộng 2 lần” nếu vừa update Scores vừa insert log.

---

## 4. Các vai trò trong hệ thống

| Vai trò | Điều kiện | Việc chính |
|---------|-----------|------------|
| **Khách** | Chưa login | Xem chợ, xem SP |
| **Buyer** | Login + eKYC Verified | Chat, đặt mua, trả escrow, xác nhận nhận hàng (ảnh), review, hủy/dispute |
| **Seller** | Login + eKYC Verified | Đăng SP, xác nhận bán, ship/handover, nhận tiền ví, rút tiền |
| **Admin** | `is_admin = 1` | Duyệt eKYC, ranking, báo cáo, dispute, duyệt rút, khóa/ban/phạt |

Một user có thể vừa mua vừa bán (marketplace C2C).

---

## 5. Luồng 1 — Đăng ký OTP / Đăng nhập / JWT

**File:** `backend/src/auth/auth.service.ts`, Flutter `lib/screens/auth/*`, `lib/services/auth_service.dart`

### 5.1 Đăng ký (2 bước)

```
[App] POST /api/auth/register/request-otp
        │  kiểm tra email disposable, trùng email/SĐT
        │  cooldown 30s; OTP TTL 5 phút; tối đa 5 lần sai
        │  OTP = randomInt(100000, 1000000)  → 6 chữ số
        │  lưu pending in-memory Map + gửi SMTP
        ▼
[App] nhập OTP → POST /api/auth/register/verify-otp
        │  đúng OTP → bcrypt.hash(password, 10)
        │  tạo User (kyc=Unverified, account=Active)
        │  trigger SQL tạo Score 500
        │  cấp access JWT + refresh token
        ▼
[App] lưu Secure Storage → vào Marketplace
```

### 5.2 Đăng nhập / Refresh

- Login bằng **email hoặc SĐT** + mật khẩu.
- Access JWT payload: `{ sub, email, isAdmin }`, mặc định hết hạn ~15 phút.
- Refresh token: `randomBytes(48)` hex, lưu **SHA-256** trong DB, rotate khi dùng lại (revoke token cũ).
- Flutter: khi API trả 401 → gọi refresh một lần (single-flight) rồi retry.

### 5.3 Quên mật khẩu

- `forgot` luôn trả thông điệp trung tính (không lộ email có tồn tại hay không).
- Reset thành công → revoke mọi refresh token chưa thu hồi.

### 5.4 Bảo mật liên quan

- Throttler toàn cục (~100 req/60s); một số route OTP throttle riêng.
- Production: bắt buộc JWT secret đủ dài, SMTP, CORS.
- Chỉ tài khoản `Active` mới qua JWT strategy; `Locked` có thể tự mở nếu hết `lockedUntil`.

---

## 6. Luồng 2 — eKYC 3 bước (định danh)

Đây là **trụ cột an toàn** của đề tài — nên trình bày kỹ.

**UI:** `lib/screens/identity_verification.dart`, `liveness_challenge_screen.dart`  
**API:** `backend/src/ekyc/*`  
**Session server:** `ekyc-session.service.ts`

### 6.1 Vì sao cần session phía server?

Client không được tự bịa số CCCD / họ tên khi submit.  
Server tạo session, khóa dữ liệu OCR từng bước; quay lại bước trước thì **xóa** bước sau (tránh bỏ qua liveness).

### 6.2 Các bước end-to-end

```
0. POST /ekyc/session/start          → sessionId (TTL ~30 phút)
1. POST /ekyc/scan-id-front          → OCR mặt trước CCCD (+ QR chip bổ sung nếu thiếu)
2. POST /ekyc/scan-id-back           → OCR mặt sau (ngày cấp, nơi cấp…)
3. Liveness trên máy (ML Kit)
      nhìn thẳng → quay trái → quay phải
      → selfie + recognitionPoints
   POST /ekyc/liveness/complete      → server phát livenessToken (HMAC)
4. POST /ekyc/face-match             → so selfie với ảnh chân dung CCCD
5. POST /ekyc/submit                 → profile Pending; chờ Admin duyệt
```

### 6.3 Provider OCR

- `EKYC_OCR_PROVIDER = vnpt | fpt`
- Ưu tiên VNPT nếu cấu hình đủ; lỗi token → fallback FPT.
- CCCD hợp lệ: 9 hoặc 12 số; chống trùng CCCD nếu user khác đã Pending/Verified.

### 6.4 Liveness token (chống giả client)

1. Client hoàn thành challenge Face Detection.  
2. Server kiểm tra `recognitionPoints ≥ EKYC_MIN_RECOGNITION_POINTS` (mặc định **8**).  
3. Phát token dạng `ekyc.{sessionId}.{random}` → lưu **HMAC-SHA256**.  
4. Submit phải mang token; verify bằng `timingSafeEqual`.

### 6.5 Face-match

- Gọi FPT (hoặc mode attested khi không có key / đã qua Face ID thiết bị — dùng khi demo).  
- Ngưỡng similarity mặc định **0.72** (`EKYC_FACE_MATCH_THRESHOLD`).  
- `isMatch = (API nói match) OR (similarity ≥ 0.72)`.

### 6.6 Sau khi nộp

- `Users.kyc_status = Pending`  
- Admin approve → `Verified` + **+50** điểm (`EKYC_VERIFIED`)  
- Admin reject → `Rejected` + lý do; user nộp lại được  

**Gate nghiệp vụ:** Chỉ `Verified` mới được **đăng bán** và **đặt mua**.

---

## 7. Luồng 3 — Đăng bán & duyệt chợ

**Files:** `post_product_screen.dart`, `products.service.ts`, `marketplace_home.dart`

### 7.1 Đăng tin (Seller)

Điều kiện server: `kycStatus === Verified`.  
Validation client tiêu biểu:

- Giá > 50.000đ  
- Độ bền (condition) ≥ 65%  
- Mô tả ≤ 200 ký tự  
- Có ảnh  

SP mới: `status = Available`.

### 7.2 Tìm kiếm / lọc (không phải ML)

API hỗ trợ filter: danh mục, từ khóa, khoảng giá, địa điểm, chỉ seller đã Verified.  
Sort: `newest | oldest | price_asc | price_desc` — **ORDER BY**, không ranking học máy.

Listing công khai chỉ hiện `Available | Reserved` (tùy cấu hình list hiện tại).

---

## 8. Luồng 4 — Chat → Đặt mua → Escrow → Hoàn tất

Đây là **luồng nghiệp vụ dài nhất** — nên vẽ lên bảng khi bảo vệ.

### 8.1 Chat realtime

**Flutter:** `ChatService` → `FirebaseChatService`  
Cây RTDB:

```
safemarket/threads/{threadKey}
safemarket/messages/{threadKey}/...
safemarket/userThreads/{userId}/...
```

`threadKey = min(userA,userB)_max(userA,userB)_productId` — ổn định, không tạo thread trùng.

Loại tin: `TEXT`, `IMAGE`, `PRODUCT_CARD`, `PURCHASE_REQUEST`, `SALE_CONFIRMED`.  
Ảnh chat: upload NestJS → lưu URL lên Firebase.

**Cảnh báo tín nhiệm:** nếu điểm đối phương `< 300` → snackbar gợi ý dùng escrow.

### 8.2 Tạo đơn từ chat

```
Buyer chọn phương thức mua (dialog):
  1) ONLINE_ESCROW + DIRECT   (khuyến nghị)
  2) ONLINE_ESCROW + SHIP     (khuyến nghị)
  3) CASH + DIRECT

→ NestJS POST /orders (trong transaction)
   - Pessimistic lock Product
   - Chỉ khi Available → Reserved (CAS)
   - Order status = Pending
→ Firebase: tin PURCHASE_REQUEST + gắn orderId
```

**Chống bán trùng (double-sell):**  
Transaction + `pessimistic_write` + điều kiện `Available → Reserved` + UNIQUE `product_id`.

### 8.3 Nhánh ONLINE_ESCROW (quan trọng nhất)

```
Pending
  │ Buyer thanh toán VNPay / simulate-pay
  ▼
Paid  (+ Payment.escrow_status = Holding)
  │ Seller xác nhận bán / ship hoặc handover
  ▼
Shipped
  │ Buyer chụp ảnh nhận hàng → POST complete (multipart proof)
  ▼
Completed
  │ Product = Sold
  │ Escrow = Released
  │ Credit ví Seller (+ điểm ORDER_COMPLETE cho cả 2 bên)
  ▼
Seller rút tiền về ngân hàng (Admin duyệt)
```

### 8.4 Nhánh CASH + DIRECT

Không qua VNPay; seller/buyer xác nhận handover → Shipped → buyer complete (vẫn có thể yêu cầu ảnh tùy rule UI).  
Không có Holding escrow online.

### 8.5 Hủy đơn & đặt lại

- Hủy được khi chưa `Completed / Cancelled / Disputed` (thường buyer hủy khi `Pending`).  
- Product về `Available`.  
- Nếu escrow đang `Holding` → `Refunded`.  
- Chat: clear `orderId` / đánh dấu request cancelled để UI không còn “Đã đặt mua” giả.

### 8.6 Khiếu nại (Dispute)

- Chỉ từ `Paid | Shipped` → `Disputed`.  
- Admin:
  - **REFUND_BUYER**: hoàn escrow, order Cancelled, SP Available, phạt seller (mặc định 50).  
  - **RELEASE_SELLER**: giải ngân seller, order Completed, SP Sold, phạt buyer (+ thưởng hoàn tất cho seller nếu chưa có).

---

## 9. Luồng 5 — Thanh toán VNPay

**Files:** `backend/src/payments/vnpay.service.ts`, `lib/services/payment_service.dart`

### 9.1 Điều kiện checkout

- Buyer của đơn  
- `paymentMethod = ONLINE_ESCROW`  
- `orderStatus = Pending`

### 9.2 Quy trình

```
POST /payments/orders/:orderId/checkout
  → tạo URL VNPay (ký HMAC-SHA512)
  → App mở trình duyệt / deep link
  → VNPay return + IPN
  → Server verify chữ ký + vnp_ResponseCode == '00'
  → capture: Order=Paid, Payment=Holding
```

**Demo:** `POST .../simulate-pay` (chỉ non-production) — tiện bảo vệ khi không gọi cổng thật.

### 9.3 Công thức chữ ký (thuật toán)

1. `amount` gửi VNPay = `Math.round(amountVND) * 100` (đơn vị xu).  
2. Sort các tham số theo key.  
3. Nối `key=value` bằng `&`.  
4. `HMAC-SHA512(data, VNPAY_HASH_SECRET)` → hex.  
5. Gắn `vnp_SecureHash` vào URL.  
6. Khi IPN/return: tính lại hash, so khớp; chỉ chấp nhận khi hợp lệ và mã `00`.

`txnRef` dạng `SM{orderId}{timestamp}` (giới hạn độ dài theo VNPay).

---

## 10. Luồng 6 — Ví & rút tiền ngân hàng

**Files:** `wallet.service.ts`, `lib/screens/wallet_screen.dart`

### 10.1 Nạp ví (tự động)

Khi escrow **Released** sau complete (hoặc Admin RELEASE):

- `creditSale` idempotent theo `ref` + type `CREDIT_SALE`  
- Tăng `Wallets.balance`

### 10.2 Rút tiền

```
Seller nhập: số tiền (≥ 10.000), ngân hàng (picker), STK, chủ TK
→ POST /wallet/withdrawals
   - Trừ balance ngay
   - Withdrawal status = Pending
   - Tối đa 3 lệnh Pending / user
→ Admin approve → Completed (không cộng lại)
→ Admin reject → Rejected + REFUND_WITHDRAW hoàn ví
```

### 10.3 Bank picker (UI)

Bottom sheet “Chọn ngân hàng”, tìm theo tên/mã (~25 NH VN), chọn → điền `bankName = "Vietcombank (VCB)"`.  
Danh sách cứng trên client (không gọi API ngân hàng mở).

---

## 11. Luồng 7 — Đánh giá, báo cáo, khiếu nại, Admin

### 11.1 Review

- Chỉ đơn `Completed`.  
- Mỗi bên (buyer↔seller) review **một lần** / order.  
- Rating 1–5 → áp dụng delta điểm cho **người được đánh giá** (xem mục 12).

### 11.2 Report

Category → severity:

| Category | Severity |
|----------|----------|
| SCAM, FAKE_OR_BANNED, HARASSMENT | **high** |
| MISLEADING, OFFENSIVE_SPAM, OTHER | **medium** |

Admin resolve / reject; high có thể trừ điểm qua trigger/SQL.

### 11.3 Admin dashboard (Flutter)

Menu: Tổng quan · Người dùng · Xếp hạng tín nhiệm · Phê duyệt eKYC · Báo cáo · Khiếu nại đơn · Duyệt rút tiền · Danh sách đen · Xuất PDF báo cáo.

Hành động kỷ luật: warn, lock, suspend (1–365 ngày), ban, punish (−điểm), soft-delete, unlock.

---

## 12. Thuật toán & công thức cần thuộc

> Phần này **hay bị hỏi** — nên thuộc lòng số và điều kiện.

### 12.1 Thuật toán xếp hạng tín nhiệm (cốt lõi đề tài)

**Không gian điểm:** số nguyên \(P \in [0, 1000]\).  
**Khởi tạo:** \(P_0 = 500\), hạng Bronze (trigger khi tạo User).

**Cập nhật khi có sự kiện:**

\[
P' = \mathrm{clamp}(P + \Delta,\ 0,\ 1000)
\]

\[
\mathrm{clamp}(x,a,b) = \max(a,\ \min(b,x))
\]

**Ánh xạ hạng:**

| Điều kiện điểm | Hạng | Ý nghĩa UI |
|----------------|------|------------|
| \(P < 300\) | Bronze (Đồng) | Thấp — cảnh báo chat |
| \(300 \le P < 600\) | Silver (Bạc) | Trung bình |
| \(600 \le P < 850\) | Gold (Vàng) | Tốt |
| \(P \ge 850\) | Diamond (Kim cương) | Cao nhất |

**Bảng \(\Delta\) (đúng với code hiện tại):**

| Sự kiện | \(\Delta\) | reasonCode |
|---------|------------|------------|
| eKYC Admin duyệt | **+50** | `EKYC_VERIFIED` |
| Hoàn tất đơn (mỗi bên) | **+20** | `ORDER_COMPLETE` |
| Nhận review 5★ | **+30** | `REVIEW_5_STAR` |
| Nhận review 4★ | **0** | — |
| Nhận review 3★ | **−10** | `REVIEW_3_STAR` |
| Nhận review 2★ | **−20** | `REVIEW_2_STAR` |
| Nhận review 1★ | **−30** | `REVIEW_1_STAR` |
| Report severity high | **−50** | `REPORT_HIGH` |
| Admin phạt | −1…−500 | `ADMIN_PENALTY` |
| Dispute penalty (mặc định 50) | −penalty | `DISPUTE_PENALTY` |

**Cơ chế triển khai:**  
`ReputationService.addPoints` / review/order/admin → **INSERT Point_Logs** → trigger SQL cập nhật Scores + rank.  
Tránh update Scores trực tiếp rồi lại insert log (double apply).

**Xếp hạng Admin:** User Verified ưu tiên trên Unverified; trong nhóm sort theo `trustScore`.

**Ngưỡng cảnh báo giao dịch:** `currentPoint < 300` → khuyến nghị escrow khi chat.

### 12.2 Thuật toán khóa sản phẩm (chống double booking)

Trong một transaction SQL:

1. `SELECT Product ... FOR UPDATE` (pessimistic_write).  
2. Kiểm tra `status === Available`.  
3. CAS cập nhật `Available → Reserved` + tạo/gắn Order `Pending`.  
4. UNIQUE `product_id` bảo vệ tầng DB.

Nếu 2 buyer cùng lúc: chỉ 1 transaction thắng; transaction kia fail / báo hết hàng.

### 12.3 Thuật toán chữ ký VNPay (HMAC-SHA512)

\[
H = \mathrm{HMAC\text{-}SHA512}(\mathrm{sortedQueryString},\ Secret)
\]

Chấp nhận thanh toán khi \(H\) khớp và `ResponseCode = 00`.

### 12.4 Thuật toán bảo mật phiên eKYC

1. **Thứ tự bắt buộc** các bước trong session (state machine).  
2. **Ngưỡng liveness points** \(\ge 8\).  
3. **Token** gắn session + HMAC; so khớp constant-time.  
4. **Face similarity** \(\ge 0.72\) (hoặc cờ match từ provider).  
5. Khóa CCCD/họ tên từ OCR server-side.

### 12.5 Thuật toán OTP

\[
OTP = \mathrm{randomInt}(100000,\ 1000000) \quad \text{(6 chữ số)}
\]

TTL 5 phút; cooldown gửi lại 30s; tối đa 5 lần sai; mật khẩu `bcrypt` cost 10.

### 12.6 Thuật toán refresh token

1. Sinh `randomBytes(48)` → hex.  
2. Lưu `SHA256(token)` vào DB.  
3. Mỗi lần refresh: revoke token cũ, phát token mới (`replacedBy`) — chống tái sử dụng token bị lộ.

### 12.7 Liveness trên thiết bị (client)

Dùng Google ML Kit Face Detection, chuỗi challenge:

1. Nhìn thẳng: mắt mở, \(|yaw| \le 12°\)  
2. Quay trái: \(yaw \ge 20°\)  
3. Quay phải: \(yaw \le -20°\)  

Đếm landmark/contour → `recognitionPoints` gửi server.  
**Không** tự mint liveness token ở client.

### 12.8 Lọc ngân hàng (client)

Chuẩn hóa chuỗi (bỏ dấu tiếng Việt) → `contains` trên shortName / fullName / code.  
Độ phức tạp \(O(n\cdot|q|)\) với \(n\) ~ số ngân hàng cố định (~25–30) — đủ realtime UI.

### 12.9 Những gì KHÔNG phải thuật toán phức tạp trong đồ án

- Không collaborative filtering / content-based recommendation.  
- Không blockchain escrow.  
- Không WebSocket Nest cho chat (dùng Firebase).  
- Không matching giá động / auction.

Khi hội đồng hỏi “thuật toán của em là gì?” → trả lời rõ:  
**“Thuật toán cốt lõi là mô hình điểm tín nhiệm có ngưỡng hạng + cơ chế khóa hàng & ký quỹ; các thuật toán mật mã hỗ trợ gồm OTP, bcrypt, JWT/refresh, HMAC VNPay và HMAC session eKYC.”**

---

## 13. Máy trạng thái (State Machine)

### 13.1 KYC

```
Unverified → (submit) → Pending → (admin) → Verified
                              └→ (admin) → Rejected → (nộp lại) → Pending …
```

### 13.2 Product

```
Available → Reserved → Sold
    │          └→ (cancel/refund) → Available
    └→ Hidden (seller/admin)
```

### 13.3 Order

```
Pending ──pay/confirm──► Paid ──ship/handover──► Shipped ──buyer+ảnh──► Completed
   │                       │                        │
   │                       └──────── dispute ───────┘──► Disputed ──admin──► Cancelled | Completed
   └──────── cancel ──────────────────────────────────► Cancelled
```

### 13.4 Escrow (Payment)

```
(none) → Holding → Released   (giao dịch thành công / admin release)
                 └→ Refunded  (hủy / admin refund)
```

### 13.5 Withdrawal

```
Pending → Completed | Rejected
```

### 13.6 Account

```
Active ↔ Locked (tạm)
Active → Banned / Deleted (soft)
```

---

## 14. Bản đồ mã nguồn quan trọng

### 14.1 Backend (NestJS)

| Nội dung | Path |
|----------|------|
| OTP / JWT / refresh | `backend/src/auth/auth.service.ts` |
| JWT validate | `backend/src/auth/strategies/jwt.strategy.ts` |
| eKYC session & ngưỡng | `backend/src/ekyc/ekyc-session.service.ts` |
| OCR VNPT/FPT | `backend/src/ekyc/vnpt-ekyc.service.ts`, `fpt-ai.service.ts`, `ocr-provider.service.ts` |
| Đơn / escrow / +20 điểm | `backend/src/orders/orders.service.ts` |
| VNPay HMAC | `backend/src/payments/vnpay.service.ts` |
| Ví / rút | `backend/src/wallet/wallet.service.ts` |
| Review ± điểm | `backend/src/reviews/reviews.service.ts` |
| Reputation clamp/rank | `backend/src/reputation/reputation.service.ts` |
| Admin / dispute | `backend/src/admin/admin.service.ts` |
| Chat Nest | `backend/src/chat/chat.service.ts` |

### 14.2 Flutter

| Nội dung | Path |
|----------|------|
| Entry + routes | `lib/main.dart` |
| Auth gate | `lib/screens/auth/auth_gate.dart` |
| Chợ | `lib/screens/marketplace_home.dart` |
| Chi tiết SP / đặt mua | `lib/screens/product_detail.dart` |
| Chat | `lib/screens/chat_screen.dart`, `services/firebase_chat_service.dart` |
| Chi tiết đơn / ảnh nhận hàng | `lib/screens/order_detail_screen.dart` |
| eKYC 3 bước | `lib/screens/identity_verification.dart` |
| Liveness | `lib/screens/liveness_challenge_screen.dart` |
| Ví + bank picker | `lib/screens/wallet_screen.dart` |
| Admin | `lib/screens/admin_dashboard.dart` |
| Validators | `lib/utils/input_validators.dart` |

### 14.3 SQL

| Nội dung | Path |
|----------|------|
| Schema + trigger điểm | `eKYC Market.sql` |
| Migrate ví | `backend/db/migrate-wallet-withdrawals.sql` (nếu có trong repo) |

### 14.4 Tài liệu kèm

| File | Dùng khi |
|------|----------|
| `QA_VAN_DAP.md` | Câu hỏi–đáp vấn đáp ngắn |
| `README.md` | Giải thích cấu trúc Flutter |
| File **này** | Logic + thuật toán sâu |

---

## 15. Câu hỏi hay bị hỏi & cách trả lời ngắn

**Q1. Điểm tín nhiệm tính thế nào?**  
→ Bắt đầu 500. Mỗi sự kiện ghi `Point_Logs` với \(\Delta\). Trigger clamp 0–1000 và gán hạng theo ngưỡng 300/600/850. Ví dụ: eKYC +50, hoàn tất đơn +20/bên, 5★ +30, 1★ −30.

**Q2. Làm sao chống hai người mua cùng một món?**  
→ Transaction + pessimistic lock + chỉ `Available→Reserved` + UNIQUE product trên Orders.

**Q3. Tiền escrow nằm đâu? Seller có nhận STK ngay không?**  
→ Buyer trả qua VNPay vào luồng hệ thống; Payment `Holding`. Chỉ khi buyer xác nhận nhận hàng (ảnh) mới `Released` → cộng **ví nội bộ** seller → seller rút ngân hàng (Admin duyệt). Không chuyển thẳng STK seller lúc mua.

**Q4. eKYC có phải tự code OCR không?**  
→ Tích hợp VNPT/FPT OCR; app làm UX 3 bước + active liveness trên máy; server khóa session/token/face-match.

**Q5. Chat dùng gì? Có mất đơn khi mất mạng Firebase không?**  
→ Chat Firebase; đơn/tiền/điểm ở SQL. Mất Firebase chỉ ảnh hưởng realtime chat; dữ liệu giao dịch vẫn truy vấn NestJS.

**Q6. Thuật toán có phải AI không?**  
→ Không bắt buộc AI recommendation. Cốt lõi là **rule-based reputation** + **escrow state machine** + mật mã ứng dụng (OTP, bcrypt, JWT, HMAC).

**Q7. Vì sao cần ảnh chứng từ khi complete?**  
→ Bằng chứng buyer đã nhận hàng trước khi giải ngân — giảm chargeback/lừa “chưa nhận mà tiền đã về seller”.

**Q8. Admin resolve dispute thế nào?**  
→ Hai hướng: hoàn buyer (phạt seller) hoặc giải ngân seller (phạt buyer) — cập nhật order + escrow + điểm.

---

## 16. Hạn chế thật của đồ án (nói thẳng)

Nói hạn chế **có chủ đích** sẽ được điểm trung thực:

1. OTP đăng ký lưu **in-memory** → restart server mất pending OTP (nên chuyển Redis/DB khi production).  
2. Bank list cứng trên app — chưa nối open-banking / VietQR động.  
3. Chat Nest SQL tồn tại song song Firebase — nguồn chat chính lúc demo là Firebase.  
4. Không có recommendation ML / chống gian lận hành vi nâng cao (device fingerprint, graph fraud).  
5. VNPay/eKYC phụ thuộc cấu hình key môi trường; demo có `simulate-pay` / attested face-match.  
6. Một số copy UI có thể nhắc phạt hủy −30 trong khi API hủy **không tự trừ** −30 (phạt chủ yếu qua review/dispute/admin) — nếu bị hỏi, nói đúng theo **code API**.

---

## 17. Checklist ôn 7 ngày

### Ngày 1–2: Nắm kiến trúc & demo được

- [ ] Vẽ được sơ đồ 4 khối: Flutter – NestJS – SQL – Firebase  
- [ ] Demo: đăng ký OTP → eKYC (hoặc account sẵn Verified) → đăng SP → đặt mua escrow → complete  
- [ ] Demo Admin: duyệt eKYC / duyệt rút / xem ranking  

### Ngày 3–4: Thuộc số & state machine

- [ ] Thuộc bảng \(\Delta\) điểm và ngưỡng hạng 300/600/850  
- [ ] Thuộc Order: Pending→Paid→Shipped→Completed (+ Cancel/Dispute)  
- [ ] Thuộc Escrow: Holding→Released/Refunded  
- [ ] Thuộc eKYC thresholds: points≥8, similarity≥0.72, +50 khi duyệt  

### Ngày 5: Đi từng file code chính

- [ ] Mở và giải thích được 5 file: `orders.service.ts`, `ekyc-session.service.ts`, `vnpay.service.ts`, `reviews.service.ts`, `reputation` + trigger SQL  
- [ ] Flutter: `chat_screen`, `order_detail_screen`, `identity_verification`  

### Ngày 6: Vấn đáp

- [ ] Đọc `QA_VAN_DAP.md` + file này  
- [ ] Tập trả lời Q1–Q8 mục 15 **dưới 1 phút/câu**  
- [ ] Chuẩn bị câu “hạn chế & hướng phát triển” (mục 16)  

### Ngày 7: Chạy thử máy bảo vệ

- [ ] Backend + SQL + app chạy ổn  
- [ ] Có sẵn 2 tài khoản buyer/seller Verified + 1 admin  
- [ ] Có phương án demo khi mất mạng VNPay (`simulate-pay`)  

---

## Phụ lục A — Sơ đồ sequence Escrow (tóm tắt nói miệng)

1. Buyer mở chat SP → chọn ONLINE_ESCROW.  
2. Server khóa SP `Reserved`, tạo Order `Pending`.  
3. Buyer checkout VNPay → IPN hợp lệ → `Paid` + `Holding`.  
4. Seller xác nhận / giao hàng → `Shipped`.  
5. Buyer upload ảnh nhận hàng → `Completed` + `Released` + credit ví + `ORDER_COMPLETE +20`.  
6. Seller rút ví → Admin duyệt → tiền về STK ngân hàng.

## Phụ lục B — Sơ đồ sequence eKYC (tóm tắt nói miệng)

1. Start session.  
2. OCR mặt trước / mặt sau (VNPT hoặc FPT).  
3. Active liveness trên máy → server cấp token.  
4. Face-match ≥ 0.72.  
5. Submit → Pending → Admin duyệt → Verified +50 điểm → được mua/bán.

## Phụ lục C — Công thức nhớ nhanh (1 trang A5)

```
Điểm: 500 ban đầu | 0..1000 | hạng: <300 Đồng | <600 Bạc | <850 Vàng | ≥850 KC
Δ: eKYC+50 | xong đơn+20 | 5★+30 | 4★0 | 3★-10 | 2★-20 | 1★-30 | report high-50
Escrow: Holding → Released (đủ ảnh) | Refunded (hủy/dispute hoàn)
Khóa SP: Transaction + pessimistic + Available→Reserved
VNPay: amount*100 + sort + HMAC-SHA512
eKYC: session bắt buộc thứ tự | points≥8 | sim≥0.72 | Admin +50
OTP: 6 số | 5 phút | bcrypt10 | JWT + refresh SHA256 rotate
```

---

*Hết file. In mục 12, 13, 15 và Phụ lục C mang theo lúc bảo vệ. Kết hợp `QA_VAN_DAP.md` để luyện nói.*
