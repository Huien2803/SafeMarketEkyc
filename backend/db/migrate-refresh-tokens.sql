-- Refresh tokens (opaque, lưu hash SHA-256) cho JWT ngắn hạn.
USE SafeMarketDB;
GO

IF NOT EXISTS (
  SELECT 1 FROM sys.tables t
  INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
  WHERE s.name = N'Identity' AND t.name = N'RefreshTokens'
)
BEGIN
  CREATE TABLE [Identity].[RefreshTokens] (
    [token_id]     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RefreshTokens PRIMARY KEY,
    [user_id]      BIGINT NOT NULL,
    [token_hash]   VARCHAR(64) NOT NULL,
    [expires_at]   DATETIME2 NOT NULL,
    [revoked_at]   DATETIME2 NULL,
    [created_at]   DATETIME2 NOT NULL CONSTRAINT DF_RefreshTokens_created DEFAULT SYSUTCDATETIME(),
    [replaced_by]  BIGINT NULL,
    CONSTRAINT FK_RefreshTokens_Users
      FOREIGN KEY ([user_id]) REFERENCES [Identity].[Users]([user_id]),
    CONSTRAINT UQ_RefreshTokens_token_hash UNIQUE ([token_hash])
  );

  CREATE INDEX IX_RefreshTokens_user_id
    ON [Identity].[RefreshTokens] ([user_id]);

  CREATE INDEX IX_RefreshTokens_expires_at
    ON [Identity].[RefreshTokens] ([expires_at]);
END
GO

PRINT N'migrate-refresh-tokens.sql hoàn tất.';
GO
