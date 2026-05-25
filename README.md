# SafeMarket App — Tài liệu chi tiết toàn bộ mã nguồn

Ứng dụng **Chợ đồ cũ an toàn** (eKYC + điểm tín nhiệm), Flutter Material 3. Tài liệu này giải thích **từng file, từng class, từng widget quan trọng**, cách chúng liên kết và **cách bạn sử dụng / mở rộng** khi làm khóa luận.

---

## Mục lục

| # | Nội dung |
|---|----------|
| A | [Khái niệm Flutter cần biết trước khi đọc code](#a-khái-niệm-flutter-cần-biết-trước-khi-đọc-code) |
| B | [Chạy ứng dụng & các chế độ demo](#b-chạy-ứng-dụng--các-chế-độ-demo) |
| C | [Cấu trúc thư mục & luồng import](#c-cấu-trúc-thư-mục--luồng-import) |
| D | [Lớp nền: màu, theme, decoration](#d-lớp-nền-màu-theme-decoration) |
| E | [Widget dùng chung](#e-widget-dùng-chung) |
| F | [`main.dart` — giải thích từng dòng](#f-maindart--giải-thích-từng-dòng) |
| G | [Điều hướng (Navigator) chi tiết](#g-điều-hướng-navigator-chi-tiết) |
| H | [`marketplace_home.dart`](#h-marketplace_homedart) |
| I | [`profile_screen.dart`](#i-profile_screendart) |
| J | [`identity_verification.dart`](#j-identity_verificationdart) |
| K | [`product_detail.dart`](#k-product_detaildart) |
| L | [`admin_dashboard.dart`](#l-admin_dashboarddart) |
| M | [Công thức layout & responsive](#m-công-thức-layout--responsive) |
| N | [Mở rộng: API, ảnh, eKYC thật](#n-mở-rộng-api-ảnh-ekyc-thật) |
| O | [FAQ & lỗi thường gặp](#o-faq--lỗi-thường-gặp) |
| P | [Kết nối SQL Server & Flutter (kiến trúc 3 tầng)](#p-kết-nối-sql-server--flutter-kiến-trúc-3-tầng) |
| Q | [**Kết nối chuẩn + tự cập nhật app khi SQL đổi**](docs/HUONG_DAN_KET_NOI_SQL_DONG_BO_APP.md) |

---

## A. Khái niệm Flutter cần biết trước khi đọc code

### Widget là gì?

Mọi thứ trên màn hình đều là **Widget** (class kế thừa `Widget`). Hai loại chính trong dự án này:

| Loại | Ví dụ trong SafeMarket | Đặc điểm |
|------|------------------------|----------|
| **StatelessWidget** | `ProfileScreen`, `ProductDetailScreen` | UI cố định; không có biến state thay đổi bên trong |
| **StatefulWidget** | `MarketplaceHomeScreen`, `AdminDashboardScreen` | Có class `State` riêng; gọi `setState()` để vẽ lại UI (đổi tab, đổi danh mục) |

### `build(BuildContext context)` làm gì?

Flutter gọi `build()` mỗi khi cần **vẽ lại** widget. `context` dùng để:

- Lấy theme: `Theme.of(context)`
- Lấy kích thước màn: `MediaQuery.sizeOf(context)`
- Điều hướng: `Navigator.push(context, ...)`

### Scaffold — khung một màn hình

Hầu hết màn dùng:

```text
Scaffold
├── appBar (tùy chọn)
├── body (nội dung chính)
├── bottomNavigationBar / floatingActionButton (tùy chọn)
└── drawer (Admin trên mobile)
```

### `const` trong code

`const Widget(...)` giúp Flutter **tái sử dụng** widget, giảm rebuild. Dùng khi giá trị không đổi (màu cố định, text cố định).

### Private class (`_TênClass`)

Dấu `_` ở đầu tên = **chỉ dùng trong file đó** (library private). Ví dụ `_ProductCard` không export ra ngoài — tránh lộ implementation.

---

## B. Chạy ứng dụng & các chế độ demo

### Yêu cầu

- Flutter SDK ≥ 3.12 (`environment.sdk` trong `pubspec.yaml`)
- Một thiết bị: emulator Android/iOS, máy thật, hoặc Chrome

### Lệnh

```bash
cd safemarket_app
flutter pub get
flutter run                    # thiết bị mặc định
flutter run -d chrome            # web — nên dùng để xem Admin rộng
flutter devices                # liệt kê thiết bị
flutter run -d <device_id>
```

### Ba “chế độ” khi mở app

| Cách vào | File / code | Mục đích |
|----------|-------------|----------|
| **Mặc định** | `home: _AppLauncher()` | Demo 5 màn cho báo cáo / chụp ảnh |
| **App thật** | Đổi `home: MarketplaceHomeScreen()` | Người dùng vào thẳng Chợ |
| **Named route** | `Navigator.pushNamed(context, '/admin')` | Mở từng màn theo đường dẫn |

### Nút trên màn Launcher

- **ListTile** từng dòng → `Navigator.push` + `MaterialPageRoute` (đẩy màn mới lên stack).
- **FAB 「Vào app chính」** → `Navigator.pushReplacement` (thay Launcher bằng Home, không quay lại Launcher bằng nút Back).

---

## C. Cấu trúc thư mục & luồng import

```
lib/
├── main.dart
├── core/theme/app_colors.dart      ← không import screen
├── core/theme/app_theme.dart       ← import app_colors
├── core/constants/app_decorations.dart
├── widgets/verified_badge.dart
├── widgets/trust_score_bar.dart
└── screens/*.dart                  ← import core + widgets + screen khác (navigation)
```

**Quy tắc phụ thuộc:**

- `core` **không** import `screens` (tránh vòng lặp).
- `screens` có thể import lẫn nhau **chỉ để** `Navigator.push` — sau này nên tách sang `routes.dart`.

**Package name** (dùng trong import): `safemarket_app` — trùng `name:` trong `pubspec.yaml`.

---

## D. Lớp nền: màu, theme, decoration

### D.1 `app_colors.dart` — từng hằng số

```dart
class AppColors {
  AppColors._();  // constructor private → không thể new AppColors()
}
```

| Hằng số | ARGB | RGB gần đúng | Xuất hiện ở đâu |
|---------|------|----------------|-----------------|
| `primary` | `0xFF1E60FF` | Royal Blue | Giá, FAB, menu Admin chọn, nút Mua ngay |
| `background` | `0xFFF4F6F9` | Xám trắng | `Scaffold.backgroundColor` mọi màn |
| `trustGreen` | `0xFF198754` | Xanh lá | `⭐ 850`, tick eKYC, % tăng KPI |
| `trustGradientEnd` | `0xFF673AB7` | Tím | Cuối gradient Trust Card |
| `textPrimary` | `0xFF1A1D26` | Đen xám | Tiêu đề, tên user |
| `textSecondary` | `0xFF6B7280` | Xám | Phụ đề, email bảng Admin |
| `textMuted` | `0xFF9CA3AF` | Xám nhạt | Hint search, nhãn cột |
| `sellerCardBg` | `0xFFE8F0FF` | Xanh rất nhạt | Nền `_SellerCard` |
| `warningBg/Text/Icon` | Vàng kem / nâu / cam | Khung AI eKYC |
| `ekycVerifiedBg/Text` | Xanh mint / xanh đậm | Badge ĐÃ XÁC THỰC |
| `ekycPendingBg/Text` | Cam nhạt / cam đậm | Badge CHỜ DUYỆT |
| `shadow` | `0x1A000000` | Đen 10% opacity | `BoxShadow` |
| `trustCardGradient` | `LinearGradient` trái→phải | `_TrustCard` Profile |

**Vì sao dùng `static const`?**

- Màu compile-time, không tốn RAM tạo object mới mỗi frame.
- Sửa **một chỗ** → đổi toàn app.

**`withValues(alpha: 0.1)`** (Flutter 3.27+): thay cho `withOpacity` — tạo màu primary 10% opacity cho nền icon logo.

---

### D.2 `app_theme.dart` — từng thuộc tính ThemeData

| Thuộc tính | Giá trị | Ảnh hưởng thực tế |
|------------|---------|-------------------|
| `useMaterial3: true` | Bật M3 | Nút, card theo spec Material 3 |
| `colorScheme` | `fromSeed(primary)` | Sinh thêm màu phụ (secondary, tertiary…) |
| `scaffoldBackgroundColor` | `background` | Nền mặc định nếu Scaffold không set |
| `fontFamily: 'Roboto'` | System/Roboto | Chữ (trên Android thường có sẵn Roboto) |
| `appBarTheme` | elevation 0, nền `background` | AppBar “phẳng”, không shadow |
| `cardTheme` | bo 16, elevation 0 | `Card()` trong Launcher |
| `elevatedButtonTheme` | primary, bo 16 | Nút 「Xác thực ngay」, 「Mua ngay」 |
| `inputDecorationTheme` | filled trắng, bo 24 | `TextField` search (trừ khi override inline) |

**Lưu ý:** Nhiều màn **ghi đè** màu trực tiếp bằng `AppColors` thay vì `Theme.of(context)` — để khớp 100% thiết kế ảnh mẫu.

---

### D.3 `app_decorations.dart`

```dart
static List<BoxShadow> get cardShadow => [ BoxShadow(...) ];
```

- `blurRadius: 12` — độ mờ bóng.
- `offset: Offset(0, 4)` — bóng lệch **xuống** 4px (cảm giác thẻ nổi).

`AppDecorations.card({Color? color})`:

- Mặc định nền trắng.
- `borderRadius: 16` — đồng bộ thiết kế.
- Có thể truyền `color: AppColors.sellerCardBg` nếu cần (hiện Seller Card tự set `BoxDecoration` riêng).

---

## E. Widget dùng chung

### E.1 `VerifiedBadge`

**File:** `lib/widgets/verified_badge.dart`

**Cây widget:**

```text
Container (hình tròn, nền primary)
└── Icon(Icons.verified, size = size * 0.65)
```

| Tham số | Mặc định | Ý nghĩa |
|---------|----------|---------|
| `size` | `20` | Đường kính vòng tròn badge |

**Cách gắn lên avatar (bắt buộc dùng Stack):**

```dart
Stack(
  clipBehavior: Clip.none,  // cho phép badge tràn ra ngoài avatar
  children: [
    Container(/* avatar 72x72 */),
    const Positioned(
      right: -4,   // âm = nhô ra phải
      bottom: -4,
      child: VerifiedBadge(size: 24),
    ),
  ],
)
```

**Dùng tại:** `profile_screen.dart` (avatar 72), `product_detail.dart` (avatar 56, badge 22).

---

### E.2 `TrustScoreBar`

**File:** `lib/widgets/trust_score_bar.dart`

```dart
final progress = (score / maxScore).clamp(0.0, 1.0);
```

- `score = 920`, `maxScore = 1000` → `progress = 0.92` → thanh fill 92%.
- `clamp` tránh lỗi nếu score > maxScore hoặc âm.

**Cây widget:**

```text
Row
├── Expanded → ClipRRect → LinearProgressIndicator (minHeight: 6)
└── Text('$score')
```

**Chỉ dùng trong:** `admin_dashboard.dart` → cột DataTable 「ĐIỂM TÍN NHIỆM」.

---

## F. `main.dart` — giải thích từng dòng

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeMarketApp());
}
```

| Dòng | Giải thích |
|------|------------|
| `ensureInitialized()` | Bắt buộc nếu sau này dùng async trước `runApp` (Firebase, load config…) |
| `runApp(...)` | Gắn widget gốc vào cây Flutter, bắt đầu render |

```dart
return MaterialApp(
  title: 'SafeMarket',                    // tên app (task switcher)
  debugShowCheckedModeBanner: false,      // tắt ribbon DEBUG góc phải
  theme: AppTheme.lightTheme,
  home: const _AppLauncher(),
  routes: { ... },
);
```

**`routes` map:**

- Key: `String` bắt đầu bằng `/`.
- Value: hàm `(BuildContext) => Widget`.
- Gọi: `Navigator.pushNamed(context, '/profile')`.

**Không khai báo `initialRoute`** → Flutter dùng `home` làm màn đầu.

---

### F.1 `_AppLauncher` chi tiết

```dart
final screens = [ _LauncherItem(...), ... ];
```

`_LauncherItem` lưu 3 field: `title`, `icon`, `screen` (widget instance sẵn).

**ListView.separated:**

- `itemCount: screens.length` → 5 item.
- `separatorBuilder` → `SizedBox(height: 8)` giữa các Card.

**onTap ListTile:**

```dart
Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => item.screen),
);
```

- `MaterialPageRoute` = animation trượt từ phải (Material style).
- `builder: (_) => ...` — `_` là context của route mới (không dùng ở đây).

**FAB `pushReplacement`:**

- Xóa Launcher khỏi stack → Back từ Home **không** về Launcher.
- Phù hợp “vào app thật”.

---

## G. Điều hướng (Navigator) chi tiết

### Stack màn hình (ví dụ luồng đầy đủ)

```text
[Launcher]  → push → [Home] → push → [ProductDetail] → push → [Profile] → push → [eKYC]
                replace (FAB)     ↑ Back              ↑ Back           ↑ Back
```

| Hành động | API | Stack sau hành động |
|-----------|-----|---------------------|
| Mở màn mới | `Navigator.push` | A → B (B trên cùng) |
| Đóng màn hiện | `Navigator.pop` | Quay A |
| Thay màn gốc | `pushReplacement` | Chỉ còn màn mới |
| Mở theo tên | `pushNamed('/ekyc')` | Tương tự push |

### Import chéo giữa screens (hiện tại)

| File | Import screen | Lý do |
|------|---------------|-------|
| `marketplace_home.dart` | `product_detail`, `profile` | Tap sản phẩm / tab TÔI |
| `product_detail.dart` | `profile_screen` | Xem hồ sơ seller |
| `profile_screen.dart` | `identity_verification` | Tap eKYC |

**Cải tiến sau:** tạo `lib/routes/app_routes.dart` chứa tên route + factory, screens không import lẫn nhau.

---

## H. `marketplace_home.dart`

### H.1 Tổng quan class

| Class | Loại | Vai trò |
|-------|------|---------|
| `MarketplaceHomeScreen` | StatefulWidget | Màn root Chợ |
| `_MarketplaceHomeScreenState` | State | Giữ `_bottomIndex`, `_selectedCategory` |
| `_CategoryItem` | Data | label + icon + cờ `isAll` (chưa dùng filter logic) |
| `_ProductData` | Data | 7 field mô tả 1 sản phẩm |
| `_ProductCard` | UI | 1 ô trong grid |
| `_NavItem` | UI | 1 tab bottom |

### H.2 State — khi nào `setState`?

```dart
onTap: () => setState(() => _selectedCategory = index),
```

- Flutter gọi lại `build()` của **State** này.
- Chỉ `_buildCategories()` thấy `selected` đổi → đổi màu ô danh mục.
- **Chưa** lọc grid theo category (có thể thêm: filter `_products` theo `index`).

```dart
onTap: () => setState(() => _bottomIndex = 0),
```

- Đổi màu icon CHỦ / YÊU THÍCH / CHAT / TÔI.
- Tab YÊU THÍCH, CHAT **chưa** có màn riêng — chỉ đổi highlight.

### H.3 Cây widget body

```text
Scaffold
├── body: SafeArea
│   └── CustomScrollView
│       ├── SliverToBoxAdapter → _buildHeader()
│       ├── SliverToBoxAdapter → _buildSearchRow()
│       ├── SliverToBoxAdapter → _buildCategories()
│       ├── SliverToBoxAdapter → _buildSectionTitle()
│       └── SliverPadding (bottom: 100)
│           └── SliverGrid (2 cột) → _ProductCard × N
├── floatingActionButton (centerDocked)
└── bottomNavigationBar: BottomAppBar + Row _NavItem
```

**Vì sao `CustomScrollView` + Sliver?**

- Gộp **header cuộn chung** với **grid** trong một scroll — mượt hơn `Column` + `GridView` lồng nhau (tránh nested scroll conflict).
- `padding bottom: 100` — tránh nội dung bị FAB/BottomBar che.

### H.4 `SliverGridDelegateWithFixedCrossAxisCount`

```dart
crossAxisCount: 2,
mainAxisSpacing: 12,
crossAxisSpacing: 12,
childAspectRatio: 0.72,
```

**Công thức chiều cao ô (xấp xỉ):**

```text
cellHeight = cellWidth / childAspectRatio
cellWidth  ≈ (mànWidth - padding - spacing) / 2
```

`0.72` nghĩa là **cao hơn rộng** (~1.39:1) — phù hợp ảnh + 4 dòng chữ.

### H.5 `_buildHeader` — chấm đỏ thông báo

```dart
Stack(
  children: [
    IconButton(...),
    Positioned(right: 12, top: 12, child: Container 8×8 màu đỏ),
  ],
)
```

`Positioned` đặt tương đối **Stack cha** (vùng IconButton), không phải toàn màn hình.

### H.6 `_buildSearchRow`

- `Expanded` + `TextField` → ô search chiếm hết chiều ngang còn lại.
- `Material` + `InkWell` → hiệu ứng ripple nút lọc (48×48, bo 14).
- `onTap: () {}` — **placeholder**; sau gắn bottom sheet filter eKYC.

### H.7 `_ProductCard` — chia tỉ lệ ảnh/chữ

```dart
Column(
  children: [
    Expanded(flex: 3, child: Stack /* ảnh */),
    Expanded(flex: 4, child: Padding /* giá, tên, seller */),
  ],
)
```

Tổng flex = 7 → ảnh ~43%, chữ ~57% chiều cao card.

**GestureDetector** bọc ngoài → cả card bấm được, không chỉ từng Text.

### H.8 BottomAppBar + FAB

| Thuộc tính | Giá trị | Tác dụng |
|------------|---------|----------|
| `floatingActionButtonLocation.centerDocked` | — | FAB “cắm” vào giữa bottom bar |
| `shape: CircularNotchedRectangle()` | — | Cắt notch hình tròn quanh FAB |
| `notchMargin: 8` | — | Khe hở giữa FAB và bar |
| `SizedBox(width: 48)` giữa 2 cặp nav | — | Chừa chỗ FAB |

**FAB `onPressed: () {}`** — sau mở màn “Đăng tin”.

---

## I. `profile_screen.dart`

### I.1 Vì sao StatelessWidget?

Toàn bộ text/số đang **hard-code demo**. Khi gắn API, đổi thành:

```dart
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user});
  final User user;
}
```

hoặc StatefulWidget + `FutureBuilder`.

### I.2 Cây widget

```text
Scaffold
└── SafeArea
    └── CustomScrollView
        ├── SliverToBoxAdapter (tiêu đề Cá nhân + icons)
        └── SliverToBoxAdapter
            └── Padding 20
                ├── _UserHeaderSection
                ├── _StatsRow
                ├── _TrustCard
                ├── TRẠNG THÁI XÁC THỰC (Text)
                ├── _VerificationTile × 2
                └── ĐANG RAO BÁN (Row 2 _SellingProductCard)
```

### I.3 `_UserHeaderSection`

- Avatar **bo góc 16** (không tròn) — khớp thiết kế ảnh 2.
- Chữ `NA` = initials placeholder thay `NetworkImage`.

### I.4 `_StatsRow` — layout 1/3

```dart
Row(
  children: [
    Expanded(child: _StatCard(...)),
    SizedBox(width: 10),
    Expanded(...),
    Expanded(...),
  ],
)
```

Ba `Expanded` **không có flex** → chia **đều 1:1:1** chiều ngang.

### I.5 `_TrustCard` — logic progress

```dart
const score = 850;
const maxScore = 1000;
final progress = score / maxScore;  // = 0.85
```

`LinearProgressIndicator(value: progress)` — thanh trắng trên nền gradient.

Badge **VÀNG:** `Colors.white.withValues(alpha: 0.2)` — nền pill trong suốt.

### I.6 `_VerificationTile` — logic onTap

```dart
onTap: onTap ??
    (title.contains('eKYC') ? () { Navigator.push(...); } : null),
```

- Nếu truyền `onTap` từ ngoài → dùng ngoài.
- Nếu title chứa `'eKYC'` → mở `IdentityVerificationScreen`.
- Dòng “Giao dịch thành công” truyền `onTap: () {}` — chặn nhánh eKYC, nhưng hiện `{}` không làm gì (có thể mở màn lịch sử đơn).

**Cấu trúc:** `Material` → `InkWell` (ripple) → `Container(decoration: card())`.

---

## J. `identity_verification.dart`

### J.1 Layout 3 vùng dọc

```text
Scaffold
├── AppBar (back + title)
└── body: SafeArea
    └── Column
        ├── Expanded → SingleChildScrollView (cuộn nội dung)
        └── Padding → ElevatedButton full width (cố định đáy)
```

**Lợi ích:** Nút 「Xác thực ngay」luôn thấy trên màn nhỏ; phần trên vẫn cuộn được.

### J.2 `_PhoneIllustration`

| Lớp | Kích thước / style |
|-----|-------------------|
| Ngoài | full width, height 200, `#E3EDFF`, bo 24 |
| Trong | 80×140, viền primary 4px, bo 16 |
| Nút home giả | circle 28px đáy phone |

Không dùng asset SVG — vẽ bằng `Container` + `Border`.

### J.3 `_PreparationCard`

- Icon trong ô 48×48, `borderRadius: 12` (vuông bo).
- `Expanded` bọc Column text → text dài không tràn ra ngoài Row.

### J.4 `_SecurityNoticeBox`

- `crossAxisAlignment: start` — icon (i) căn trên cùng dòng đầu text nhiều dòng.
- `height: 1.5` line height — dễ đọc đoạn dài tiếng Việt.

---

## K. `product_detail.dart`

### K.1 Hai vùng scroll / cố định

```text
Scaffold
├── body: Column
│   ├── Row (back, share, favorite)
│   └── Expanded → SingleChildScrollView (padding bottom 100)
└── bottomNavigationBar: _BottomActionBar (cố định)
```

`SizedBox(height: 100)` cuối scroll — tránh seller card bị bar che.

### K.2 `_MetaChip`

- `mainAxisSize: min` — chip chỉ rộng bằng nội dung.
- Nền `#E5E7EB` — xám capsule như ảnh 3.

### K.3 `_SellerCard`

**Hàng trên:** `Stack` avatar + `VerifiedBadge` | tên + `Icons.verified` | `GestureDetector` “Xem hồ sơ >”.

**Hàng dưới:** 3× `Expanded` + `_SellerStatBox`:

- Chỉ cột TÍN NHIỆM truyền `valueColor: AppColors.primary`.
- Mỗi stat box: nền trắng **riêng**, shadow riêng — nổi trên nền xanh nhạt card lớn.

### K.4 `_BottomActionBar` — tỉ lệ 1:2

```dart
Expanded(flex: 1, child: /* Chat */),
Expanded(flex: 2, child: /* Mua ngay */),
```

Tổng flex = 3 → Chat ~33%, Mua ngay ~67% chiều ngang.

`SafeArea(top: false)` — chỉ chừa padding **đáy** (tai thỏ/home indicator), không thêm padding trên.

`bottomNavigationBar` của Scaffold **không** phải BottomNavigationBar widget — ở đây là custom `Container` trắng + shadow hướng lên (`offset: Offset(0, -4)`).

---

## L. `admin_dashboard.dart`

### L.1 Responsive — hai breakpoint

| Điều kiện | UI |
|-----------|-----|
| `width >= 900` | Sidebar cố định 240px + content |
| `width < 900` | Không sidebar; `drawer` + nút menu header |
| `constraints >= 800` (trong content) | Chart và Báo cáo **cạnh nhau** 7:3 |
| `< 800` | Chart trên, Báo cáo dưới |

```dart
final isWide = MediaQuery.sizeOf(context).width >= 900;
```

`MediaQuery.sizeOf` — API mới, lấy size màn hiện tại (không cần `MediaQuery.of(context).size`).

### L.2 `_AdminSidebar`

- `ListView.builder` — menu dài vẫn cuộn.
- Item chọn: `Material color: primary` + chữ/icon trắng.
- Item không chọn: nền trong suốt, chữ `textPrimary`.

**Drawer mobile:** `onSelect` gọi thêm `Navigator.pop(context)` đóng drawer sau khi chọn.

### L.3 `_AdminHeader` — vì sao `Builder`?

```dart
Builder(
  builder: (ctx) => IconButton(
    onPressed: () => Scaffold.of(ctx).openDrawer(),
  ),
)
```

`Scaffold.of(context)` cần `context` **nằm dưới** Scaffold. `Builder` tạo context con đúng cây — tránh lỗi “Scaffold not found”.

### L.4 `_StatsCardsRow` — Grid responsive

| `maxWidth` | `crossAxisCount` | `childAspectRatio` |
|------------|------------------|-------------------|
| > 1000 | 4 | 1.8 |
| > 600 | 2 | 1.8 |
| ≤ 600 | 1 | 2.8 (card thấp hơn trên mobile) |

`shrinkWrap: true` + `NeverScrollableScrollPhysics` — Grid nằm **trong** `SingleChildScrollView` cha, không scroll riêng.

### L.5 `_EkycChartCard` — biểu đồ không dùng thư viện

```dart
static const _values = [0.45, 0.62, 0.55, 0.78, 0.68, 0.85, 0.72];
```

Mỗi cột:

```text
Column
├── Expanded (chiếm phần còn lại của height 200)
│   └── Align(bottom)
│       └── FractionallySizedBox(heightFactor: _values[i])
│           └── Container (cột xanh)
└── Text nhãn T2…CN
```

`heightFactor: 0.85` = cột cao **85%** vùng Expanded → trực quan như bar chart 7 ngày.

### L.6 `_RecentReportsCard`

`_ReportItem` có `barColor` — vạch trái 4px cam/đỏ phân mức độ.

### L.7 `_UsersTableCard` — DataTable

**Cột:**

1. NGƯỜI DÙNG — `_UserCell` (CircleAvatar + tên + email).
2. TRẠNG THÁI — `_EkycBadge(verified: bool)`.
3. ĐIỂM — `TrustScoreBar` trong `SizedBox(width: 140)`.
4. GIAO DỊCH — text `"12 đơn"`.
5. HÀNH ĐỘNG — `IconButton` more_vert.

`SingleChildScrollView(scrollDirection: Axis.horizontal)` — bảng không bị vỡ trên màn hẹp.

**Dữ liệu mẫu `_users`:** 4 dòng; có thể map từ JSON API:

```json
{ "name": "...", "email": "...", "ekycVerified": true, "trustScore": 920, "orders": 12 }
```

---

## M. Công thức layout & responsive

### Tỉ lệ Flex trong Row

```text
widthChat = totalWidth * (flexChat / (flexChat + flexBuy))
         = totalWidth * (1 / 3)
```

### Progress bar (Profile & TrustScoreBar)

```text
progress = score / maxScore   // clamp 0..1
```

### Màu ARGB trong Flutter

```text
Color(0xFF1E60FF)
       ││└── Blue  (FF = 255)
       │└── Green
       └── Alpha (FF = không trong suốt)
```

---

## N. Mở rộng: API, ảnh, eKYC thật

### N.1 Truyền sản phẩm sang Product Detail

**Bước 1** — model:

```dart
class Product {
  final String id, name, price, sellerName;
  final int trustScore;
  // ...
}
```

**Bước 2** — constructor screen:

```dart
class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.product});
  final Product product;
}
```

**Bước 3** — push có arguments:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ProductDetailScreen(product: product),
  ),
);
```

### N.2 `FutureBuilder` thay list tĩnh (Home)

```dart
FutureBuilder<List<Product>>(
  future: productService.fetchFeatured(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) return Text('Lỗi: ${snapshot.error}');
    final list = snapshot.data ?? [];
    return SliverGrid(/* delegate build từ list */);
  },
)
```

### N.3 Assets ảnh

`pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/images/
```

Thay trong `_ProductCard`:

```dart
Image.asset('assets/images/${product.imagePath}', fit: BoxFit.cover)
```

### N.4 eKYC SDK

Trong `identity_verification.dart` dòng 74:

```dart
onPressed: () async {
  // final result = await EkycSdk.start(context);
  // if (result.success) Navigator.pop(context);
},
```

### N.5 Tách Admin app

- Cùng repo: `main_admin.dart` với `home: AdminDashboardScreen()`.
- Hoặc `flutter run -t lib/main_admin.dart` (tạo entry point riêng).

---

## O. FAQ & lỗi thường gặp

### O.1 Làm sao bỏ màn Demo Launcher?

`lib/main.dart` dòng 24:

```dart
home: const MarketplaceHomeScreen(),
```

### O.2 Bottom overflow / FAB che chữ?

- Tăng `padding` bottom trong `SliverPadding` (Home) hoặc `SizedBox` cuối scroll (Product).
- Kiểm tra `SafeArea` đã bọc chưa.

### O.3 Drawer Admin không mở?

- Phải có `drawer:` trên **cùng** `Scaffold` mà `openDrawer()` tìm tới.
- Dùng `Builder` như `_AdminHeader` — không gọi `Scaffold.of(context)` từ context sai cây.

### O.4 Đổi màu toàn app?

Chỉ sửa `lib/core/theme/app_colors.dart` (và kiểm tra chỗ hard-code `Color(0xFF...)` trong screen nếu có).

### O.5 Vì sao không dùng Provider / Bloc?

Yêu cầu đồ án UI thuần, dễ đọc. Khi có login/state, thêm `provider` hoặc `riverpod` ở lớp trên `MaterialApp`.

### O.6 `isAll` trong `_CategoryItem` dùng để gì?

Hiện **chưa** dùng trong logic — reserved để sau filter “TẤT CẢ” hiện full list, category khác lọc theo `categoryId`.

### O.7 Package name import lỗi?

Import phải là:

```dart
import 'package:safemarket_app/...';
```

Trùng `name:` trong `pubspec.yaml`. Đổi tên project → chạy lại hoặc sửa toàn bộ import.

---

## P. Kết nối SQL Server & Flutter (kiến trúc 3 tầng)

Phần này giải thích **cách SafeMarket lưu dữ liệu thật** bằng SQL Server và cách app Flutter lấy dữ liệu — phù hợp khi bạn làm khóa luận có **mobile + database + API**.

### P.0 Điểm quan trọng nhất (đọc trước)

**App Flutter trong repo này không nên (và hầu như không nên) kết nối thẳng vào SQL Server.**

Luồng đúng:

```text
[Điện thoại — Flutter]  ----HTTP/JSON---->  [API Backend]  ----SQL---->  [SQL Server]
```

| Thành phần | Vai trò |
|------------|---------|
| **SQL Server** | Lưu dữ liệu lâu dài: user, sản phẩm, báo cáo, eKYC… |
| **Backend (API)** | Nhận request từ app, chạy câu SQL, trả JSON |
| **Flutter (`safemarket_app`)** | Chỉ gọi URL API, hiển thị UI — **không** chứa password database |

**Vì sao không nối SQL trực tiếp từ Flutter?**

| Nếu Flutter nối thẳng SQL | Hậu quả |
|---------------------------|---------|
| Connection string nằm trong file APK/IPA | Decompile app → lộ user/password DB |
| Port 1433 thường bị chặn từ internet | App trên điện thoại 4G không vào được máy SQL nhà bạn |
| Không có lớp kiểm tra quyền (JWT, role Admin…) | Khó đạt yêu cầu bảo mật đồ án |

**Trạng thái repo hiện tại:** Chỉ có UI (`lib/screens/...`), dữ liệu **hard-code** trong Dart. SQL Server + API là **bước triển khai tiếp theo**, không nằm trong package Flutter này.

---

### P.1 Sơ đồ kiến trúc

```text
┌─────────────────┐     GET /api/products      ┌──────────────────┐
│  Flutter App    │ ──────────────────────────> │  ASP.NET Core    │
│  safemarket_app │ <────────────────────────── │  (hoặc Node.js)  │
└─────────────────┘     JSON [{ id, name... }]  └────────┬─────────┘
                                                         │
                                                         │ Connection String
                                                         ▼
                                                ┌──────────────────┐
                                                │   SQL Server     │
                                                │  SafeMarketDB    │
                                                └──────────────────┘
```

**Một câu nhớ:** *“Kết nối SQL Server” = cấu hình trên **Backend**; Flutter chỉ **gọi API**.*

---

### P.2 Bảng “ai làm việc gì”

| Việc cần làm | Làm ở đâu | Công cụ / file |
|--------------|-----------|----------------|
| Tạo database, bảng, INSERT mẫu | SQL Server | SSMS, script `.sql` |
| Connection string | Backend | `appsettings.json` (C#) hoặc `.env` (Node) |
| SELECT / INSERT / UPDATE | Backend | Controller, Repository, EF Core |
| Hiển thị danh sách sản phẩm trên Chợ | Flutter | `http.get` + `jsonDecode` |
| **Không làm** | Flutter | Không có `Server=...;Database=...` trong Dart |

---

### P.3 Bước 1 — Cài SQL Server và tạo database

#### P.3.1 Cài đặt

1. Cài **SQL Server** (bản **Express** miễn phí đủ cho khóa luận) hoặc Developer Edition.
2. Cài **SQL Server Management Studio (SSMS)** để quản lý DB bằng giao diện.
3. Đảm bảo dịch vụ đang chạy: Windows **Services** → **SQL Server (SQLEXPRESS)** hoặc **MSSQLSERVER** → **Start**.

#### P.3.2 Tạo database và bảng mẫu (khớp app SafeMarket)

Chạy trong SSMS (New Query):

```sql
CREATE DATABASE SafeMarketDB;
GO
USE SafeMarketDB;
GO

-- Người dùng / người bán (Profile, Admin table)
CREATE TABLE Users (
    Id            INT IDENTITY(1,1) PRIMARY KEY,
    FullName      NVARCHAR(100) NOT NULL,
    Email         NVARCHAR(100) NOT NULL,
    TrustScore    INT NOT NULL DEFAULT 0,
    EkycVerified  BIT NOT NULL DEFAULT 0,
    CreatedAt     DATETIME2 DEFAULT GETDATE()
);

-- Sản phẩm (Chợ, Chi tiết SP)
CREATE TABLE Products (
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    Name        NVARCHAR(200) NOT NULL,
    Price       DECIMAL(18,0) NOT NULL,
    SellerId    INT NOT NULL FOREIGN KEY REFERENCES Users(Id),
    Location    NVARCHAR(100),
    PostedAt    DATETIME2 DEFAULT GETDATE()
);

-- Báo cáo vi phạm (Admin — cột phải biểu đồ)
CREATE TABLE Reports (
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    UserId      INT FOREIGN KEY REFERENCES Users(Id),
    Reason      NVARCHAR(200),
    Severity    NVARCHAR(20),  -- 'orange', 'red'
    CreatedAt   DATETIME2 DEFAULT GETDATE()
);

-- Dữ liệu demo
INSERT INTO Users (FullName, Email, TrustScore, EkycVerified)
VALUES (N'Nguyễn Văn An', 'an@email.com', 850, 1),
       (N'Trần Thị B', 'b@email.com', 500, 0);

INSERT INTO Products (Name, Price, SellerId, Location)
VALUES (N'iPhone 13 Pro Max - 256GB', 15500000, 1, N'Quận 1');
```

#### P.3.3 Kiểm tra kết nối trong SSMS

| Trường | Giá trị thường dùng (máy local) |
|--------|----------------------------------|
| Server name | `localhost` hoặc `.\SQLEXPRESS` hoặc `(localdb)\MSSQLLocalDB` |
| Authentication | Windows Authentication hoặc SQL Server Authentication (`sa` + mật khẩu) |

Nếu đăng nhập SSMS được → SQL Server sẵn sàng cho Backend kết nối.

---

### P.4 Bước 2 — Connection String (chuỗi kết nối)

Connection string **chỉ đặt trên project API**, không commit password vào Git công khai (dùng User Secrets / biến môi trường khi deploy).

#### P.4.1 Đăng nhập SQL Server (User Id + Password)

```text
Server=localhost;Database=SafeMarketDB;User Id=sa;Password=MatKhauCuaBan;TrustServerCertificate=True;
```

| Tham số | Ý nghĩa |
|---------|---------|
| `Server` | Máy chứa SQL: `localhost`, `.\SQLEXPRESS`, hoặc IP server |
| `Database` | Tên DB: `SafeMarketDB` |
| `User Id` / `Password` | Tài khoản SQL (ví dụ `sa`) |
| `TrustServerCertificate=True` | Bỏ qua lỗi chứng chỉ SSL khi dev trên máy cá nhân |

#### P.4.2 Đăng nhập Windows (Trusted Connection)

```text
Server=localhost;Database=SafeMarketDB;Trusted_Connection=True;TrustServerCertificate=True;
```

Dùng khi API chạy trên cùng máy Windows với SQL và bạn login Windows được SSMS chấp nhận.

---

### P.5 Bước 3 — Backend kết nối SQL (ví dụ ASP.NET Core)

Đây là lớp **thật sự** nối tới SQL Server. Stack **C# + ASP.NET Core + EF Core** hay dùng cùng SQL Server trong đồ án CNTT Việt Nam.

#### P.5.1 Tạo project

Visual Studio → **Create a new project** → **ASP.NET Core Web API** → .NET 8.

#### P.5.2 Cấu hình connection string

File `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=SafeMarketDB;User Id=sa;Password=YOUR_PASSWORD;TrustServerCertificate=True;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    }
  },
  "AllowedHosts": "*"
}
```

Thay `YOUR_PASSWORD` bằng mật khẩu thật. **Không** push mật khẩu lên GitHub — dùng `appsettings.Development.json` (gitignore) hoặc User Secrets.

#### P.5.3 Đăng ký DbContext (`Program.cs`)

```csharp
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Cho Flutter Web / emulator gọi API local (dev)
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
});

var app = builder.Build();
app.UseCors();
app.UseSwagger();
app.UseSwaggerUI();
app.MapControllers();
app.Run();
```

#### P.5.4 Model + DbContext (ví dụ rút gọn)

```csharp
public class Product
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public decimal Price { get; set; }
    public int SellerId { get; set; }
    public string? Location { get; set; }
}

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
    public DbSet<Product> Products => Set<Product>();
}
```

Tạo migration (Package Manager Console):

```text
Add-Migration InitialCreate
Update-Database
```

#### P.5.5 API Controller trả JSON cho Flutter

```csharp
[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly AppDbContext _db;
    public ProductsController(AppDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var list = await _db.Products
            .Select(p => new {
                p.Id,
                p.Name,
                price = p.Price,
                p.Location
            })
            .ToListAsync();
        return Ok(list);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _db.Products.FindAsync(id);
        if (item == null) return NotFound();
        return Ok(item);
    }
}
```

Chạy API (F5 hoặc `dotnet run`) → mở Swagger → thử `GET /api/products` → thấy JSON là Backend đã nối SQL thành công.

#### P.5.6 Luồng dữ liệu một request (để hiểu rõ)

```text
1. Flutter: http.get('http://10.0.2.2:5000/api/products')
2. Kestrel (ASP.NET) nhận HTTP GET
3. ProductsController gọi _db.Products.ToListAsync()
4. EF Core sinh câu SQL: SELECT ... FROM Products
5. SQL Server trả rows
6. Controller serialize thành JSON → response 200
7. Flutter jsonDecode → List → vẽ GridView
```

---

### P.6 Bước 4 — Flutter gọi API (không nối SQL)

#### P.6.1 Thêm package

`pubspec.yaml`:

```yaml
dependencies:
  http: ^1.2.0
