# SafeMarket Backend (NestJS + SQL Server)

> Khoá luận tốt nghiệp HUFLIT 2026 — Trương Trí Hiền & Lê Tấn Lộc  
> Backend cho hệ thống Marketplace đồ cũ an toàn (eKYC + Trust Score)

---

## 1. Stack công nghệ

| Tầng | Công nghệ |
|------|-----------|
| Runtime | Node.js ≥ 18 |
| Framework | NestJS 10 |
| ORM | TypeORM 0.3 |
| Database | Microsoft SQL Server (driver `mssql`) |
| Auth | JWT + bcrypt |
| Doc | Swagger UI |

---

## 2. Yêu cầu trước khi chạy

| # | Việc | Trạng thái |
|---|------|------------|
| 1 | Đã cài Node.js + npm | bắt buộc |
| 2 | SQL Server (default instance MSSQLSERVER) đang chạy | bắt buộc |
| 3 | Đã chạy script `eKYC Market.sql` (tạo `SafeMarketDB` + 11 bảng) | bắt buộc |
| 4 | Đã chạy script `backend/db/create-app-user.sql` (tạo user `safemarket_api`) | bắt buộc |
| 5 | SQL Server bật **Mixed Mode Authentication** | bắt buộc |
| 6 | FPT.AI API key (cho module eKYC) | tuỳ chọn (Phase 3) |

### Cách bật Mixed Mode Authentication trong SSMS

1. Mở **SSMS** → connect bằng Windows Authentication
2. Chuột phải vào tên server (`HUIEN`) → **Properties**
3. Chọn tab **Security** → tick **SQL Server and Windows Authentication mode** → OK
4. Mở **Services.msc** → chuột phải **SQL Server (MSSQLSERVER)** → **Restart**

---

## 3. Cài đặt và chạy lần đầu

```bash
cd backend
npm install              # đã cài rồi, bỏ qua nếu node_modules tồn tại
npm run start:dev        # chạy ở chế độ dev với hot reload
```

Server mặc định chạy tại **http://localhost:3000**

| URL | Mục đích |
|-----|----------|
| `http://localhost:3000/api` | Prefix gốc của API |
| `http://localhost:3000/api/docs` | Swagger UI |
| `http://localhost:3000/api/auth/register` | POST đăng ký |
| `http://localhost:3000/api/auth/login` | POST đăng nhập |
| `http://localhost:3000/api/auth/me` | GET tài khoản hiện tại (cần Bearer token) |
| `http://localhost:3000/api/users/me` | GET profile + trust score + eKYC |
| `http://localhost:3000/api/users/:id` | GET profile của user khác |

---

## 4. Cấu trúc thư mục

```text
backend/
├── .env                       ← KHÔNG commit (đã trong .gitignore)
├── .env.example               ← Template biến môi trường
├── package.json
├── tsconfig.json
├── nest-cli.json
├── db/
│   └── create-app-user.sql    ← Script tạo SQL user safemarket_api
└── src/
    ├── main.ts                ← Bootstrap NestJS + Swagger
    ├── app.module.ts          ← Module gốc, cấu hình TypeORM
    ├── common/
    │   └── decorators/
    │       └── current-user.decorator.ts
    ├── entities/              ← Map 1-1 với bảng SQL
    │   ├── user.entity.ts
    │   ├── score.entity.ts
    │   ├── ekyc-profile.entity.ts
    │   └── point-log.entity.ts
    ├── auth/                  ← Module xác thực
    │   ├── auth.module.ts
    │   ├── auth.service.ts
    │   ├── auth.controller.ts
    │   ├── dto/
    │   │   ├── register.dto.ts
    │   │   ├── login.dto.ts
    │   │   └── auth-response.dto.ts
    │   └── strategies/
    │       └── jwt.strategy.ts
    └── users/                 ← Module hồ sơ + trust score
        ├── users.module.ts
        ├── users.service.ts
        ├── users.controller.ts
        └── dto/
            └── user-profile.dto.ts
```

---

## 5. Test nhanh với cURL

### Register

