# PHẢN BIỆN HỘI ĐỒNG CNTT — SafeMarket (Chuyên sâu Logic · Dữ liệu · Code)

> **Mục đích:** Chuẩn bị buổi phản biện với hội đồng CNTT (thứ Sáu).  
> Thầy **không hỏi kiểu phổ thông** — hỏi logic, luồng dữ liệu, concurrency, escrow, điểm tín nhiệm, eKYC session, chỗ code cụ thể.  
> **Nguyên tắc trả lời:** Khái niệm → Bảng/trường → Hàm/file → Edge case → Hạn chế (nếu có).  
> **Không phóng đại.** Nói đúng code đang làm.  
> Tài liệu kèm: `LOGIC_LUONG_VA_THUAT_TOAN_BAO_VE.md`, `QA_VAN_DAP.md`.

---

## Cách dùng tài liệu này trong 4–5 ngày còn lại

| Ngày | Việc |
|------|------|
| D1 | Học **Lộ trình đọc code** (mục 0) — mở đúng file, chạy thử 1 giao dịch escrow |
| D2 | Học thuộc **Escrow + Order lock + Wallet** (mục 3, 4, 5) — đây là chỗ thầy hỏi nhiều nhất |
| D3 | Học **Điểm tín nhiệm + Trigger SQL + eKYC session** (mục 6, 7) |
| D4 | Học **Auth/JWT, Firebase vs SQL, Admin dispute** + luyện nói Q&A mục 2–11 |
| D5 (trước thứ 6) | Chỉ ôn **mục 12 (bẫy)**, **mục 13 (thầy mở code)**, Phụ lục nhớ nhanh |

**Cách nói khi bị hỏi code:**  
1. “Em xin chỉ vào hàm `X` trong file `Y`.”  
2. Nêu **input / precondition**.  
3. Nêu **thay đổi dữ liệu** (bảng nào, status nào → nào).  
4. Nêu **vì sao** thiết kế vậy (race, idempotent, audit).  
5. Nếu UI lệch backend: nói thẳng “UI cảnh báo… nhưng API hiện **chưa** trừ điểm.”

---

# 0. LỘ TRÌNH HỌC HIỂU CODE CHUYÊN SÂU (theo thứ tự bắt buộc)

Đọc **theo thứ tự dưới** — không nhảy lung tung. Mỗi bước phải trả lời được câu hỏi kiểm tra.

## Tầng 0 — Bản đồ hệ thống (30 phút)

| File | Việc phải nắm |
|------|----------------|
| `backend/src/main.ts` | prefix `/api`, ValidationPipe, Helmet, CORS |
| `backend/src/app.module.ts` | các module được import |
| `lib/main.dart` | resolve API → Firebase → `AuthGate` |
| `lib/screens/auth/auth_gate.dart` | khách xem chợ; không bắt login ngay |
| `eKYC Market.sql` | 5 schema + CHECK + trigger điểm |

**Kiểm tra:** Vẽ được Flutter → Nest → SQL và nhánh Firebase riêng cho chat.

## Tầng 1 — Dữ liệu cốt lõi (1 buổi)

Đọc entity + SQL song song:

| Entity | Bảng | Trường sống còn |
|--------|------|-----------------|
| `user.entity.ts` | `Identity.Users` | `kycStatus`, `accountStatus`, `isAdmin` |
| `product.entity.ts` | `Market.Products` | `status`, `sellerId`, `price` |
| `order.entity.ts` | `Finance.Orders` | `orderStatus`, **unique `productId`**, payment/delivery |
| `payment.entity.ts` | `Finance.Payments` | `escrowStatus`, `amount`, unique order |
| `score.entity.ts` / `point-log.entity.ts` | Reputation | điểm + nhật ký delta |
| `wallet.entity.ts` / `wallet-transaction` / `withdrawal` | Finance (migrate) | balance, ref idempotent |

**Kiểm tra:** Nói được UNIQUE `product_id` trên Orders dùng để làm gì.

## Tầng 2 — Auth (nửa buổi)

1. `auth.service.ts`: `requestOtp` → `verifyOtp` → `login` → `refresh` → `logout`  
2. `jwt.strategy.ts`: validate Active / tự mở Locked hết hạn  
3. Flutter `auth_service.dart`: Secure Storage + refresh single-flight  

**Kiểm tra:** OTP nằm RAM hay DB? Refresh rotate thế nào?

## Tầng 3 — eKYC (1 buổi)

1. `ekyc-session.service.ts` (state machine)  
2. `ekyc.controller.ts` + `ekyc.service.ts` (submit)  
3. `ocr-provider.service.ts` / VNPT / FPT  
4. Flutter: `identity_verification.dart` + `liveness_challenge_screen.dart`  

**Kiểm tra:** Bỏ bước liveness submit được không? Token ai phát?

## Tầng 4 — Order + Escrow + Payment + Wallet (2 buổi — quan trọng nhất)

Thứ tự đọc hàm:

