-- =========================================================================
-- ĐỒ ÁN KHÓA LUẬN: HỆ THỐNG MARKETPLACE ĐỒ CŨ AN TOÀN (SAFEMARKET)
-- File: eKYC Market.sql (BẢN GỐC — tham khảo khóa luận)
--
-- KHUYÊN DÙNG: database/01-setup-schema.sql + 02-seed-demo.sql + 03-create-app-user.sql
-- (idempotent — chạy lại không báo "already exists")
-- Chi tiết: database/HUONG-DAN-DATABASE.md
--
-- Phiên bản: 2.0 (bổ sung Admin, Moderation, Profile, ảnh SP, ràng buộc)
--
-- THAY ĐỔI SO VỚI BẢN CŨ:
--   + Schema [Moderation] — báo cáo vi phạm
--   + Users: display_name, avatar, location, account_status, is_admin, UNIQUE email/phone
--   + eKYC: URL nullable khi chưa upload; rejection_reason, submitted_at
--   + Products: location, thumbnail_url; bảng Product_Images
--   + Reviews: reviewer_id, reviewee_id; comment nullable
--   + CHECK constraint trạng thái; Scores giới hạn 0–1000
--   + Index cho API; trigger điểm có sàn/trần
--   + Dữ liệu mẫu Categories; phần TEST tách rõ
-- =========================================================================

--USE master;
--GO

--IF EXISTS (SELECT name FROM sys.databases WHERE name = N'SafeMarketDB')
--BEGIN
--    ALTER DATABASE SafeMarketDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
--    DROP DATABASE SafeMarketDB;
--END
--GO

CREATE DATABASE SafeMarketDB;
GO

USE SafeMarketDB;
GO

-- ==========================================
-- BƯỚC 2: SCHEMA (LƯỢC ĐỒ)
-- ==========================================
CREATE SCHEMA [Identity];
GO
CREATE SCHEMA [Market];
GO
CREATE SCHEMA [Finance];
GO
CREATE SCHEMA [Reputation];
GO
CREATE SCHEMA [Moderation];
GO

-- ==========================================
-- BƯỚC 3: BẢNG (CHA -> CON)
-- ==========================================

-- -------------------------------------------------------------------------
-- 1. Users — đăng nhập, profile, trạng thái tài khoản (Admin khóa/ban)
-- -------------------------------------------------------------------------
CREATE TABLE [Identity].[Users] (
    [user_id]        BIGINT IDENTITY(1,1) NOT NULL,
    [phone_number]   VARCHAR(15) NOT NULL,
    [email]          VARCHAR(255) NOT NULL,
    [password_hash]  VARCHAR(255) NOT NULL,
    [display_name]   NVARCHAR(100) NULL,
    [avatar_url]     VARCHAR(500) NULL,
    [location]       NVARCHAR(100) NULL,
    [kyc_status]     VARCHAR(30) NOT NULL DEFAULT 'Unverified',
    [account_status] VARCHAR(20) NOT NULL DEFAULT 'Active',
    [is_admin]       BIT NOT NULL DEFAULT 0,
    [locked_at]      DATETIME2 NULL,
    [lock_reason]    NVARCHAR(255) NULL,
    [created_at]     DATETIME2 NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY ([user_id]),
    CONSTRAINT UQ_Users_Email        UNIQUE ([email]),
    CONSTRAINT UQ_Users_Phone        UNIQUE ([phone_number]),
    CONSTRAINT CK_Users_KycStatus    CHECK ([kyc_status] IN ('Unverified','Pending','Verified','Rejected')),
    CONSTRAINT CK_Users_AccountStatus CHECK ([account_status] IN ('Active','Locked','Banned','Deleted'))
);
GO

-- -------------------------------------------------------------------------
-- 2. Categories — danh mục Chợ (Điện tử, Thời trang...)
-- -------------------------------------------------------------------------
CREATE TABLE [Market].[Categories] (
    [category_id] INT IDENTITY(1,1) NOT NULL,
    [name]        NVARCHAR(100) NOT NULL,
    [slug]        VARCHAR(50) NULL,
    PRIMARY KEY ([category_id]),
    CONSTRAINT UQ_Categories_Name UNIQUE ([name])
);
GO

