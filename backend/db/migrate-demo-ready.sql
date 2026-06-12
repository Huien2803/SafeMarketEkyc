-- SafeMarket: migration bổ sung cho demo NestJS + Flutter
-- Chạy trên DB đã có schema từ eKYC Market.sql
USE SafeMarketDB;
GO

-- Mở rộng Orders (payment, delivery, dispute)
IF COL_LENGTH('Finance.Orders', 'payment_method') IS NULL
  ALTER TABLE [Finance].[Orders] ADD [payment_method] VARCHAR(50) NOT NULL DEFAULT 'BANK_TRANSFER';
IF COL_LENGTH('Finance.Orders', 'delivery_method') IS NULL
  ALTER TABLE [Finance].[Orders] ADD [delivery_method] VARCHAR(50) NOT NULL DEFAULT 'SHIP';
IF COL_LENGTH('Finance.Orders', 'dispute_type') IS NULL
  ALTER TABLE [Finance].[Orders] ADD [dispute_type] VARCHAR(50) NULL;
IF COL_LENGTH('Finance.Orders', 'dispute_note') IS NULL
  ALTER TABLE [Finance].[Orders] ADD [dispute_note] NVARCHAR(500) NULL;
IF COL_LENGTH('Finance.Orders', 'cancel_reason') IS NULL
  ALTER TABLE [Finance].[Orders] ADD [cancel_reason] NVARCHAR(255) NULL;
GO

-- Reviews: cho phép buyer và seller đánh giá nhau (2 review / đơn)
IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_Reviews_Order')
  ALTER TABLE [Reputation].[Reviews] DROP CONSTRAINT UQ_Reviews_Order;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_Reviews_Order_Reviewer')
  ALTER TABLE [Reputation].[Reviews] ADD CONSTRAINT UQ_Reviews_Order_Reviewer UNIQUE ([order_id], [reviewer_id]);
GO

-- Chat
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Chat_Threads' AND schema_id = SCHEMA_ID('Market'))
BEGIN
  CREATE TABLE [Market].[Chat_Threads] (
    [thread_id]  BIGINT IDENTITY(1,1) NOT NULL,
    [buyer_id]   BIGINT NOT NULL,
    [seller_id]  BIGINT NOT NULL,
    [product_id] BIGINT NULL,
    [order_id]   BIGINT NULL,
    [created_at] DATETIME2 NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY ([thread_id]),
    FOREIGN KEY ([buyer_id])  REFERENCES [Identity].[Users]([user_id]),
    FOREIGN KEY ([seller_id]) REFERENCES [Identity].[Users]([user_id]),
    FOREIGN KEY ([product_id]) REFERENCES [Market].[Products]([product_id]),
    FOREIGN KEY ([order_id])   REFERENCES [Finance].[Orders]([order_id])
  );
  CREATE INDEX IX_ChatThreads_Buyer  ON [Market].[Chat_Threads]([buyer_id]);
  CREATE INDEX IX_ChatThreads_Seller ON [Market].[Chat_Threads]([seller_id]);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Chat_Messages' AND schema_id = SCHEMA_ID('Market'))
BEGIN
  CREATE TABLE [Market].[Chat_Messages] (
    [message_id]   BIGINT IDENTITY(1,1) NOT NULL,
    [thread_id]    BIGINT NOT NULL,
    [sender_id]    BIGINT NOT NULL,
    [body]         NVARCHAR(MAX) NOT NULL,
    [message_type] VARCHAR(30) NOT NULL DEFAULT 'TEXT',
    [meta]         NVARCHAR(MAX) NULL,
    [created_at]   DATETIME2 NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY ([message_id]),
    FOREIGN KEY ([thread_id]) REFERENCES [Market].[Chat_Threads]([thread_id]) ON DELETE CASCADE,
    FOREIGN KEY ([sender_id]) REFERENCES [Identity].[Users]([user_id])
  );
  CREATE INDEX IX_ChatMessages_Thread ON [Market].[Chat_Messages]([thread_id], [created_at]);
END
GO

PRINT N'migrate-demo-ready.sql hoàn tất.';
GO