```
OrdersService.createOrder
  → PaymentsService (checkout / captureEscrow / simulate)
  → OrdersService.confirmPayment | markShipped | confirmHandover
  → OrdersService.complete
  → PaymentsService.releaseEscrow
  → WalletService.creditSale
  → ReputationService.adjustPoints (+20)
  → OrdersService.cancel / dispute
  → AdminService.resolveDispute
  → WalletService.requestWithdrawal / admin approve|reject
```

Flutter song song: `chat_service.dart` → `order_detail_screen.dart` → `payment_service.dart` → `wallet_screen.dart`.

**Kiểm tra:** Hai người bấm mua cùng lúc — dữ liệu đổi ra sao? Tiền seller nằm bảng nào?

## Tầng 5 — Reputation + Review + Report (nửa buổi)

1. Trigger `trg_UpdateScoreAndRank` trong SQL  
2. `reputation.service.ts` → chỉ INSERT log  
3. `reviews.service.ts` → delta theo sao  
4. `admin.service.ts` → eKYC +50, dispute penalty  

**Kiểm tra:** Ai cập nhật cột `current_point` — Nest hay trigger?

## Tầng 6 — Chat hybrid (nửa buổi)

1. `firebase_chat_service.dart` — cây RTDB, threadKey  
2. `chat_service.dart` — `sendPurchaseRequest` gọi Nest rồi ghi Firebase  
3. `getThreadDetail` — enrich order từ Nest (chống lệch)  

**Kiểm tra:** Source of truth của `orderStatus` là đâu?

## Tầng 7 — Admin & cạnh (nửa buổi)

`admin.service.ts` + `admin_dashboard.dart`: duyệt eKYC, ranking, report, dispute, rút tiền, lock/ban.

---

# 1. CHIẾN LƯỢC TRẢ LỜI HỘI ĐỒNG CNTT

### Mẫu câu trả lời “đạt điểm kỹ thuật”

> “Luồng này đi từ client gọi API `POST /api/orders`. Trong `OrdersService.createOrder`, em mở transaction, `pessimistic_write` trên Product và Order theo `productId`. Chỉ khi `status = Available` mới CAS sang `Reserved` và tạo/tái dùng Order `Pending`. Nhờ UNIQUE `product_id`, không tồn tại hai đơn active trên cùng sản phẩm. Tiền chưa vào ví seller lúc này — ví chỉ tăng khi `complete` gọi `releaseEscrow` rồi `creditSale` với ref `ORDER-{id}`.”

### Việc không được làm

- Không nói “AI xếp hạng” nếu không có model ML.  
- Không nói “tiền nằm ngân hàng trung gian thật” nếu chỉ là trạng thái `Holding` + VNPay sandbox.  
- Không đoán hàm — nói “em xin mở file…”.

---

# 2. KIẾN TRÚC & LUỒNG DỮ LIỆU (hỏi sâu)

### Q2.1. Source of truth của hệ thống nằm ở đâu? Firebase có phải DB chính không?

**Trả lời:**  
Source of truth giao dịch là **SQL Server qua NestJS**: Users, Products, Orders, Payments, Scores, Wallets.  
Firebase RTDB chỉ phục vụ **chat realtime** và snapshot hiển thị (`orderId`, `orderStatus`, thông tin SP trên thread).  
Nếu Firebase lệch, Flutter có `getThreadDetail` đọc lại order từ Nest để sửa UI.  
**Không** dùng Firebase để cộng tiền / cộng điểm.

### Q2.2. Vì sao tách chat Firebase nhưng đơn hàng Nest?

**Trả lời:**  
Chat cần latency thấp, fan-out tin nhắn — RTDB phù hợp.  
Đơn hàng cần ACID, khóa hàng, ràng buộc UNIQUE, audit tiền — SQL + transaction.  
Kiến trúc hybrid: **realtime UX** vs **consistency tài chính**.

### Q2.3. Một thao tác “Đặt mua” trong chat đụng những store nào?

**Trả lời (theo thứ tự):**  
1. Flutter validate login + eKYC.  
2. `OrderService.createOrder` → Nest → SQL: lock Product, Order Pending, Product Reserved.  
3. Firebase: gửi message `PURCHASE_REQUEST`, gắn `orderId`/`orderStatus` lên thread.  
4. (Tuỳ) Notification Nest.  
→ Hai store: SQL (chuẩn) + Firebase (hiển thị).

### Q2.4. Client có được tin field `orderStatus` trên Firebase không?

**Trả lời:**  
Không tuyệt đối. Firebase có thể bị ghi lệch (ví dụ confirm sale từng ghi `Paid` cứng).  
UI quan trọng (thanh toán, complete) lấy từ Nest `GET /orders/:id`.  
Firebase dùng để list chat cập nhật nhanh.

### Q2.5. TypeORM `synchronize: false` nghĩa là gì với đồ án?

**Trả lời:**  
Schema do script SQL / migrate quản lý, không để TypeORM tự sửa DB khi start.  
Tránh lệch production; entity phải khớp tay với `eKYC Market.sql` + migrate ví.

---

# 3. ORDER · RACE CONDITION · KHÓA HÀNG (chắc chắn bị hỏi)

### Q3.1. Hai buyer cùng lúc đặt một SP — code xử lý ra sao?

