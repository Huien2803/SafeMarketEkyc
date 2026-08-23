-- Gán ảnh cho sản phẩm demo (chạy sau khi có file trong backend/uploads/products/)
USE SafeMarketDB;
GO

-- 1) Ảnh theo tên sản phẩm
UPDATE p SET [thumbnail_url] = '/uploads/products/iphone13.jpg'
FROM [Market].[Products] p
WHERE p.[title] LIKE N'iPhone%';

UPDATE p SET [thumbnail_url] = '/uploads/products/sony-a7iii.jpg'
FROM [Market].[Products] p
WHERE p.[title] LIKE N'Sony A7%';

UPDATE p SET [thumbnail_url] = '/uploads/products/macbook-m1.jpg'
FROM [Market].[Products] p
WHERE p.[title] LIKE N'MacBook%';

UPDATE p SET [thumbnail_url] = '/uploads/products/airpods-pro2.jpg'
FROM [Market].[Products] p
WHERE p.[title] LIKE N'AirPods%';

UPDATE p SET [thumbnail_url] = '/uploads/products/uniqlo-jacket.jpg'
FROM [Market].[Products] p
WHERE p.[title] LIKE N'%Uniqlo%' OR p.[title] LIKE N'%Áo khoác%';

UPDATE p SET [thumbnail_url] = '/uploads/products/rice-cooker.jpg'
FROM [Market].[Products] p
WHERE p.[title] LIKE N'%Nồi cơm%' OR p.[title] LIKE N'%Toshiba%';

-- 2) Sản phẩm còn thiếu ảnh → mặc định theo danh mục
UPDATE p SET [thumbnail_url] = '/uploads/products/default-dientu.jpg'
FROM [Market].[Products] p
INNER JOIN [Market].[Categories] c ON c.[category_id] = p.[category_id]
WHERE (p.[thumbnail_url] IS NULL OR LTRIM(RTRIM(p.[thumbnail_url])) = '')
  AND c.[name] = N'Điện tử';

UPDATE p SET [thumbnail_url] = '/uploads/products/default-thoitrang.jpg'
FROM [Market].[Products] p
INNER JOIN [Market].[Categories] c ON c.[category_id] = p.[category_id]
WHERE (p.[thumbnail_url] IS NULL OR LTRIM(RTRIM(p.[thumbnail_url])) = '')
  AND c.[name] = N'Thời trang';

UPDATE p SET [thumbnail_url] = '/uploads/products/default-giadung.jpg'
FROM [Market].[Products] p
INNER JOIN [Market].[Categories] c ON c.[category_id] = p.[category_id]
WHERE (p.[thumbnail_url] IS NULL OR LTRIM(RTRIM(p.[thumbnail_url])) = '')
  AND c.[name] = N'Đồ gia dụng';

-- 3) Đồng bộ bảng Product_Images (ảnh chính, sort_order = 0)
INSERT INTO [Market].[Product_Images] ([product_id], [image_url], [sort_order])
SELECT p.[product_id], p.[thumbnail_url], 0
FROM [Market].[Products] p
WHERE p.[thumbnail_url] IS NOT NULL
  AND LTRIM(RTRIM(p.[thumbnail_url])) <> ''
  AND NOT EXISTS (
    SELECT 1 FROM [Market].[Product_Images] i
    WHERE i.[product_id] = p.[product_id]
  );
GO

PRINT N'Đã gán ảnh sản phẩm. Kiểm tra: SELECT product_id, title, thumbnail_url FROM [Market].[Products];';
GO