-- -------------------------------------------------------------------------
-- 3. eKYC_Profiles — 1:1 với User; URL NULL khi chưa nộp file
-- -------------------------------------------------------------------------
CREATE TABLE [Identity].[eKYC_Profiles] (
    [kyc_id]           BIGINT IDENTITY(1,1) NOT NULL,
    [id_number]        VARCHAR(20) NULL,
    [full_name]        NVARCHAR(100) NULL,
    [dob]              DATE NULL,
    [address]          NVARCHAR(255) NULL,
    [id_front_url]     VARCHAR(500) NULL,
    [id_back_url]      VARCHAR(500) NULL,
    [face_video_url]   VARCHAR(500) NULL,
    [submitted_at]     DATETIME2 NULL,
    [verified_at]      DATETIME2 NULL,
    [rejection_reason] NVARCHAR(500) NULL,
    [user_id]          BIGINT NOT NULL,
    PRIMARY KEY ([kyc_id]),
    CONSTRAINT UQ_eKYC_User UNIQUE ([user_id]),
    FOREIGN KEY ([user_id]) REFERENCES [Identity].[Users]([user_id]) ON DELETE CASCADE
);
GO

-- -------------------------------------------------------------------------
-- 4. Scores — điểm tín nhiệm 0–1000 (UI Profile: 850/1000, hạng Vàng ≈ Gold)
-- -------------------------------------------------------------------------
CREATE TABLE [Reputation].[Scores] (
    [score_id]      BIGINT IDENTITY(1,1) NOT NULL,
    [current_point] INT NOT NULL DEFAULT 500,
    [rank_level]    NVARCHAR(20) NOT NULL DEFAULT 'Silver',
    [updated_at]    DATETIME2 NOT NULL DEFAULT GETDATE(),
    [user_id]       BIGINT NOT NULL,
    PRIMARY KEY ([score_id]),
    CONSTRAINT UQ_Scores_User UNIQUE ([user_id]),
    CONSTRAINT CK_Scores_Point CHECK ([current_point] BETWEEN 0 AND 1000),
    CONSTRAINT CK_Scores_Rank CHECK ([rank_level] IN ('Bronze','Silver','Gold','Diamond')),
    FOREIGN KEY ([user_id]) REFERENCES [Identity].[Users]([user_id]) ON DELETE CASCADE
);
GO

-- -------------------------------------------------------------------------
-- 5. Point_Logs — nhật ký cộng/trừ điểm (trigger cập nhật Scores)
-- -------------------------------------------------------------------------
CREATE TABLE [Reputation].[Point_Logs] (
    [log_id]      BIGINT IDENTITY(1,1) NOT NULL,
    [delta]       INT NOT NULL,
    [reason_code] VARCHAR(50) NOT NULL,
    [note]        NVARCHAR(255) NULL,
    [user_id]     BIGINT NOT NULL,
    [created_at]  DATETIME2 NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY ([log_id]),
    FOREIGN KEY ([user_id]) REFERENCES [Identity].[Users]([user_id])
);
GO

-- -------------------------------------------------------------------------
-- 6. Products — tin rao bán
-- -------------------------------------------------------------------------
CREATE TABLE [Market].[Products] (
    [product_id]    BIGINT IDENTITY(1,1) NOT NULL,
    [title]         NVARCHAR(255) NOT NULL,
    [description]   NVARCHAR(MAX) NOT NULL,
    [price]         BIGINT NOT NULL,
    [condition_pct] TINYINT NOT NULL,
    [status]        VARCHAR(20) NOT NULL DEFAULT 'Available',
    [location]      NVARCHAR(100) NULL,
    [thumbnail_url] VARCHAR(500) NULL,
    [created_at]    DATETIME2 NOT NULL DEFAULT GETDATE(),
    [seller_id]     BIGINT NOT NULL,
    [category_id]   INT NOT NULL,
    PRIMARY KEY ([product_id]),
    CONSTRAINT CK_Products_Price     CHECK ([price] >= 0),
    CONSTRAINT CK_Products_Condition CHECK ([condition_pct] BETWEEN 0 AND 100),
    CONSTRAINT CK_Products_Status    CHECK ([status] IN ('Available','Reserved','Sold','Hidden')),
    FOREIGN KEY ([seller_id])   REFERENCES [Identity].[Users]([user_id]),
    FOREIGN KEY ([category_id]) REFERENCES [Market].[Categories]([category_id])
);
GO

-- -------------------------------------------------------------------------
-- 7. Product_Images — nhiều ảnh / sản phẩm
-- -------------------------------------------------------------------------
CREATE TABLE [Market].[Product_Images] (
    [image_id]   BIGINT IDENTITY(1,1) NOT NULL,
    [product_id] BIGINT NOT NULL,
    [image_url]  VARCHAR(500) NOT NULL,
    [sort_order] TINYINT NOT NULL DEFAULT 0,
    PRIMARY KEY ([image_id]),
    FOREIGN KEY ([product_id]) REFERENCES [Market].[Products]([product_id]) ON DELETE CASCADE
);
GO