**File:** `backend/src/orders/orders.service.ts` → `createOrder`

**Trả lời từng lớp:**  
1. `dataSource.transaction(...)`  
2. `findOne(Product, { lock: pessimistic_write })` → hàng bị khóa đến hết transaction.  
3. Kiểm tra `status === 'Available'` (Reserved/Sold/Hidden → lỗi).  
4. `findOne(Order, { productId, lock: pessimistic_write })`.  
5. Nếu đã có order khác Cancelled → **UPDATE reuse** dòng (vì UNIQUE product_id).  
6. `UPDATE Product WHERE status='Available' SET status='Reserved'` — nếu `affected = 0` → Conflict.  
→ Buyer thứ hai nhận Conflict / không đặt được.

**Thuật ngữ nên nói:** pessimistic locking, compare-and-set (CAS) trên status, uniqueness constraint.

### Q3.2. Vì sao UNIQUE `product_id` trên Orders? Sao không tạo order mới mỗi lần?

**Trả lời:**  
Một sản phẩm vật lý chỉ bán một lần trong mô hình này. UNIQUE ngăn hai đơn active.  
Khi hủy, SP về Available; lần đặt sau **tái dùng** dòng Cancelled (reset buyer, status Pending, clear dispute…) thay vì INSERT — nếu INSERT sẽ vi phạm UNIQUE.

### Q3.3. `Reserved` khác `Sold` thế nào?

| Status | Ý nghĩa dữ liệu |
|--------|-----------------|
| `Available` | Đang rao, chưa ai giữ |
| `Reserved` | Đã có order đang chạy (Pending/Paid/Shipped/Disputed…) |
| `Sold` | Đã Completed thành công |
| `Hidden` | Seller/admin ẩn, không mua |

Reserved ≠ đã nhận tiền. Paid mới là đã capture escrow (online).

### Q3.4. Admin có mua hàng được không? Buyer tự mua SP mình?

**Trả lời:**  
`createOrder` chặn `buyer.isAdmin` và chặn `sellerId === buyerId`.  
Lý do: tách vai trò kiểm duyệt / tránh tự giao dịch ảo tạo điểm.

### Q3.5. Điều kiện tiên quyết tạo đơn về KYC?

**Trả lời:**  
`buyer.kycStatus === 'Verified'`. Unverified/Pending/Rejected → 403.  
Đăng bán phía Products cũng bắt Verified.

### Q3.6. Thầy hỏi: “Em lock rồi còn cần UPDATE … WHERE Available không?”

**Trả lời:**  
Có. Lock giảm race trong DB này, nhưng CAS `WHERE status='Available'` là lớp phòng thủ kép: nếu trạng thái đổi bất thường giữa đọc và ghi, `affected=0` → fail an toàn. Pattern phòng thủ theo chiều sâu.

---

# 4. ESCROW · COMPLETE · CANCEL · DISPUTE (logic tiền)

### Q4.1. “Escrow” trong đồ án em là gì — có tài khoản ngân hàng trung gian không?

**Trả lời trung thực:**  
Escrow **logic nghiệp vụ**: bảng `Payments.escrow_status` ∈ {Holding, Released, Refunded}.  
Buyer thanh toán VNPay (sandbox) / `simulate-pay` → hệ thống ghi nhận Holding gắn order.  
**Chưa** phải mô hình ngân hàng giữ tiền đa bên thật (custodial bank).  
Seller **không** nhận STK ngay; chỉ khi Released → cộng `Wallets.balance` → rút (Admin duyệt).

### Q4.2. Luồng dữ liệu ONLINE_ESCROW từ đầu đến cuối?

```
Order Pending | Product Reserved | (chưa có Payment Holding nếu online chưa trả)
    ↓ checkout + IPN/simulate hợp lệ
Order Paid | Payment Holding
    ↓ seller ship/handover
Order Shipped
    ↓ buyer complete + ảnh proof
Order Completed | Product Sold | Payment Released
    ↓ creditSale(seller, amount, ref=ORDER-{id})
Wallet.balance += amount | WalletTransaction CREDIT_SALE
    ↓ (+20 điểm mỗi bên qua Point_Logs)
Seller POST withdrawal → Pending (trừ balance)
    ↓ Admin approve
Withdrawal Completed
```

### Q4.3. `complete` bắt buộc gì? Ai được gọi?

**Hàm:** `OrdersService.complete` + controller bắt multipart `proof`.

- Chỉ **buyer**.  
- Bắt buộc `receiptProofUrl` (file proof).  
- Seller phải đã giao: `Shipped` (hoặc legacy Paid+CASH+DIRECT).  
- Side effects: Completed, Sold, releaseEscrow, creditSale, +20 điểm × 2 (idempotent key `ORDER-{id}`).

### Q4.4. Vì sao bắt buộc ảnh nhận hàng?

**Trả lời:**  
Bằng chứng buyer xác nhận đã nhận trước khi giải ngân — giảm gian lận “chưa nhận hàng mà tiền về seller”.  
Admin mở dispute vẫn xem được proof URL.

### Q4.5. Hủy đơn thay đổi dữ liệu thế nào? Có trừ điểm không?

