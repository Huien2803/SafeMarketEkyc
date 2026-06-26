-- Ảnh bằng chứng người mua xác nhận đã nhận hàng
USE SafeMarketDB;
GO

IF NOT EXISTS (
  SELECT 1 FROM sys.columns
  WHERE Name = N'receipt_proof_url'
    AND Object_ID = Object_ID(N'Finance.Orders')
)
BEGIN
  ALTER TABLE [Finance].[Orders]
    ADD [receipt_proof_url] VARCHAR(500) NULL;
END
GO

IF NOT EXISTS (
  SELECT 1 FROM sys.columns
  WHERE Name = N'received_at'
    AND Object_ID = Object_ID(N'Finance.Orders')
)
BEGIN
  ALTER TABLE [Finance].[Orders]
    ADD [received_at] DATETIME2 NULL;
END
GO

PRINT N'migrate-order-receipt-proof.sql hoàn tất.';
GO
