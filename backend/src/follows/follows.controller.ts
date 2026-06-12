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
@ApiBearerAuth('JWT-auth')
@UseGuards(AuthGuard('jwt'))
@Controller('follows')
export class FollowsController {
  constructor(private readonly followsService: FollowsService) {}

  @Post(':userId')
  @ApiOperation({ summary: 'Theo dõi người bán/mua' })
  follow(
    @CurrentUser() user: User,
    @Param('userId', ParseIntPipe) userId: number,
  ) {
    return this.followsService.follow(Number(user.userId), userId);
  }

  @Delete(':userId')
  @ApiOperation({ summary: 'Bỏ theo dõi' })
  unfollow(
    @CurrentUser() user: User,
    @Param('userId', ParseIntPipe) userId: number,
  ) {
    return this.followsService.unfollow(Number(user.userId), userId);
  }

  @Get(':userId/status')
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
}