**Hàm:** `OrdersService.cancel`

- Cho phép khi chưa Completed/Cancelled/Disputed (rule trong service).  
- Order → Cancelled + cancelReason.  
- Product → Available.  
- ONLINE_ESCROW Holding → `refundEscrow` → Refunded.  
- **Không** gọi `adjustPoints`.  

⚠️ **Bẫy UI:** `order_detail_screen.dart` có chữ “Hủy đơn sau thanh toán: −30 điểm” — **backend không trừ**.  
Khi bị hỏi: nói đúng API; thừa nhận UI cảnh báo chưa khớp rule (hướng sửa: hoặc bỏ text, hoặc implement penalty).

### Q4.6. Dispute user khác Admin resolve thế nào?

**User:** `OrdersService.dispute` — chỉ từ Paid|Shipped → Disputed + loại/note.  
**Admin:** `AdminService.resolveDispute`

| Decision | Order | Product | Escrow/Ví | Điểm |
|----------|-------|---------|-----------|------|
| `REFUND_BUYER` | Cancelled | Available | Refunded | trừ **seller** (mặc định 50) |
| `RELEASE_SELLER` | Completed | Sold | Released + creditSale | trừ **buyer**; seller +20 ORDER_COMPLETE (idempotent) |

`penaltyPoints` clamp 0–200; mặc định 50.  
⚠️ UI từng ghi −80/−60 theo loại khiếu nại — **backend không hardcode 80/60**.

### Q4.7. `creditSale` idempotent bằng gì? Vì sao cần?

**Hàm:** `WalletService.creditSale`  
Tìm `WalletTransaction` `(userId, ref, type='CREDIT_SALE')`. Đã có → return.  
Chưa có → transaction tăng balance + insert txn.  
`ref = ORDER-{orderId}`.  
→ Gọi `complete` / admin RELEASE hai lần không cộng tiền đôi.

### Q4.8. `releaseEscrow` / `refundEscrow` có kiểm tra trạng thái không?

**Có.** Chỉ từ `Holding` → Released hoặc Refunded.  
Gọi lại khi đã Released sẽ không “release lần nữa” theo guard trong `PaymentsService`.

### Q4.9. BANK_TRANSFER lúc tạo đơn tạo Payment Holding ngay — khác ONLINE thế nào?

**Trả lời:**  
Trong `createOrder`, nếu `paymentMethod === 'BANK_TRANSFER'` thì tạo/reset Payment Holding ngay (mô hình chuyển khoản thủ công + seller confirm).  
`ONLINE_ESCROW` Holding thường phát sinh khi **capture** sau VNPay/simulate (order Pending → Paid).  
Dialog Flutter hiện tại ưu tiên ONLINE_ESCROW và CASH; BANK_TRANSFER còn trong model/đơn cũ.

### Q4.10. CASH + DIRECT có qua ví không?

**Trả lời:**  
Không qua VNPay/Holding online. Giao tiền mặt.  
Complete vẫn có thể yêu cầu ảnh (UI/server rule). Không `creditSale` từ escrow online.

---

# 5. VNPAY · CHỮ KÝ · DEMO PAY

### Q5.1. Chữ ký VNPay tính thế nào? (thầy thích hỏi mật mã ứng dụng)

**File:** `backend/src/payments/vnpay.service.ts`

1. `vnp_Amount = round(VND) * 100`  
2. Sort param theo key  
3. Nối `key=value` bằng `&`  
4. `HMAC-SHA512(data, VNPAY_HASH_SECRET)` → hex  
5. Gắn `vnp_SecureHash`  
6. Return/IPN: tính lại, so khớp; `vnp_ResponseCode === '00'` mới capture  

### Q5.2. IPN và Return khác nhau vai trò?

**Trả lời:**  
Return: browser quay lại (UX).  
IPN: server-to-server xác nhận (đáng tin hơn).  
Hệ thống nên (và code có endpoint) xử lý capture khi chữ ký hợp lệ — không chỉ tin query trên Return.

### Q5.3. `simulate-pay` dùng khi nào? Production có không?

**Trả lời:**  
Chỉ môi trường non-production / cấu hình cho demo bảo vệ khi không gọi cổng thật.  
Production phải tắt; chỉ VNPay thật + secret.

### Q5.4. Sau thanh toán thành công, bảng nào đổi trước?

**Trả lời:**  
`Payments` → Holding (upsert theo order) + `Orders.orderStatus = Paid`.  
Wallet **chưa** đổi. Product vẫn Reserved (chưa Sold).

---

# 6. ĐIỂM TÍN NHIỆM · TRIGGER · REVIEW (thuật toán đề tài)

### Q6.1. Pipeline cập nhật điểm — ai ghi gì?

```
Sự kiện nghiệp vụ (complete / review / admin / report…)
    → INSERT Reputation.Point_Logs (delta, reason_code, note, user_id)
    → TRIGGER trg_UpdateScoreAndRank
         UPDATE Scores.current_point = clamp(old+delta, 0, 1000)
         UPDATE rank_level theo ngưỡng
```

