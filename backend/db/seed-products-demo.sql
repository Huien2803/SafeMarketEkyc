-- Thêm sản phẩm demo cho Phase 4 (chạy trên SafeMarketDB đã có seed cơ bản)
USE SafeMarketDB;
GO

DECLARE @SellerC BIGINT = (SELECT [user_id] FROM [Identity].[Users] WHERE [email] = 'c.le@email.com');
DECLARE @SellerB BIGINT = (SELECT [user_id] FROM [Identity].[Users] WHERE [email] = 'b.tran@email.com');
DECLARE @CatDienTu INT = (SELECT [category_id] FROM [Market].[Categories] WHERE [name] = N'Điện tử');
DECLARE @CatThoiTrang INT = (SELECT [category_id] FROM [Market].[Categories] WHERE [name] = N'Thời trang');
DECLARE @CatGiaDung INT = (SELECT [category_id] FROM [Market].[Categories] WHERE [name] = N'Đồ gia dụng');

IF NOT EXISTS (SELECT 1 FROM [Market].[Products] WHERE [title] LIKE N'Sony A7 III%')
INSERT INTO [Market].[Products] ([title], [description], [price], [condition_pct], [status], [location], [thumbnail_url], [seller_id], [category_id])
VALUES
(N'Sony A7 III Body', N'Máy full frame, shutter 15k, kèm pin + sạc. Zin 98%.', 22000000, 95, 'Available', N'Quận 3, TP.HCM', NULL, @SellerC, @CatDienTu),
(N'MacBook Pro M1 2020', N'RAM 16GB, SSD 512GB. Dùng văn phòng, pin 88%.', 18900000, 88, 'Available', N'Thủ Đức', NULL, @SellerC, @CatDienTu),
(N'AirPods Pro 2', N'Chính hãng Apple VN, còn bảo hành 3 tháng.', 3200000, 90, 'Available', N'Quận 7', NULL, @SellerB, @CatDienTu),
(N'Áo khoác Uniqlo Ultra Light', N'Size M, màu navy, mặc 2 lần.', 450000, 98, 'Available', N'Quận 3', NULL, @SellerB, @CatThoiTrang),
(N'Nồi cơm điện Toshiba 1.8L', N'Dùng 1 năm, còn tốt, kèm xửng hấp.', 650000, 85, 'Available', N'Quận 7', NULL, @SellerB, @CatGiaDung);
GO

-- Đơn mua demo (Completed) để test lịch sử
DECLARE @BuyerB BIGINT = (SELECT [user_id] FROM [Identity].[Users] WHERE [email] = 'b.tran@email.com');
DECLARE @ProductSold BIGINT = (
    SELECT TOP 1 [product_id] FROM [Market].[Products]
    WHERE [title] LIKE N'iPhone 13%' AND [status] = 'Available'
);

IF @ProductSold IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Finance].[Orders] WHERE [product_id] = @ProductSold)
BEGIN
    INSERT INTO [Finance].[Orders] ([order_status], [shipping_address], [buyer_id], [product_id], [completed_at])
    VALUES ('Completed', N'Liên hệ trực tiếp - Giao tại Quận 3', @BuyerB, @ProductSold, GETDATE());

    UPDATE [Market].[Products] SET [status] = 'Sold' WHERE [product_id] = @ProductSold;
END
GO
