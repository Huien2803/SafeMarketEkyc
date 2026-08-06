import {
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../entities/user.entity';
import { FollowsService } from './follows.service';

@ApiTags('follows')
@Controller('follows')
export class FollowsController {
  constructor(private readonly followsService: FollowsService) {}

  @Post(':userId')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(AuthGuard('jwt'))
  @ApiOperation({ summary: 'Theo dõi người bán/mua' })
  follow(
    @CurrentUser() user: User,
    @Param('userId', ParseIntPipe) userId: number,
  ) {
    return this.followsService.follow(Number(user.userId), userId);
  }

  @Delete(':userId')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(AuthGuard('jwt'))
  @ApiOperation({ summary: 'Bỏ theo dõi' })
  unfollow(
    @CurrentUser() user: User,
    @Param('userId', ParseIntPipe) userId: number,
  ) {
    return this.followsService.unfollow(Number(user.userId), userId);
  }

  @Get(':userId/status')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(AuthGuard('jwt'))
  @ApiOperation({ summary: 'Trạng thái theo dõi + số follower' })
  async status(
    @CurrentUser() user: User,
    @Param('userId', ParseIntPipe) userId: number,
  ) {
    const viewerId = Number(user.userId);
    const [following, followerCount, followingCount] = await Promise.all([
      this.followsService.isFollowing(viewerId, userId),
      this.followsService.followerCount(userId),
      this.followsService.followingCount(userId),
    ]);
    return { following, followerCount, followingCount };
  }

  @Get(':userId/followers')
  @ApiOperation({ summary: 'Danh sách người theo dõi user' })
  listFollowers(@Param('userId', ParseIntPipe) userId: number) {
    return this.followsService.listFollowers(userId);
  }

  @Get(':userId/following')
  @ApiOperation({ summary: 'Danh sách user đang theo dõi' })
  listFollowing(@Param('userId', ParseIntPipe) userId: number) {
    return this.followsService.listFollowing(userId);
  }
}
