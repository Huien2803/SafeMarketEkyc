import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Put,
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
import { UpdateProfileDto } from './dto/update-profile.dto';
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

  @Put('me')
  @ApiOperation({ summary: 'Cập nhật hồ sơ cá nhân' })
  @ApiResponse({ status: 200, type: UserProfileDto })
  updateMe(@CurrentUser() user: User, @Body() dto: UpdateProfileDto) {
    return this.usersService.updateProfile(Number(user.userId), dto);
  }

  @Get('me/sold-products')
  @ApiOperation({ summary: 'Sản phẩm đang rao / đã bán của tôi' })
  getSoldProducts(@CurrentUser() user: User) {
    return this.usersService.getSoldProducts(Number(user.userId));
  }

  @Get(':id/listings')
  @ApiOperation({ summary: 'Sản phẩm người bán đã đăng (public)' })
  getUserListings(@Param('id', ParseIntPipe) id: number) {
    return this.usersService.getUserListings(id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Xem profile public của user khác' })
  @ApiResponse({ status: 200, type: UserProfileDto })
  getById(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() viewer: User,
  ): Promise<UserProfileDto> {
    return this.usersService.getProfile(id, Number(viewer.userId));
  }
}
