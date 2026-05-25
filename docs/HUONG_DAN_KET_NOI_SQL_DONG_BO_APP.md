# Hướng dẫn kết nối SQL Server chuẩn & đồng bộ dữ liệu lên App Flutter

Tài liệu này dành cho đồ án **SafeMarket**: database `SafeMarketDB` (file `eKYC Market.sql`) + app Flutter `safemarket_app`.

---

## 1. Hiểu đúng: “Tự cập nhật” nghĩa là gì?

**SQL Server không gửi trực tiếp sang điện thoại.** Khi bạn sửa bảng trong SSMS, app **chỉ thấy thay đổi** khi:

1. App **gọi lại API** (mở màn hình, kéo refresh, hoặc định kỳ vài giây), **hoặc**
2. API **đẩy thông báo** xuống app qua **WebSocket / SignalR** (cập nhật gần như tức thì).

```text
  SSMS (sửa SQL)  -->  SQL Server lưu dữ liệu mới
                              ^
                              | SELECT / UPDATE
                              |
                        [API Backend]
                              ^
                    HTTP GET (hoặc SignalR push)
                              |
                        [Flutter App]  -->  setState / refresh UI
```

**Kết luận:** Chuẩn khóa luận = **Flutter ↔ REST API ↔ SQL Server**. “Tự cập nhật” = thiết kế **cơ chế làm mới UI** sau khi DB đổi.

---

## 2. Kiến trúc chuẩn (3 tầng)

| Tầng | Công nghệ gợi ý | File / vị trí |
|------|-----------------|---------------|
| 1. Database | SQL Server + `eKYC Market.sql` | SSMS, `SafeMarketDB` |
| 2. API | ASP.NET Core Web API + EF Core | Project riêng: `SafeMarket.Api` |
| 3. Client | Flutter + package `http` (hoặc `dio`) | `safemarket_app/lib/services/` |

**Không** đặt connection string trong Flutter.

---

## 3. Lộ trình triển khai từng bước

### Bước 1 — Chạy SQL (một lần hoặc khi đổi schema)

1. Mở **SQL Server Management Studio**.
2. Mở file `eKYC Market.sql` → **Execute (F5)**.
3. Kiểm tra:

```sql
USE SafeMarketDB;
SELECT * FROM [Moderation].[vw_AdminDashboardStats];
```

### Bước 2 — Tạo API kết nối SQL (Backend)

#### 2.1 Tạo project (Visual Studio hoặc CLI)

```bash
dotnet new webapi -n SafeMarket.Api -o SafeMarket.Api
cd SafeMarket.Api
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
dotnet add package Microsoft.EntityFrameworkCore.Tools
```

#### 2.2 Connection string — `appsettings.json`

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=SafeMarketDB;User Id=sa;Password=MAT_KHAU_CUA_BAN;TrustServerCertificate=True;"
  }
}
```

| Tham số | Ví dụ |
|---------|--------|
| Server | `localhost`, `.\SQLEXPRESS` |
| Database | `SafeMarketDB` |
| User Id / Password | Tài khoản SQL (không commit password lên Git) |

#### 2.3 Đăng ký DbContext — `Program.cs`

```csharp
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<SafeMarketDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Cho Flutter gọi API khi dev (HTTP local)
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();
app.UseCors();
app.UseSwagger();
app.UseSwaggerUI();
app.MapControllers();
app.Run();
```

#### 2.4 Entity khớp bảng SQL (ví dụ Products)

```csharp
public class Product
{
    public long ProductId { get; set; }
    public string Title { get; set; } = "";
    public long Price { get; set; }
    public string? Location { get; set; }
    public string Status { get; set; } = "Available";
    public long SellerId { get; set; }
    public int CategoryId { get; set; }
}

public class SafeMarketDbContext : DbContext
{
    public SafeMarketDbContext(DbContextOptions<SafeMarketDbContext> options) : base(options) { }
    public DbSet<Product> Products => Set<Product>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Product>().ToTable("Products", "Market");
        modelBuilder.Entity<Product>().Property(p => p.ProductId).HasColumnName("product_id");
        modelBuilder.Entity<Product>().Property(p => p.Title).HasColumnName("title");
        // ... map các cột snake_case tương ứng
    }
}
```

#### 2.5 Controller — đọc từ SQL, trả JSON

```csharp
[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly SafeMarketDbContext _db;
    public ProductsController(SafeMarketDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var list = await _db.Products
            .Where(p => p.Status == "Available")
            .OrderByDescending(p => p.ProductId)
            .Select(p => new {
                id = p.ProductId,
                title = p.Title,
                price = p.Price,
                location = p.Location
            })
            .ToListAsync();
        return Ok(list);
    }
}
```

#### 2.6 Chạy API

```bash
dotnet run
```

Mở Swagger: `https://localhost:7xxx/swagger` → thử `GET /api/products`.  
Thấy JSON = **API đã kết nối SQL thành công**.