```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{ \"phoneNumber\": \"0359599503\", \"email\": \"hien@huflit.edu.vn\", \"password\": \"MatKhau@123\", \"displayName\": \"Truong Tri Hien\", \"location\": \"TP.HCM\" }"
```

Kết quả: trả về `accessToken` + `user`.

### Login

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{ \"identifier\": \"hien@huflit.edu.vn\", \"password\": \"MatKhau@123\" }"
```

### Lấy profile (cần Bearer token)

```bash
curl http://localhost:3000/api/users/me \
  -H "Authorization: Bearer <ACCESS_TOKEN>"
```

> Hoặc dùng file `requests.http` trong thư mục backend (cần cài extension **REST Client** trong VS Code).

---

## 6. Các Trigger SQL tự động liên quan

Backend **không tự tính điểm** — đã có trigger SQL làm:

| Trigger | Khi nào chạy | Tác dụng |
|---------|--------------|----------|
| `trg_InitializeReputation` | INSERT vào `Identity.Users` | Tự tạo `Reputation.Scores` với 500 điểm, hạng Bronze |
| `trg_UpdateScoreAndRank` | INSERT vào `Reputation.Point_Logs` | Cập nhật điểm (sàn 0, trần 1000) và đổi hạng (Bronze/Silver/Gold/Diamond) |
| `trg_SyncKycStatusOnVerify` | UPDATE `verified_at` của eKYC_Profiles | Tự đổi `Users.kyc_status = 'Verified'` |
| `trg_ReportHighSeverityPenalty` | INSERT Report severity='high' | Tự trừ 50 điểm user bị tố cáo |

→ Khi register, user **chắc chắn có** hồ sơ trust score = 500/1000.

---

## 7. Lộ trình phát triển

| Phase | Module | Trạng thái |
|-------|--------|------------|
| 2 | Auth + Users | ✅ |
| 3 | EkycModule (FPT.AI OCR + Face Match + liveness demo) | ✅ |
| 4 | Products + Categories + upload ảnh | ✅ |
| 4 | Orders + Escrow (Payments) | ✅ |
| 5 | Chat, Reviews, Reports, Admin | ✅ |
| 6 | Flutter app (`api_config.dart` → port 3000) | ✅ |

### Chat realtime (Firebase)

Tin nhắn lưu trên **Firebase Realtime Database** (không qua NestJS SQL).
Đơn hàng trong chat vẫn tạo qua API `POST /orders`.

1. Tạo project Firebase → bật Realtime Database
2. Import `database.rules.json` (thư mục gốc repo) vào Firebase Console → Rules
3. Chạy `flutterfire configure` hoặc điền `lib/firebase_options.dart` + `android/app/google-services.json`

### Migration bổ sung (chat SQL — tùy chọn, NestJS chat cũ)

Sau khi chạy `eKYC Market.sql`, chạy thêm:

```bash
# Trong SSMS hoặc sqlcmd
sqlcmd -S localhost -d SafeMarketDB -i backend/db/migrate-demo-ready.sql
```

---

## 8. Lỗi thường gặp

| Lỗi | Nguyên nhân | Cách sửa |
|-----|-------------|---------|
| `Login failed for user 'safemarket_api'` | Chưa chạy `create-app-user.sql` hoặc chưa bật Mixed Mode | Xem mục 2 |
| `Cannot open server 'localhost'` | SQL Server service tắt | Services.msc → MSSQLSERVER → Start |
| `EAI_AGAIN` / timeout | DNS hoặc firewall | Dùng IP `127.0.0.1` thay `localhost` trong `.env` |
| `409 Conflict: Email đã được sử dụng` | Đã register email/phone trước đó | Đổi email/phone hoặc DELETE record cũ |
| `401 Unauthorized` ở `/auth/me` | Thiếu header `Authorization: Bearer ...` | Copy `accessToken` từ login response |

---

## 9. Lệnh hữu ích

```bash
npm run start:dev    # dev với watch
npm run build        # build production vào dist/
npm run start:prod   # chạy bản đã build
npm run lint         # check linter
npm run format       # format Prettier
```
