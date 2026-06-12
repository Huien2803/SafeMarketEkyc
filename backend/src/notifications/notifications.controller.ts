import {
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../entities/user.entity';
import { NotificationsService } from './notifications.service';

@ApiTags('notifications')
@ApiBearerAuth('JWT-auth')
@UseGuards(AuthGuard('jwt'))
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: 'Danh sách thông báo của tôi' })
  list(@CurrentUser() user: User) {
    return this.notificationsService.listForUser(Number(user.userId));
  }

  @Patch(':id/read')
  @ApiOperation({ summary: 'Đánh dấu đã đọc một thông báo' })
  markRead(
    @CurrentUser() user: User,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.notificationsService.markRead(id, Number(user.userId));
  }

  @Post('read-all')
  @ApiOperation({ summary: 'Đánh dấu tất cả đã đọc' })
  markAllRead(@CurrentUser() user: User) {
    return this.notificationsService.markAllRead(Number(user.userId));
  }
}
