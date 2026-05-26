-- =========================================================================
-- TẠO USER SQL SERVER RIÊNG CHO BACKEND API
-- Mục đích: Backend NestJS không dùng tài khoản `sa` (bảo mật cho KLTN)
-- Chạy: SSMS → New Query → Execute (F5)
-- =========================================================================

USE master;
GO

-- 1. Tạo SQL Login (cấp Server)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'safemarket_api')
BEGIN
    CREATE LOGIN safemarket_api
    WITH PASSWORD = 'SafeMarket@2026',
         DEFAULT_DATABASE = SafeMarketDB,
         CHECK_POLICY = OFF;
    PRINT 'Login safemarket_api created.';
END
ELSE
    PRINT 'Login safemarket_api already exists.';
GO

USE SafeMarketDB;
GO

-- 2. Tạo Database User (cấp DB) ánh xạ tới Login
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'safemarket_api')
BEGIN
    CREATE USER safemarket_api FOR LOGIN safemarket_api;
    PRINT 'User safemarket_api created in SafeMarketDB.';
END
ELSE
    PRINT 'User safemarket_api already exists in SafeMarketDB.';
GO

-- 3. Cấp quyền CRUD đầy đủ trên SafeMarketDB
ALTER ROLE db_datareader ADD MEMBER safemarket_api;
ALTER ROLE db_datawriter ADD MEMBER safemarket_api;
-- Cấp quyền EXECUTE để gọi stored procedure / function (nếu cần sau này)
GRANT EXECUTE TO safemarket_api;
GO

PRINT '=========================================';
PRINT 'Connection info for NestJS backend:';
PRINT '  Server  : localhost';
PRINT '  Database: SafeMarketDB';
PRINT '  User    : safemarket_api';
PRINT '  Password: SafeMarket@2026';
PRINT '=========================================';
GO

-- 4. Bật SQL Server Authentication (Mixed Mode) nếu chưa bật
-- Kiểm tra:
SELECT 
    CASE SERVERPROPERTY('IsIntegratedSecurityOnly') 
        WHEN 0 THEN 'Mixed Mode (OK)'
        WHEN 1 THEN 'Windows Only - CẦN BẬT MIXED MODE'
    END AS AuthMode;

-- Nếu trả về 'Windows Only', làm thủ công:
--   1. SSMS → chuột phải vào server name (HUIEN) → Properties
--   2. Tab Security → chọn "SQL Server and Windows Authentication mode"
--   3. OK → Khởi động lại service: Services.msc → MSSQLSERVER → Restart