**Khi bạn UPDATE trong SSMS:**

```sql
UPDATE [Market].[Products] SET [price] = 14000000 WHERE [title] LIKE N'%iPhone%';
```

Gọi lại `GET /api/products` trên Swagger → giá mới → **SQL đã đồng bộ qua API**.

---

### Bước 3 — Flutter gọi API (không nối SQL)

#### 3.1 Thêm package

`pubspec.yaml`:

```yaml
dependencies:
  http: ^1.2.0
```

```bash
flutter pub get
```

#### 3.2 Cấu hình URL theo thiết bị — `lib/services/api_config.dart`

```dart
class ApiConfig {
  /// Android Emulator: 10.0.2.2 = localhost máy PC
  static const String baseUrl = 'http://10.0.2.2:5214';

  /// iOS Simulator: 'http://127.0.0.1:5214'
  /// Điện thoại thật (cùng Wi-Fi): 'http://192.168.1.xx:5214'
}
```

Đổi port `5214` đúng với cổng `dotnet run` in ra (xem console hoặc `launchSettings.json`).

#### 3.3 Service gọi API — `lib/services/product_api.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:safemarket_app/services/api_config.dart';

class ProductApi {
  static Future<List<Map<String, dynamic>>> fetchProducts() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/products');
    final res = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Lỗi ${res.statusCode}: ${res.body}');
  }
}
```

#### 3.4 Android cho phép HTTP local (chỉ dev)

`android/app/src/main/AndroidManifest.xml` trong `<application>`:

```xml
android:usesCleartextTraffic="true"
```

---

## 4. Ba cách làm App “tự cập nhật” khi SQL đổi

### Cách 1 — Làm mới khi mở màn hình (dễ nhất, nên làm trước)

Mỗi lần vào Chợ → gọi API → đọc SQL mới nhất.

```dart
class MarketplaceHomeScreen extends StatefulWidget { ... }

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _reloadProducts();
  }

  void _reloadProducts() {
    setState(() {
      _productsFuture = ProductApi.fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          final list = snapshot.data ?? [];
          // ... vẽ GridView từ list
          return CustomScrollView(/* ... */);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _reloadProducts,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
```

**Luồng:** Sửa giá trong SSMS → quay lại app → bấm refresh hoặc thoát/vào lại màn → **giá mới**.

---

### Cách 2 — Kéo xuống để làm mới (Pull-to-refresh)

Bọc `CustomScrollView` bằng `RefreshIndicator`:

```dart
RefreshIndicator(
  onRefresh: () async {
    _reloadProducts();
    await _productsFuture;
  },
  child: CustomScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [ /* ... */ ],
  ),
)
```

**Trải nghiệm:** Giống Facebook/Shopee — user chủ động kéo để lấy dữ liệu mới từ SQL (qua API).

---

### Cách 3 — Tự động theo chu kỳ (polling)

Mỗi N giây gọi API một lần (phù hợp Admin dashboard).

```dart
import 'dart:async';

Timer? _pollTimer;

@override
void initState() {
  super.initState();
  _reloadProducts();
  _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    _reloadProducts();
  });
}

@override
void dispose() {
  _pollTimer?.cancel();
  super.dispose();
}
```

| Ưu | Nhược |
|----|--------|
| Không cần SignalR | Tốn pin / băng thông nếu N quá nhỏ |
| Dễ code | Không “tức thì” (trễ tối đa N giây) |

**Gợi ý:** Chợ 30–60 giây; Admin KPI 15–30 giây.

---

### Cách 4 — Realtime (SignalR) — “SQL đổi là app biết ngay”

Dùng khi hội đồng hỏi **cập nhật thời gian thực**.

```text
SSMS UPDATE  -->  API (sau khi SaveChanges)  -->  hub.Clients.All.SendAsync("ProductsChanged")
                                                      -->
                                              Flutter SignalR client  -->  _reloadProducts()
```

**Backend (rút gọn):**

```csharp
// Program.cs
builder.Services.AddSignalR();
app.MapHub<MarketHub>("/hubs/market");

