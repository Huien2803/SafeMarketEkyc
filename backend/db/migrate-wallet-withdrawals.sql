-- Ví người bán + lịch sử giao dịch ví + yêu cầu rút tiền
-- Tiền escrow khi giải ngân sẽ được cộng vào ví người bán; người bán rút về ngân hàng.
USE SafeMarketDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Wallets' AND schema_id = SCHEMA_ID('Finance'))
BEGIN
  CREATE TABLE [Finance].[Wallets] (
    [wallet_id]  BIGINT IDENTITY(1,1) NOT NULL,
    [user_id]    BIGINT NOT NULL,
    [balance]    BIGINT NOT NULL DEFAULT 0,
    [updated_at] DATETIME2 NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY ([wallet_id]),
    CONSTRAINT UQ_Wallets_User UNIQUE ([user_id]),
    CONSTRAINT CK_Wallets_Balance CHECK ([balance] >= 0),
    FOREIGN KEY ([user_id]) REFERENCES [Identity].[Users]([user_id])
  );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Wallet_Transactions' AND schema_id = SCHEMA_ID('Finance'))
BEGIN
  CREATE TABLE [Finance].[Wallet_Transactions] (
    [txn_id]     BIGINT IDENTITY(1,1) NOT NULL,
    [user_id]    BIGINT NOT NULL,
    [amount]     BIGINT NOT NULL,               -- dương: cộng tiền; âm: trừ tiền
    [type]       VARCHAR(30) NOT NULL,          -- CREDIT_SALE | DEBIT_WITHDRAW | REFUND_WITHDRAW
    [ref]        VARCHAR(100) NULL,
    [note]       NVARCHAR(255) NULL,
    [created_at] DATETIME2 NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY ([txn_id]),
    FOREIGN KEY ([user_id]) REFERENCES [Identity].[Users]([user_id])
  );
  CREATE INDEX IX_WalletTxn_User ON [Finance].[Wallet_Transactions]([user_id], [created_at] DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Withdrawals' AND schema_id = SCHEMA_ID('Finance'))
BEGIN
  CREATE TABLE [Finance].[Withdrawals] (
    [withdrawal_id]   BIGINT IDENTITY(1,1) NOT NULL,
    [user_id]         BIGINT NOT NULL,
    [amount]          BIGINT NOT NULL,
    [bank_name]       NVARCHAR(100) NOT NULL,
    [bank_account]    VARCHAR(50) NOT NULL,
    [account_holder]  NVARCHAR(100) NOT NULL,
    [status]          VARCHAR(20) NOT NULL DEFAULT 'Completed', -- Pending | Completed | Rejected
    [transaction_ref] VARCHAR(100) NULL,
    [created_at]      DATETIME2 NOT NULL DEFAULT GETDATE(),
    [processed_at]    DATETIME2 NULL,
    PRIMARY KEY ([withdrawal_id]),
    CONSTRAINT CK_Withdrawals_Amount CHECK ([amount] > 0),
    FOREIGN KEY ([user_id]) REFERENCES [Identity].[Users]([user_id])
  );
  CREATE INDEX IX_Withdrawals_User ON [Finance].[Withdrawals]([user_id], [created_at] DESC);
END
GO

PRINT N'migrate-wallet-withdrawals.sql hoàn tất.';
GO
