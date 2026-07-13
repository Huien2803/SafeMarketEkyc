-- Nâng cấp quản lý kỷ luật người dùng cho admin:
--   * locked_until: thời điểm hết hạn đình chỉ tạm thời (NULL = khóa/cấm vô thời hạn).
-- Trạng thái "Deleted" (xóa mềm) dùng chung cột account_status hiện có (varchar) nên
-- không cần thay đổi cấu trúc thêm.
USE SafeMarketDB;
GO

IF NOT EXISTS (
  SELECT 1 FROM sys.columns
  WHERE Name = N'locked_until'
    AND Object_ID = Object_ID(N'Identity.Users')
)
BEGIN
  ALTER TABLE [Identity].[Users]
    ADD [locked_until] DATETIME2 NULL;
END
GO

PRINT N'migrate-user-moderation.sql hoàn tất.';
GO
