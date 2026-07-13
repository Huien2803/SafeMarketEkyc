import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * Guard JWT "mềm": nếu có token hợp lệ thì gắn `req.user`, nếu không có
 * (hoặc token sai/hết hạn) vẫn cho request đi tiếp với `req.user = undefined`.
 * Dùng cho các route công khai nhưng muốn biết người xem là ai khi đã đăng nhập.
 */
@Injectable()
export class OptionalJwtAuthGuard extends AuthGuard('jwt') {
  handleRequest<TUser = unknown>(_err: unknown, user: TUser): TUser {
    return (user ?? undefined) as TUser;
  }
}