**Nest `ReputationService.adjustPoints` cố ý không UPDATE Scores trực tiếp** — comment trong code: tránh cộng/trừ 2 lần.

### Q6.2. Công thức hạng (thuộc lòng)

\[
\begin{align}
P &< 300 &&\Rightarrow \text{Bronze}\\
300 \le P &< 600 &&\Rightarrow \text{Silver}\\
600 \le P &< 850 &&\Rightarrow \text{Gold}\\
P &\ge 850 &&\Rightarrow \text{Diamond}
\end{align}
\]

Khởi tạo: trigger tạo User → Score **500 / Bronze**.

### Q6.3. Bảng delta (thuộc lòng)

| Sự kiện | Δ | reasonCode | Ghi chú |
|---------|---|------------|---------|
| eKYC duyệt | +50 | `EKYC_VERIFIED` | Admin; idempotent key `EKYC-{userId}` |
| Hoàn tất đơn | +20 / bên | `ORDER_COMPLETE` | key `ORDER-{orderId}` |
| Review 5★ | +30 | `REVIEW_5_STAR` | người được đánh giá |
| 4★ | 0 | — | |
| 3★ | −10 | `REVIEW_3_STAR` | |
| 2★ | −20 | `REVIEW_2_STAR` | |
| 1★ | −30 | `REVIEW_1_STAR` | |
| Report high | −50 | `REPORT_HIGH` | trigger SQL |
| Dispute | −penalty (mặc định 50) | `DISPUTE_PENALTY` | admin |
| Admin phạt | tùy | `ADMIN_PENALTY` | |

### Q6.4. Idempotent điểm là gì? Review có idempotent không?

**Trả lời:**  
`adjustPoints` có `idempotentKey`: tìm log cùng user + reasonCode + note chứa key → không insert lại.  
Dùng cho ORDER_COMPLETE, EKYC_VERIFIED.  
**Review** insert log theo lần đánh giá; chặn duplicate bằng business rule “1 review / (order, reviewer)” chứ không dùng idempotentKey kiểu order-complete.  
Race lý thuyết: hai request song song cùng key vẫn có thể lọt nếu không có unique constraint DB trên (user, reason, key) — hạn chế có thể thừa nhận.

### Q6.5. Vì sao có cả clamp trong Nest và trigger SQL?

**Trả lời:**  
Defense in depth. Nest chỉnh `appliedDelta` trước khi insert; trigger vẫn clamp khi cộng.  
Hạng: trigger gán theo điểm sau cộng; service có `rankFor` để trả về client sau khi refresh.

### Q6.6. Điểm < 300 ảnh hưởng giao dịch thế nào?

**Trả lời:**  
Chat: nếu peer < 300 → cảnh báo gợi ý escrow (Flutter/Nest chat path).  
Không chặn cứng mua bán chỉ vì Bronze — chủ yếu tín hiệu rủi ro.  
(Gate cứng là eKYC Verified.)

### Q6.7. “Thuật toán xếp hạng” có phải machine learning không?

**Trả lời chắc nịch:**  
**Không.** Đây là **rule-based scoring** + threshold ranking, có nhật ký audit (`Point_Logs`).  
Phù hợp khóa luận ứng dụng; có thể mở rộng ML fraud detection sau.

### Q6.8. Ai được review? Khi nào?

- Order `Completed`.  
- Buyer review seller và ngược lại — mỗi chiều một lần.  
- Delta áp lên **reviewee**.

---

# 7. eKYC SESSION · OCR · LIVENESS · FACE MATCH

### Q7.1. Vì sao eKYC phải có session server, không submit thẳng form?

**Trả lời:**  
Chống client giả số CCCD/họ tên.  
OCR kết quả **khóa trong session server**; submit chỉ được dùng dữ liệu đã scan + token liveness hợp lệ.

### Q7.2. State machine — bỏ bước được không?

**File:** `ekyc-session.service.ts`

Thứ tự: `start → front → back → liveness → faceMatch → submit`.  
Thiếu bước → lỗi.  
Quay lại bước trước → **xóa các bước sau** (ví dụ scan lại front thì mất back/liveness/face).

### Q7.3. Liveness token tạo và verify thế nào?

1. Client hoàn thành challenge ML Kit (thẳng/trái/phải), gửi `recognitionPoints`.  
2. Server: points ≥ `EKYC_MIN_RECOGNITION_POINTS` (mặc định **8**).  
3. Raw token `ekyc.{sessionId}.{random24}` → lưu **HMAC-SHA256**.  
4. Submit: verify HMAC bằng `timingSafeEqual` (chống timing attack).  
5. `consume` session → không reuse.

### Q7.4. Face-match ngưỡng?

Mặc định similarity **0.72**.  
`isMatch` nếu provider báo match **hoặc** similarity ≥ ngưỡng.  
Mode attested/demo: có thể chấp nhận khi không có key FPT (nói rõ là cấu hình demo).

### Q7.5. Session lưu đâu? Restart server?

**In-memory `Map`** — giống OTP. Restart mất session đang làm.  
Hạn chế production → chuyển Redis. Thừa nhận được điểm trung thực.