```

Chạy: `flutter pub get`.

#### P.6.2 Tạo service (gợi ý cấu trúc thư mục)

```text
lib/
  services/
    api_config.dart      # baseUrl theo môi trường
    product_api.dart     # fetchProducts()
```

**`lib/services/api_config.dart`:**

```dart
class ApiConfig {
  ApiConfig._();

  /// Android Emulator: 10.0.2.2 = localhost của máy PC host
  static const String androidEmulator = 'http://10.0.2.2:5000';

  /// iOS Simulator: có thể dùng localhost
  static const String iosSimulator = 'http://127.0.0.1:5000';

  /// Điện thoại thật: IP LAN máy chạy API (vd 192.168.1.10)
  static const String physicalDevice = 'http://192.168.1.10:5000';

  /// Đổi dòng này theo máy bạn đang test
  static const String baseUrl = androidEmulator;
}
```

**`lib/services/product_api.dart`:**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:safemarket_app/services/api_config.dart';

class ProductApi {
  static Future<List<Map<String, dynamic>>> fetchProducts() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/products');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('API lỗi ${response.statusCode}: ${response.body}');
  }
}
```

#### P.6.3 Gắn vào `marketplace_home.dart` (ý tưởng)

Thay list `_products` cứng bằng `FutureBuilder`:

```dart
FutureBuilder<List<Map<String, dynamic>>>(
  future: ProductApi.fetchProducts(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasError) {
      return SliverFillRemaining(
        child: Center(child: Text('Lỗi: ${snapshot.error}')),
      );
    }
    final list = snapshot.data ?? [];
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final p = list[index];
          return _ProductCard(
            product: _ProductData(
              name: p['name'] as String,
              price: '${p['price']}đ',
              // map thêm seller, trustScore khi API trả đủ field
              seller: '...',
              trustScore: 0,
              location: p['location'] as String? ?? '',
              time: '',
              icon: Icons.shopping_bag,
            ),
            onTap: () { /* push ProductDetail với id */ },
          );
        },
        childCount: list.length,
      ),
    );
  },
)
```

Repo hiện **chưa** có các file `services/` — bạn thêm khi làm phần backend.

#### P.6.4 Bảng URL theo môi trường test

| Bạn chạy app ở đâu | API chạy trên PC | `baseUrl` gợi ý |
|--------------------|------------------|-----------------|
| Android Emulator | `dotnet run` port 5000 | `http://10.0.2.2:5000` |
| iOS Simulator | cùng máy Mac/PC | `http://127.0.0.1:5000` |
| Điện thoại thật (cùng Wi-Fi) | IP máy tính | `http://192.168.x.x:5000` |
| Flutter Web | API local | `http://localhost:5000` + CORS |
| Production | Server cloud | `https://api.tenmiencuaban.com` |