-- -------------------------------------------------------------------------
-- 8. Orders — mỗi sản phẩm tối đa một đơn (đồ cũ)
-- -------------------------------------------------------------------------
CREATE TABLE [Finance].[Orders] (
    [order_id]         BIGINT IDENTITY(1,1) NOT NULL,
    [order_status]     VARCHAR(30) NOT NULL DEFAULT 'Pending',
    [shipping_address] NVARCHAR(500) NOT NULL,
    [buyer_id]         BIGINT NOT NULL,
    [product_id]       BIGINT NOT NULL,
    [created_at]       DATETIME2 NOT NULL DEFAULT GETDATE(),
    [completed_at]     DATETIME2 NULL,
    PRIMARY KEY ([order_id]),
    CONSTRAINT UQ_Orders_Product UNIQUE ([product_id]),
    CONSTRAINT CK_Orders_Status CHECK ([order_status] IN (
        'Pending','Paid','Shipped','Completed','Cancelled','Disputed'
    )),
    FOREIGN KEY ([buyer_id])   REFERENCES [Identity].[Users]([user_id]),
    FOREIGN KEY ([product_id]) REFERENCES [Market].[Products]([product_id])
);
GO

-- -------------------------------------------------------------------------
-- 9. Payments — escrow (tạm giữ)
-- -------------------------------------------------------------------------
CREATE TABLE [Finance].[Payments] (
    [payment_id]      BIGINT IDENTITY(1,1) NOT NULL,
    [amount]          BIGINT NOT NULL,
    [payment_method]  VARCHAR(50) NOT NULL,
    [escrow_status]   VARCHAR(20) NOT NULL DEFAULT 'Holding',
    [transaction_ref] VARCHAR(100) NOT NULL,
    [order_id]        BIGINT NOT NULL,
    [paid_at]         DATETIME2 NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY ([payment_id]),
    CONSTRAINT UQ_Payments_Order UNIQUE ([order_id]),
    CONSTRAINT CK_Payments_Amount CHECK ([amount] > 0),
    CONSTRAINT CK_Payments_Escrow CHECK ([escrow_status] IN ('Holding','Released','Refunded')),
    FOREIGN KEY ([order_id]) REFERENCES [Finance].[Orders]([order_id])
);
GO

-- -------------------------------------------------------------------------
-- 10. Reviews — sau giao dịch; buyer đánh giá seller (hoặc ngược lại)
-- -------------------------------------------------------------------------
CREATE TABLE [Reputation].[Reviews] (
    [review_id]   BIGINT IDENTITY(1,1) NOT NULL,
    [rating]      TINYINT NOT NULL,
    [comment]     NVARCHAR(MAX) NULL,
    [order_id]    BIGINT NOT NULL,
    [reviewer_id] BIGINT NOT NULL,
    [reviewee_id] BIGINT NOT NULL,
    [created_at]  DATETIME2 NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY ([review_id]),
    CONSTRAINT UQ_Reviews_Order_Reviewer UNIQUE ([order_id], [reviewer_id]),
    CONSTRAINT CK_Reviews_Rating CHECK ([rating] BETWEEN 1 AND 5),
    FOREIGN KEY ([order_id])    REFERENCES [Finance].[Orders]([order_id]),
    FOREIGN KEY ([reviewer_id]) REFERENCES [Identity].[Users]([user_id]),
    FOREIGN KEY ([reviewee_id]) REFERENCES [Identity].[Users]([user_id])
);
GO

-- -------------------------------------------------------------------------
-- 11. Reports — báo cáo vi phạm (Admin: cột phải, KPI)
-- -------------------------------------------------------------------------
CREATE TABLE [Moderation].[Reports] (
    [report_id]    BIGINT IDENTITY(1,1) NOT NULL,
    [reporter_id]  BIGINT NOT NULL,
    [reported_id]  BIGINT NOT NULL,
    [product_id]   BIGINT NULL,
    [reason]       NVARCHAR(500) NOT NULL,
    [severity]     VARCHAR(20) NOT NULL DEFAULT 'medium',
    [status]       VARCHAR(20) NOT NULL DEFAULT 'Open',
    [created_at]   DATETIME2 NOT NULL DEFAULT GETDATE(),
    [resolved_at]  DATETIME2 NULL,
    PRIMARY KEY ([report_id]),
    CONSTRAINT CK_Reports_Severity CHECK ([severity] IN ('low','medium','high')),
    CONSTRAINT CK_Reports_Status   CHECK ([status] IN ('Open','Resolved','Rejected')),
    FOREIGN KEY ([reporter_id]) REFERENCES [Identity].[Users]([user_id]),
    FOREIGN KEY ([reported_id])  REFERENCES [Identity].[Users]([user_id]),
    FOREIGN KEY ([product_id])   REFERENCES [Market].[Products]([product_id])
);
GO

