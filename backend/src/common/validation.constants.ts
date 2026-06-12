/** Ràng buộc dữ liệu SafeMarket — đồng bộ với Flutter `input_validators.dart`. */

/** SĐT Việt Nam: 10 chữ số, bắt đầu bằng 0 (vd. 0912345678). */
export const VN_PHONE_PATTERN = /^0\d{9}$/;

export const VN_PHONE_MESSAGE =
  'Số điện thoại Việt Nam phải gồm 10 chữ số, bắt đầu bằng 0';

/** Họ tên: chữ cái (Unicode) và khoảng trắng. */
export const DISPLAY_NAME_PATTERN = /^[\p{L}\s]+$/u;

export const DISPLAY_NAME_MESSAGE =
  'Họ và tên chỉ được chứa chữ cái và khoảng trắng';

/** ≥8 ký tự, có chữ thường, hoa, số và ký tự đặc biệt. */
export const STRONG_PASSWORD_PATTERN =
  /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$/;

export const STRONG_PASSWORD_MESSAGE =
  'Mật khẩu tối thiểu 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt';

export const MIN_PRODUCT_PRICE = 50001;

export const MIN_PRODUCT_CONDITION = 65;

export const MAX_PRODUCT_DESCRIPTION = 200;