**Lưu ý Android 9+:** HTTP không mã hóa có thể bị chặn — dev dùng `android:usesCleartextTraffic="true"` trong `AndroidManifest.xml` (chỉ dev) hoặc HTTPS.

---

### P.7 Liên kết từng màn Flutter ↔ bảng SQL (gợi ý)

| Màn Flutter | Dữ liệu cần từ SQL | API gợi ý |
|-------------|-------------------|-----------|
| `marketplace_home` | `Products` + join `Users` (seller) | `GET /api/products` |
| `product_detail` | 1 product + seller stats | `GET /api/products/{id}` |
| `profile_screen` | 1 user + trust + listings | `GET /api/users/me` |
| `admin_dashboard` | KPI đếm, chart eKYC, reports, users | `GET /api/admin/stats`, `/reports`, `/users` |
| `identity_verification` | Cập nhật trạng thái eKYC | `POST /api/ekyc/submit` |

---

### P.8 Lỗi thường gặp khi kết nối SQL / API

| Triệu chứng | Nguyên nhân | Cách xử lý |
|-------------|-------------|------------|
| Cannot connect to SQL Server | Service SQL tắt | Bật service trong Windows Services |
| Login failed for user `sa` | Sai password / chưa bật mixed mode | SSMS → Server Properties → Security |
| Flutter: Connection refused | Sai `baseUrl` hoặc API chưa chạy | Kiểm tra port Swagger, dùng `10.0.2.2` trên emulator |
| Flutter: `localhost` không work trên emulator | localhost = chính emulator | Đổi sang `10.0.2.2` |
| CORS error (Flutter Web) | API chưa AllowAnyOrigin | Thêm `AddCors` như mục P.5.3 |
| 401 / 403 sau này | Thiếu JWT | Thêm login API + gửi header `Authorization: Bearer ...` |
| Timeout trên điện thoại thật | Khác mạng Wi-Fi / firewall | Cùng LAN, mở port Windows Firewall cho API |

