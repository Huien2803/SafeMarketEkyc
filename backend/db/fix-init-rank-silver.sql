-- Sửa trigger + hạng user 500 điểm → Silver
-- Chạy trên DB đang dùng (KHÔNG tạo lại database)
USE SafeMarketDB;
GO

IF OBJECT_ID(N'Identity.trg_InitializeReputation', N'TR') IS NOT NULL
    DROP TRIGGER [Identity].[trg_InitializeReputation];
GO
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

IF OBJECT_ID(N'Reputation.trg_UpdateScoreAndRank', N'TR') IS NOT NULL
    DROP TRIGGER [Reputation].[trg_UpdateScoreAndRank];
GO
CREATE TRIGGER [Reputation].[trg_UpdateScoreAndRank]
ON [Reputation].[Point_Logs]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE S
    SET S.[current_point] = CASE
            WHEN S.[current_point] + I.[delta] < 0    THEN 0
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

-- User đang 500 + Bronze → Silver (đúng công thức)
UPDATE [Reputation].[Scores]
SET [rank_level] = N'Silver', [updated_at] = GETDATE()
WHERE [current_point] >= 300 AND [current_point] < 600
  AND [rank_level] = N'Bronze';
GO

PRINT N'Da cap nhat 2 trigger + hang 500 diem = Silver.';
GO
