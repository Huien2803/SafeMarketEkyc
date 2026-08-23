-- Mốc thời gian giao hàng — dùng giới hạn khiếu nại 3 ngày
USE SafeMarketDB;
GO

IF NOT EXISTS (
  SELECT 1 FROM sys.columns
  WHERE Name = N'shipped_at'
    AND Object_ID = Object_ID(N'Finance.Orders')
)
BEGIN
  ALTER TABLE [Finance].[Orders]
    ADD [shipped_at] DATETIME2 NULL;
END
GO

-- Đơn Shipped cũ: gán shipped_at = created_at để có mốc tính hạn
UPDATE [Finance].[Orders]
SET [shipped_at] = [created_at]
WHERE [order_status] = N'Shipped'
  AND [shipped_at] IS NULL;
GO

PRINT N'migrate-order-shipped-at.sql hoàn tất.';
GO