-- ==========================================
-- BƯỚC 4: INDEX (TỐI ƯU API / ADMIN)
-- ==========================================
CREATE INDEX IX_Users_KycStatus      ON [Identity].[Users]([kyc_status]);
CREATE INDEX IX_Users_AccountStatus  ON [Identity].[Users]([account_status]);
CREATE INDEX IX_Products_Seller      ON [Market].[Products]([seller_id]);
CREATE INDEX IX_Products_Category    ON [Market].[Products]([category_id]);
CREATE INDEX IX_Products_Status      ON [Market].[Products]([status]);
CREATE INDEX IX_Orders_Buyer         ON [Finance].[Orders]([buyer_id]);
CREATE INDEX IX_PointLogs_User       ON [Reputation].[Point_Logs]([user_id]);
CREATE INDEX IX_Reports_Status       ON [Moderation].[Reports]([status], [created_at] DESC);
CREATE INDEX IX_eKYC_VerifiedAt      ON [Identity].[eKYC_Profiles]([verified_at]);
GO

-- ==========================================
-- BƯỚC 5: TRIGGERS
-- ==========================================

-- 5.1 Tạo điểm 500 + Silver khi đăng ký User mới (300–599 = Silver)
CREATE TRIGGER [Identity].[trg_InitializeReputation]
ON [Identity].[Users]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO [Reputation].[Scores] ([user_id], [current_point], [rank_level])
    SELECT [user_id], 500, N'Silver'
    FROM inserted;
END;
GO

-- 5.2 Cộng/trừ điểm (sàn 0, trần 1000) + cập nhật hạng
--     Bronze <300 | Silver 300–599 | Gold 600–849 | Diamond >=850
--     (Gold ≈ "VÀNG" trên UI Flutter)
CREATE TRIGGER [Reputation].[trg_UpdateScoreAndRank]
ON [Reputation].[Point_Logs]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE S
    SET S.[current_point] = CASE
            WHEN S.[current_point] + I.[delta] < 0   THEN 0
            WHEN S.[current_point] + I.[delta] > 1000 THEN 1000
            ELSE S.[current_point] + I.[delta]
        END,
        S.[updated_at] = GETDATE()
    FROM [Reputation].[Scores] S
    INNER JOIN inserted I ON S.[user_id] = I.[user_id];

    UPDATE [Reputation].[Scores]
    SET [rank_level] = CASE
            WHEN [current_point] < 300  THEN N'Bronze'
            WHEN [current_point] < 600  THEN N'Silver'
            WHEN [current_point] < 850  THEN N'Gold'
            ELSE N'Diamond'
        END
    WHERE [user_id] IN (SELECT [user_id] FROM inserted);
END;
GO

-- 5.3 Khi admin duyệt eKYC (verified_at có giá trị) -> đồng bộ Users.kyc_status
CREATE TRIGGER [Identity].[trg_SyncKycStatusOnVerify]
ON [Identity].[eKYC_Profiles]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE([verified_at]) RETURN;

    UPDATE U
    SET U.[kyc_status] = N'Verified'
    FROM [Identity].[Users] U
    INNER JOIN inserted I ON U.[user_id] = I.[user_id]
    WHERE I.[verified_at] IS NOT NULL;
END;
GO

-- 5.4 Báo cáo vi phạm nghiêm trọng -> trừ điểm (tùy backend cũng insert Point_Logs)
--     Ví dụ: có thể gọi từ API sau khi INSERT Reports; ở đây chỉ trừ khi severity = high
CREATE TRIGGER [Moderation].[trg_ReportHighSeverityPenalty]
ON [Moderation].[Reports]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO [Reputation].[Point_Logs] ([delta], [reason_code], [note], [user_id])
    SELECT -50, 'REPORT_HIGH', N'Báo cáo vi phạm: ' + LEFT(I.[reason], 200), I.[reported_id]
    FROM inserted I
    WHERE I.[severity] = 'high' AND I.[status] = 'Open';
