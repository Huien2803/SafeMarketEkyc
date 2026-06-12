-- Theo dõi người dùng + thông báo in-app
USE SafeMarketDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'User_Follows' AND schema_id = SCHEMA_ID('Identity'))
BEGIN
  CREATE TABLE [Identity].[User_Follows] (
    [follow_id]    BIGINT IDENTITY(1,1) NOT NULL,
    [follower_id]  BIGINT NOT NULL,
    [followee_id]  BIGINT NOT NULL,
    [created_at]   DATETIME2 NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY ([follow_id]),
    CONSTRAINT UQ_UserFollows UNIQUE ([follower_id], [followee_id]),
    FOREIGN KEY ([follower_id]) REFERENCES [Identity].[Users]([user_id]),
    FOREIGN KEY ([followee_id]) REFERENCES [Identity].[Users]([user_id])
  );
  CREATE INDEX IX_UserFollows_Followee ON [Identity].[User_Follows]([followee_id]);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Notifications' AND schema_id = SCHEMA_ID('Market'))
BEGIN
  CREATE TABLE [Market].[Notifications] (
    [notification_id] BIGINT IDENTITY(1,1) NOT NULL,
    [user_id]         BIGINT NOT NULL,
    [type]            VARCHAR(50) NOT NULL,
    [title]           NVARCHAR(200) NOT NULL,
    [body]            NVARCHAR(500) NOT NULL,
    [payload_json]    NVARCHAR(MAX) NULL,
    [read_at]         DATETIME2 NULL,
    [created_at]      DATETIME2 NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY ([notification_id]),
    FOREIGN KEY ([user_id]) REFERENCES [Identity].[Users]([user_id])
  );
  CREATE INDEX IX_Notifications_User ON [Market].[Notifications]([user_id], [created_at] DESC);
END
GO

PRINT N'migrate-follow-notifications.sql hoàn tất.';
GO