---

### P.9 Thứ tự làm đề xuất cho khóa luận SafeMarket

```text
1. SSMS: SafeMarketDB + bảng Users, Products, Reports
2. ASP.NET Core Web API + EF Core + Swagger test
3. Flutter: thêm http + lib/services/product_api.dart
4. Màn marketplace_home lấy grid từ API (một luồng end-to-end)
5. Mở rộng Profile, Admin, eKYC POST
6. (Tùy chọn) JWT đăng nhập, phân quyền Admin
```

**Câu trả lời cho hội đồng:** *“Em dùng kiến trúc 3 tầng: SQL Server lưu trữ, ASP.NET Core cung cấp REST API, Flutter client chỉ gọi API để đảm bảo bảo mật và tách lớp dữ liệu.”*

---

### P.10 Tóm tắt một trang

| Câu hỏi | Trả lời ngắn |
|---------|----------------|
| Flutter kết nối SQL Server thế nào? | **Gián tiếp** qua API, không connection string trong Dart |
| Connection string đặt ở đâu? | `appsettings.json` (Backend) |
| Flutter cần package gì? | `http` (hoặc `dio`) để gọi REST |
| Test local emulator Android? | API: `http://10.0.2.2:PORT` |
| Repo này đã có API chưa? | **Chưa** — UI demo; phần P là hướng dẫn triển khai |