END;
GO

-- ==========================================
-- BƯỚC 6: VIEW HỖ TRỢ ADMIN (DASHBOARD)
-- ==========================================

-- Thống kê nhanh cho màn SafeAdmin
CREATE VIEW [Moderation].[vw_AdminDashboardStats]
AS
SELECT
    (SELECT COUNT(*) FROM [Identity].[Users]) AS total_users,
    (SELECT COUNT(*) FROM [Identity].[Users] WHERE [kyc_status] = 'Verified') AS ekyc_verified_count,
    (SELECT COUNT(*) FROM [Moderation].[Reports] WHERE [status] = 'Open') AS open_reports_count,
    (SELECT COUNT(*) FROM [Identity].[Users] WHERE [account_status] IN ('Locked','Banned')) AS locked_accounts_count;
GO

-- Danh sách user gần đây cho DataTable Admin
CREATE VIEW [Moderation].[vw_RecentUsersForAdmin]
AS
SELECT
    U.[user_id],
    U.[display_name],
    U.[email],
    U.[kyc_status],
    U.[account_status],
    S.[current_point] AS trust_score,
    (SELECT COUNT(*) FROM [Finance].[Orders] O WHERE O.[buyer_id] = U.[user_id] AND O.[order_status] = 'Completed') AS orders_as_buyer,
    U.[created_at]
FROM [Identity].[Users] U
LEFT JOIN [Reputation].[Scores] S ON S.[user_id] = U.[user_id]
WHERE U.[is_admin] = 0;
GO

-- ==========================================
-- BƯỚC 7: DỮ LIỆU MẪU (SEED) — Chạy sau khi tạo schema
-- ==========================================
INSERT INTO [Market].[Categories] ([name], [slug]) VALUES
    (N'Điện tử', 'dien-tu'),
    (N'Thời trang', 'thoi-trang'),
    (N'Đồ gia dụng', 'do-gia-dung'),
    (N'Xe cộ', 'xe-co'),
    (N'Sách', 'sach');
GO

-- Admin (NestJS backend: mật khẩu demo admin123 khi password_hash = HASH_REPLACE_IN_PRODUCTION)
INSERT INTO [Identity].[Users] (
    [phone_number], [email], [password_hash],
    [display_name], [location], [kyc_status], [account_status], [is_admin]
) VALUES (
    '0900000000', 'admin@safemarket.vn', 'HASH_REPLACE_IN_PRODUCTION',
    N'Admin Quản trị', N'Hệ thống', 'Verified', 'Active', 1
);
GO

-- User demo (NestJS: mật khẩu 123456 khi password_hash = HASH_DEMO; trigger tạo Scores 500)
INSERT INTO [Identity].[Users] (
    [phone_number], [email], [password_hash],
    [display_name], [location], [kyc_status], [account_status]
) VALUES
    ('0912345678', 'an.nguyen@email.com', 'HASH_DEMO', N'Nguyễn Văn An', N'Quận 1, TP. HCM', 'Verified', 'Active'),
    ('0923456789', 'b.tran@email.com',    'HASH_DEMO', N'Trần Thị B',    N'Quận 3',           'Pending',  'Active'),
    ('0934567890', 'c.le@email.com',      'HASH_DEMO', N'Lê Văn C',      N'Thủ Đức',         'Verified', 'Active'),
    ('0945678901', 'd.pham@email.com',    'HASH_DEMO', N'Phạm Thị D',    N'Quận 7',           'Verified', 'Locked');
GO

-- Cập nhật điểm demo — hạng khớp công thức trigger:
-- Bronze <300 | Silver 300–599 | Gold 600–849 | Diamond >=850
UPDATE S SET S.[current_point] = 850, S.[rank_level] = N'Diamond'
FROM [Reputation].[Scores] S
INNER JOIN [Identity].[Users] U ON U.[user_id] = S.[user_id]
WHERE U.[email] = 'an.nguyen@email.com';

UPDATE S SET S.[current_point] = 500, S.[rank_level] = N'Silver'
FROM [Reputation].[Scores] S
INNER JOIN [Identity].[Users] U ON U.[user_id] = S.[user_id]
WHERE U.[email] = 'b.tran@email.com';

UPDATE S SET S.[current_point] = 780, S.[rank_level] = N'Gold'
FROM [Reputation].[Scores] S
INNER JOIN [Identity].[Users] U ON U.[user_id] = S.[user_id]
WHERE U.[email] = 'c.le@email.com';