### Q7.6. OCR VNPT/FPT chọn thế nào?

`OcrProviderService`: theo config; VNPT lỗi auth → fallback FPT.  
Có bổ sung từ QR CCCD chip nếu OCR thiếu dob/address.

### Q7.7. Sau submit trạng thái user?

`kycStatus = Pending` + lưu `eKYC_Profiles`.  
Admin approve → Verified + `adjustPoints(+50)`.  
Reject → Rejected + lý do; được nộp lại.

### Q7.8. Active liveness trên máy đo gì?

ML Kit Face Detection:  
- Thẳng: mắt mở, |yaw| ≤ 12°  
- Trái: yaw ≥ 20°  
- Phải: yaw ≤ −20°  
Đếm landmark/contour → points. Token **không** mint ở client.

---

# 8. AUTH · JWT · OTP · SESSION BẢO MẬT

### Q8.1. OTP lưu ở đâu? TTL? Brute-force?

**RAM** `pending: Map` trong `AuthService`.  
TTL **5 phút**, resend cooldown **30s**, tối đa **5** lần sai.  
OTP = `randomInt(100000, 1000000)`.  
Password: `bcrypt` cost **10**.

### Q8.2. Access vs Refresh?

| Token | TTL mặc định | Lưu |
|-------|--------------|-----|
| Access JWT | ~15m | Client (Secure Storage) — payload sub/email/isAdmin |
| Refresh | ~7d | Client plain; DB lưu **SHA-256** |

Refresh: tìm hash → hợp lệ → **rotate** (revoke cũ + `replacedBy` + issue mới).

### Q8.3. Tài khoản Locked xử lý ở JWT strategy thế nào?

`jwt.strategy.ts`: nếu Locked nhưng `lockedUntil` đã qua → tự Active.  
Nếu vẫn không Active → 401.  
Ban/Deleted không vào được API bảo vệ.

### Q8.4. Quên mật khẩu có lộ email tồn tại không?

Không — response trung tính. Reset xong revoke mọi refresh của user.

### Q8.5. Throttle?

Global ThrottlerGuard (~100/60s) + throttle riêng route OTP.  
Chống spam OTP/mail.

---

# 9. WALLET · RÚT TIỀN · ADMIN DUYỆT

### Q9.1. Tiền seller “có” khi nào trong DB?

Khi `creditSale` thành công: `Wallets.balance` tăng + dòng `CREDIT_SALE`.  
Trước đó chỉ có Payment Holding (không phải balance seller).

### Q9.2. Rút tiền trừ lúc nào?

Lúc **tạo yêu cầu** (`Pending`): trừ balance ngay + `DEBIT_WITHDRAW`.  
Admin reject → `REFUND_WITHDRAW` hoàn.  
Admin approve → `Completed` (không cộng lại).  
Giới hạn ~3 Pending / user. Min UI 10.000đ.

### Q9.3. Vì sao Admin duyệt rút?

Kiểm soát thủ công chống rút quả / gian lận KYC giả — phù hợp MVP khóa luận.  
Production có thể rule tự động + ngưỡng.

### Q9.4. Bank picker có gọi API ngân hàng không?

Không — danh sách cứng client, filter bỏ dấu.  
`bankName` lưu chuỗi hiển thị (vd. `Vietcombank (VCB)`).

---

# 10. CHAT FIREBASE · ĐỒNG BỘ ĐƠN

### Q10.1. `threadKey` công thức?

`min(uidA,uidB)_max(uidA,uidB)_productId`  
→ Một cặp user + một SP = một thread ổn định.

### Q10.2. Message types?

`TEXT`, `IMAGE`, `PRODUCT_CARD`, `PURCHASE_REQUEST`, `SALE_CONFIRMED`.

### Q10.3. Nest vẫn có ChatModule SQL — app dùng không?

Có code REST chat SQL (legacy/đồ án tầng API).  
**App hiện tại** realtime = Firebase. Đừng nói “chat lưu SQL là chính” nếu demo Flutter Firebase.

### Q10.4. Hủy đơn xong chat còn hiện “Đã đặt mua”?

Đã xử lý phía client/service: clear order trên thread / đánh dấu request cancelled / bỏ qua order Cancelled khi xét active.  
Nếu thầy hỏi bug cũ: giải thích đã sync lại từ Nest + clear Firebase fields.

---

# 11. SẢN PHẨM · TÌM KIẾM · ADMIN

### Q11.1. Tìm kiếm có thuật toán đặc biệt không?

`ProductsService.findAll`: WHERE status ∈ Available|Reserved + filter category/search/price/location/verifiedOnly; ORDER BY newest/price…; TAKE 100.  
**Không** full-text rank / vector search.

### Q11.2. Admin ranking user sort thế nào?

Verified eKYC ưu tiên nhóm trên; trong nhóm sort `trustScore`.  
Không phải PageRank.

### Q11.3. Report severity?

SCAM / FAKE_OR_BANNED / HARASSMENT → high (−50 nếu trigger Open).  
MISLEADING / OFFENSIVE_SPAM / OTHER → medium.

---