---

## Q. Kết nối chuẩn & đồng bộ SQL → App (tóm tắt)

Hướng dẫn **đầy đủ từng bước** (API, Flutter, pull-refresh, polling, SignalR):  
→ **[docs/HUONG_DAN_KET_NOI_SQL_DONG_BO_APP.md](docs/HUONG_DAN_KET_NOI_SQL_DONG_BO_APP.md)**

### Ý chính

1. **Flutter không nối thẳng SQL** — chỉ gọi `http://.../api/...`.
2. **SQL đổi trong SSMS** → lần app **gọi lại API** mới thấy (hoặc dùng SignalR để báo app refresh).
3. **Thứ tự chạy:** SQL Server → `dotnet run` (API) → `flutter run` (app).
4. **Làm mới UI:** `FutureBuilder` + nút refresh / **Pull-to-refresh** / `Timer.periodic` (Admin).

### Luồng nhanh

```text
SSMS UPDATE  →  SafeMarketDB  →  GET /api/products  →  Flutter setState  →  UI mới
```

### `baseUrl` Flutter (dev)

| Thiết bị | URL |
|----------|-----|
| Android Emulator | `http://10.0.2.2:<PORT>` |
| Điện thoại thật | `http://<IP-máy-tính>:<PORT>` |

Chi tiết code mẫu `ProductApi`, `RefreshIndicator`, checklist test: xem file **docs** ở trên.

---

## Bảng tra nhanh: File → Màn hình thiết kế

| File | Ảnh mẫu | Widget root |
|------|---------|-------------|
| `marketplace_home.dart` | Ảnh 5 — Chợ | `MarketplaceHomeScreen` |
| `profile_screen.dart` | Ảnh 2 — Cá nhân | `ProfileScreen` |
| `identity_verification.dart` | Ảnh 1 — eKYC | `IdentityVerificationScreen` |
| `product_detail.dart` | Ảnh 3 — Chi tiết SP | `ProductDetailScreen` |
| `admin_dashboard.dart` | Ảnh 4 — SafeAdmin | `AdminDashboardScreen` |

---

## Phụ lục: Dependency

| Package | Vai trò |
|---------|---------|
| `flutter` | SDK UI, Material |
| `cupertino_icons` | Icon style iOS (ít dùng trong project) |
| `http` (khi làm API) | Gọi REST API từ Flutter — xem [mục P](#p-kết-nối-sql-server--flutter-kiến-trúc-3-tầng) |

---

*Tài liệu bám sát source `lib/` phiên bản 1.0.0+1. Mục A–O: UI Flutter; mục P: SQL Server + API + tích hợp. Khi sửa code, cập nhật README tương ứng.*
