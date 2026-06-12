import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { User } from '../../entities/user.entity';

@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const user = context.switchToHttp().getRequest().user as User | undefined;
    if (!user?.isAdmin) {
      throw new ForbiddenException('Chỉ admin mới được truy cập');
    }
    return true;
  }
}
