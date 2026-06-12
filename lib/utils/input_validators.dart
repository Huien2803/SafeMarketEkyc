/// Ràng buộc nhập liệu — đồng bộ với backend `validation.constants.ts`.
class InputValidators {
  InputValidators._();

  static const minProductPrice = 50001;
  static const minProductCondition = 65;
  static const maxProductDescription = 200;

  static final _vnPhone = RegExp(r'^0\d{9}$');
  static final _displayName = RegExp(r'^[a-zA-ZÀ-ỹ\s]+$');
  static final _strongPassword = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
  );

  static String? vnPhoneNumber(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Vui lòng nhập số điện thoại';
    if (!_vnPhone.hasMatch(t)) {
      return 'SĐT Việt Nam: 10 chữ số, bắt đầu bằng 0 (vd. 0912345678)';
    }
    return null;
  }

  static String? displayName(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Vui lòng nhập họ và tên';
    if (t.length < 2) return 'Họ và tên tối thiểu 2 ký tự';
    if (!_displayName.hasMatch(t)) {
      return 'Họ và tên không được chứa ký tự đặc biệt hoặc số';
    }
    return null;
  }

  static String? strongPassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (!_strongPassword.hasMatch(value)) {
      return 'Mật khẩu ≥8 ký tự: chữ hoa, chữ thường, số và ký tự đặc biệt';
    }
    return null;
  }

  static String? productPrice(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nhập giá sản phẩm';
    final n = int.tryParse(value.replaceAll('.', '').replaceAll(',', ''));
    if (n == null) return 'Giá không hợp lệ';
    if (n < minProductPrice) {
      return 'Giá phải cao hơn 50.000đ';
    }
    return null;
  }

  static String? productDescription(String? value) {
    final t = value ?? '';
    if (t.length > maxProductDescription) {
      return 'Mô tả tối đa $maxProductDescription ký tự';
    }
    return null;
  }

  static String? productCondition(num value) {
    if (value < minProductCondition) {
      return 'Độ bền tối thiểu $minProductCondition%';
    }
    return null;
  }
}