# 12. CÂU BẪY & CHỖ LỆCH UI ↔ CODE (học thuộc — tránh bị bắt)

| Thầy nói / UI ghi | Sự thật trong code |
|-------------------|-------------------|
| Hủy đơn −30 điểm | `cancel` **không** trừ điểm |
| Không nhận hàng seller −80; giao sai −60 | Dispute mặc định **−50**, admin chỉnh; không map 80/60 |
| Escrow = ngân hàng giữ tiền thật | Trạng thái Payment + ví nội bộ; VNPay sandbox |
| Thuật toán AI | Rule-based scoring |
| OTP an toàn production | OTP/session eKYC **RAM** — restart mất |
| Chat = SQL | App realtime Firebase |
| Face-match luôn FPT | Có attested/demo khi thiếu key |
| Đồng bộ điểm = Nest UPDATE Scores | Nest INSERT log; **trigger** UPDATE Scores |

**Cách thoát bẫy:**  
“Dạ em xin đối chiếu đúng backend: hiện API …; phần UI … là copy cảnh báo, em ghi nhận là điểm cần chỉnh cho khớp.”

---

# 13. KỊCH BẢN “THẦY MỞ CODE” — GIẢI THÍCH THEO HÀM

Thầy có thể bảo: “Em mở `orders.service.ts` giải thích `createOrder`.”  
Học thuộc **outline nói 90 giây** sau:

### 13.1. `createOrder` (90 giây)

> Check buyer tồn tại, không admin, KYC Verified.  
> Vào transaction: lock Product, reject nếu tự mua / không Available.  
> Lock Order theo productId; nếu tồn tại và không Cancelled → Conflict; nếu Cancelled → reuse row.  
> Else insert Order Pending.  
> CAS Product Available→Reserved; affected=0 thì Conflict.  
> BANK_TRANSFER thì upsert Payment Holding.  
> Commit → trả JSON order.

### 13.2. `complete` (60 giây)

> Chỉ buyer + proofUrl.  
> Phải Shipped (hoặc legacy cash direct).  
> Set Completed, Sold, lưu receipt.  
> Nếu ONLINE_ESCROW: releaseEscrow + creditSale ref ORDER-id.  
> adjustPoints +20 hai bên idempotent.

### 13.3. `adjustPoints` (45 giây)

> delta 0 thì thôi.  
> Có idempotentKey thì tìm log cũ.  
> Tính appliedDelta trong biên 0–1000.  
> Chỉ save Point_Logs — trigger cập nhật Scores.  
> Đọc lại score trả về.

### 13.4. `creditSale` (30 giây)

> amount≤0 return.  
> Đã có txn cùng ref+CREDIT_SALE → return.  
> Transaction: +balance + insert txn.

### 13.5. `EkycSessionService.completeLiveness` / submit (60 giây)

> Phải có front+back.  
> points ≥ 8.  
> Phát token HMAC, xóa faceMatch cũ nếu re-liveness.  
> Submit: assertReady + verify token + consume + lưu profile Pending.

### 13.6. `refresh` token (45 giây)

> Hash incoming refresh → tìm DB.  
> Hết hạn/revoked → lỗi.  
> Issue access+refresh mới; revoke cũ gắn replacedBy.

### 13.7. Flutter `sendPurchaseRequest` (45 giây)

> Gọi Nest tạo order trước.  
> Thành công mới ghi Firebase PURCHASE_REQUEST + orderId.  
> Fail Nest thì không tạo tin mua giả.

---

# 14. CÂU HỎI “THIẾT KẾ / TẠI SAO” (logic)

### Q14.1. Vì sao không cộng điểm trực tiếp vào Scores trong service?

Audit trail + một cửa cập nhật (trigger) + tránh double apply khi vừa update vừa log.

### Q14.2. Vì sao trừ tiền ví lúc xin rút chứ không lúc Admin duyệt?

Giữ chỗ (hold) số dư — tránh rút vượt khi nhiều lệnh Pending.  
Reject thì hoàn. Giống hold balance.

### Q14.3. Vì sao complete không cho seller bấm?

Tránh seller tự xác nhận giả để giải ngân. Buyer là bên xác nhận đã nhận hàng (+ ảnh).

### Q14.4. Vì sao cần cả orderStatus và escrowStatus?

Tách vòng đời đơn hàng (vận hành) và vòng đời tiền (Holding/Released/Refunded).  
Order Paid vẫn có thể dispute; tiền vẫn Holding đến khi resolve.

### Q14.5. Vì sao Soft gate AuthGate (khách xem chợ)?

Tăng chuyển đổi xem hàng; hành vi rủi ro (mua/bán/chat) tạo gate mềm login+eKYC.

### Q14.6. Transaction isolation — em dùng mức nào?

TypeORM/SQL Server mặc định trong transaction + pessimistic lock row.  
Không tự set SERIALIZABLE toàn cục; dựa lock + CAS status.

---

# 15. CÂU HỎI HIỆU NĂNG · BẢO MẬT · MỞ RỘNG

### Q15.1. Bottleneck đâu?

