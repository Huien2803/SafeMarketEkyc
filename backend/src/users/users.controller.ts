import {
  Controller,
  Get,
  Param,
  ParseIntPipe,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { UsersService } from './users.service';
import { UserProfileDto } from './dto/user-profile.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../entities/user.entity';

@ApiTags('users')
@ApiBearerAuth('JWT-auth')
@UseGuards(AuthGuard('jwt'))
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Profile + Trust Score + eKYC status của tôi' })
  @ApiResponse({ status: 200, type: UserProfileDto })
  getMe(@CurrentUser() user: User): Promise<UserProfileDto> {
    return this.usersService.getProfile(Number(user.userId));
  }

  @Get(':id')
  @ApiOperation({ summary: 'Xem profile public của user khác (dùng cho Seller Card)' })
  @ApiResponse({ status: 200, type: UserProfileDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy user' })
  getById(@Param('id', ParseIntPipe) id: number): Promise<UserProfileDto> {
    return this.usersService.getProfile(id);
  }
}
