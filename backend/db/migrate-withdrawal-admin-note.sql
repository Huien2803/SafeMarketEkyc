-- Ghi chú admin khi duyệt/từ chối rút tiền
USE SafeMarketDB;
GO

IF NOT EXISTS (
  SELECT 1 FROM sys.columns
  WHERE Name = N'admin_note'
    AND Object_ID = Object_ID(N'Finance.Withdrawals')
)
BEGIN
  ALTER TABLE [Finance].[Withdrawals]
    ADD [admin_note] NVARCHAR(255) NULL;
END
GO

PRINT N'migrate-withdrawal-admin-note.sql hoàn tất.';
GO