- OCR/eKYC gọi HTTP ngoài.  
- List product TAKE 100 — ổn MVP, cần phân trang.  
- Firebase fan-out chat.  
- OTP/eKYC session RAM — không scale multi-instance.

### Q15.2. Multi-instance Nest thì OTP/eKYC vỡ?

**Có.** Map in-memory không share. Cần Redis sticky / store tập trung.

### Q15.3. SQL injection?

TypeORM parameter hóa + ValidationPipe whitelist DTO. Không nối chuỗi SQL thô từ input user.

### Q15.4. Upload ảnh nguy cơ?

Giới hạn 8MB; lưu local/uploads theo config; cần chú ý MIME/antivirus nếu production (thừa nhận chưa harden hết).

### Q15.5. Hướng phát triển nói 30 giây

Redis session/OTP; phân trang; unique constraint idempotent keys; khớp UI penalty; webhook SePay/VietQR nếu mở rộng; monitoring fraud rule; tách worker IPN.

---

# 16. BẢNG “HỎI NHANH — ĐÁP 15 GIÂY”

| Hỏi nhanh | Đáp |
|-----------|-----|
| Điểm gốc? | 500 |
| Trần/sàn? | 0–1000 |
| Ngưỡng hạng? | 300 / 600 / 850 |
| eKYC duyệt? | +50 |
| Xong đơn? | +20/bên |
| 5★ / 1★? | +30 / −30 |
| Face threshold? | 0.72 |
| Liveness points? | ≥ 8 |
| OTP TTL? | 5 phút |
| JWT access? | ~15 phút |
| Escrow release khi? | complete + proof (hoặc admin RELEASE) |
| Ví tăng khi? | creditSale sau Released |
| Chống double-sell? | lock + CAS + UNIQUE product |
| Chat DB? | Firebase (app) |
| Tiền DB? | SQL |
| Hủy có −30? | **Không** (API) |

---

# 17. KỊCH BẢN DEMO GẮN CÂU HỎI (thầy hay chặn giữa chừng)

1. **Đặt mua 2 máy cùng SP** → máy 2 Conflict — giải thích lock.  
2. **Thanh toán simulate** → chỉ Paid+Holding, ví seller chưa tăng — mở DB/API chứng minh.  
3. **Complete có ảnh** → Released + balance tăng + Point_Logs +20.  
4. **Rút tiền** → Pending trừ balance; Admin reject → hoàn.  
5. **Dispute** → REFUND vs RELEASE khác nhau trên Order/Product/Wallet/điểm.  
6. **User Bronze <300 chat** → cảnh báo escrow.

---

# 18. CHECKLIST TRƯỚC GIỜ PHẢN BIỆN

- [ ] Thuộc mục 16 (đáp 15 giây)  
- [ ] Nói trôi 13.1–13.7 không nhìn tài liệu  
- [ ] Biết 5 chỗ lệch UI (mục 12)  
- [ ] Mở sẵn IDE tại: `orders.service.ts`, `reputation.service.ts`, `wallet.service.ts`, `ekyc-session.service.ts`, `vnpay.service.ts`, trigger trong `eKYC Market.sql`  
- [ ] Backend + SQL + 2 user Verified + 1 admin sẵn  
- [ ] Phương án mất VNPay: simulate-pay  
- [ ] Không hứa tính năng không có trong code  

---

# PHỤ LỤC A — Sơ đồ dữ liệu 1 trang (vẽ bảng nếu thầy yêu cầu)

```
Users (kyc, account, is_admin)
  ├─ eKYC_Profiles (1:1)
  ├─ Scores (1:1) ← Point_Logs (N)
  ├─ Products (seller) ── status
  │     └─ Orders (UNIQUE product) ── order_status
  │           └─ Payments (1:1) ── escrow_status
  ├─ Wallets (1:1) ── Wallet_Transactions / Withdrawals
  └─ Reviews (order, reviewer, reviewee, rating)
```

# PHỤ LỤC B — Thứ tự file mở khi bị hỏi “code đâu?”

1. Khóa hàng / đơn → `orders.service.ts`  
2. Tiền escrow → `payments.service.ts` + `wallet.service.ts`  
3. Điểm → `reputation.service.ts` + SQL trigger  
4. eKYC → `ekyc-session.service.ts`  
5. Chữ ký → `vnpay.service.ts`  
6. Auth → `auth.service.ts` + `jwt.strategy.ts`  
7. Chat sync → `lib/services/chat_service.dart` + `firebase_chat_service.dart`  

# PHỤ LỤC C — Câu mở đầu nếu hồi hộp

> “Dạ em xin trình bày theo đúng implementation hiện tại của nhóm trên nhánh main: phần lõi là machine trạng thái đơn hàng kết hợp escrow trạng thái và mô hình điểm tín nhiệm rule-based ghi qua Point_Logs. Em xin đi vào chi tiết phần thầy hỏi.”

---

*In mang theo: mục 12, 13, 16 + Phụ lục B.  
Kết hợp luyện nói với `LOGIC_LUONG_VA_THUAT_TOAN_BAO_VE.md`.  
Chúc phản biện vững — nói chậm, chỉ đúng file, thừa nhận hạn chế rõ ràng.*