UPDATE S SET S.[current_point] = 920, S.[rank_level] = N'Diamond'
FROM [Reputation].[Scores] S
INNER JOIN [Identity].[Users] U ON U.[user_id] = S.[user_id]
WHERE U.[email] = 'd.pham@email.com';
GO

-- eKYC đã duyệt cho user An
INSERT INTO [Identity].[eKYC_Profiles] (
    [id_number], [full_name], [dob], [address],
    [id_front_url], [id_back_url], [face_video_url],
    [submitted_at], [verified_at], [user_id]
)
SELECT
    '079203001234', N'Nguyễn Văn An', '1998-05-15', N'Quận 1, TP. HCM',
    '/uploads/kyc/1/front.jpg', '/uploads/kyc/1/back.jpg', '/uploads/kyc/1/face.mp4',
    GETDATE(), GETDATE(), [user_id]
FROM [Identity].[Users] WHERE [email] = 'an.nguyen@email.com';
GO

-- Sản phẩm demo (Chợ + Chi tiết iPhone)
DECLARE @SellerAn BIGINT = (SELECT [user_id] FROM [Identity].[Users] WHERE [email] = 'an.nguyen@email.com');
DECLARE @CatDienTu INT = (SELECT TOP 1 [category_id] FROM [Market].[Categories] WHERE [name] = N'Điện tử');

INSERT INTO [Market].[Products] (
    [title], [description], [price], [condition_pct], [status],
    [location], [thumbnail_url], [seller_id], [category_id]
) VALUES (
    N'iPhone 13 Pro Max - 256GB Xanh Sierra',
    N'Máy zin 100%, pin 92%, kèm hộp và cáp sạc. Bảo hành 7 ngày đổi trả.',
    15500000, 92, 'Available',
    N'Quận 1, TP. Hồ Chí Minh', '/uploads/products/iphone13.jpg',
    @SellerAn, @CatDienTu
);

INSERT INTO [Market].[Product_Images] ([product_id], [image_url], [sort_order])
SELECT p.[product_id], '/uploads/products/iphone13.jpg', 0
FROM [Market].[Products] p
WHERE p.[title] LIKE N'iPhone 13%'
  AND NOT EXISTS (
    SELECT 1 FROM [Market].[Product_Images] i WHERE i.[product_id] = p.[product_id]
  );
GO

-- Báo cáo vi phạm demo (Admin — cột phải)
INSERT INTO [Moderation].[Reports] ([reporter_id], [reported_id], [reason], [severity], [status])
SELECT
    U1.[user_id], U2.[user_id], N'Gian lận giao dịch', 'high', 'Open'
FROM [Identity].[Users] U1, [Identity].[Users] U2
WHERE U1.[email] = 'admin@safemarket.vn' AND U2.[email] = 'b.tran@email.com';
GO

-- =========================================================================
-- BƯỚC 8: SCRIPT KIỂM TRA TRIGGER (CHỈ CHẠY KHI TEST — CÓ THỂ BỎ QUA)
-- Chạy trên DB đã có seed ở trên sẽ trùng email/phone -> comment block này
-- hoặc dùng DB trống (chỉ schema, không seed) để test thuần trigger.
-- =========================================================================
/*
USE SafeMarketDB;
GO

INSERT INTO [Identity].[Users] ([phone_number], [email], [password_hash])
VALUES ('0911223344', 'test.trigger@email.com', 'matkhau123_hash');

SELECT * FROM [Reputation].[Scores];  -- Mong đợi: 500, Silver

DECLARE @Uid BIGINT = (SELECT [user_id] FROM [Identity].[Users] WHERE [email] = 'test.trigger@email.com');

INSERT INTO [Reputation].[Point_Logs] ([delta], [reason_code], [user_id])
VALUES (150, 'KYC_SUCCESS', @Uid);
SELECT * FROM [Reputation].[Scores];  -- Mong đợi: 650, Gold

INSERT INTO [Reputation].[Point_Logs] ([delta], [reason_code], [user_id])
VALUES (-400, 'SCAM_REPORTED', @Uid);
SELECT * FROM [Reputation].[Scores];  -- Mong đợi: 250, Bronze
*/

PRINT N'SafeMarketDB v2.0 — tạo schema, trigger, seed và view Admin hoàn tất.';
GO


USE SafeMarketDB;
GO

SELECT 
    [user_id],
    [display_name],
    [email],
    [phone_number],
    [password_hash],
    [account_status],
    [is_admin]
FROM [Identity].[Users];