// Sau khi UPDATE product trong service:
await _hubContext.Clients.All.SendAsync("ProductsChanged");
```

**Flutter:** package `signalr_netcore` hoặc `web_socket_channel` — lắng nghe event → gọi `_reloadProducts()`.

Đồ án **không bắt buộc** SignalR; Cách 1 + 2 thường đủ.

---

## 5. Luồng đầy đủ: Sửa SQL → Thấy trên App

| Bước | Ai làm | Việc gì |
|------|--------|---------|
| 1 | Bạn | SSMS: `UPDATE [Market].[Products] SET [price] = ...` |
| 2 | SQL Server | Lưu giá mới vào đĩa |
| 3 | — | (Không có gì tự chạy sang Flutter) |
| 4 | API | Khi app gọi `GET /api/products`, EF đọc lại DB → JSON giá mới |
| 5 | Flutter | `FutureBuilder` / `RefreshIndicator` / Timer nhận JSON → `setState` → UI đổi |

**Checklist test end-to-end:**

1. [ ] SQL script chạy OK  
2. [ ] `dotnet run` — Swagger trả đúng dữ liệu  
3. [ ] Sửa 1 dòng trong SSMS  
4. [ ] Swagger gọi lại GET → thấy giá mới  
5. [ ] Flutter `baseUrl` đúng, `flutter run`  
6. [ ] App refresh → thấy giá mới  

Nếu bước 4 OK mà bước 6 lỗi → lỗi **mạng Flutter ↔ API**, không phải SQL.

---

## 6. Map API ↔ bảng SQL SafeMarketDB

| Màn Flutter | API gợi ý | Bảng / View SQL chính |
|-------------|-----------|------------------------|
| Chợ | `GET /api/products` | `[Market].[Products]`, join `Users`, `Scores` |
| Chi tiết SP | `GET /api/products/{id}` | `Products`, `Product_Images` |
| Profile | `GET /api/users/me` | `Users`, `Scores`, `eKYC_Profiles` |
| Admin KPI | `GET /api/admin/stats` | `[Moderation].[vw_AdminDashboardStats]` |
| Admin users | `GET /api/admin/users` | `[Moderation].[vw_RecentUsersForAdmin]` |
| Admin reports | `GET /api/admin/reports` | `[Moderation].[Reports]` |
| eKYC gửi hồ sơ | `POST /api/ekyc/submit` | `INSERT eKYC_Profiles`, `Users.kyc_status = Pending` |
| Admin duyệt eKYC | `PUT /api/ekyc/{id}/approve` | `verified_at`, trigger sync `kyc_status` |

**Khi Admin duyệt eKYC qua API** (không sửa tay SSMS):

```csharp
profile.VerifiedAt = DateTime.UtcNow;
user.KycStatus = "Verified";
await _db.SaveChangesAsync();
// Trigger trg_SyncKycStatusOnVerify cũng chạy
```

App Profile gọi lại `GET /api/users/me` → thấy Verified + điểm mới.

---

## 7. Thứ tự chạy khi dev hàng ngày

```text
1. Bật SQL Server (service đang chạy)
2. (Tùy chọn) Sửa schema → chạy lại eKYC Market.sql
3. Terminal 1: cd SafeMarket.Api → dotnet run
4. Terminal 2: cd safemarket_app → flutter run
5. Sửa data trong SSMS hoặc qua API POST/PUT
6. Trên app: pull-to-refresh hoặc đợi polling
```

---

## 8. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách sửa |
|-------------|-------------|----------|
| Connection refused (Flutter) | Sai `baseUrl` / API chưa chạy | `10.0.2.2` + đúng port; bật API |
| Login failed SQL (API) | Sai password `sa` | Sửa `appsettings.json` |
| Swagger OK, Flutter lỗi | CORS / HTTP blocked | `AddCors`; `usesCleartextTraffic` |
| App vẫn giá cũ | UI cache list cứng | Dùng `FutureBuilder` + refresh, bỏ `_products` static |
| Sửa SSMS không đổi app | Chưa gọi lại API | Refresh; không expect “magic push” |

---

## 9. Tóm tắt một câu cho hội đồng

*“Em dùng kiến trúc 3 lớp: SQL Server lưu trữ, ASP.NET Core Web API truy vấn qua Entity Framework, Flutter client lấy dữ liệu qua REST và làm mới giao diện khi người dùng mở màn hình hoặc kéo refresh; như vậy mọi thay đổi trong database đều phản ánh lên app thông qua API, đảm bảo bảo mật và không lộ thông tin kết nối SQL trên thiết bị di động.”*

---

## 10. File liên quan trong repo

| File | Mục đích |
|------|----------|
| `eKYC Market.sql` | Schema + seed + trigger |
| `README.md` mục P | Tổng quan kết nối SQL |
| `lib/services/` (sẽ tạo) | `api_config.dart`, `product_api.dart` |
| `SafeMarket.Api/` (project riêng, bạn tạo) | API + connection string |

*Bước tiếp theo gợi ý: tạo solution `SafeMarket.Api` cạnh `safemarket_app`, implement `GET /api/products`, rồi gắn `FutureBuilder` vào `marketplace_home.dart`.*
