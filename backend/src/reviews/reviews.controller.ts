import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../entities/user.entity';
import { ReviewsService } from './reviews.service';

@ApiTags('reviews')
@Controller('reviews')
export class ReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @Post()
  @ApiBearerAuth('JWT-auth')
  @UseGuards(AuthGuard('jwt'))
  submit(
    @CurrentUser() user: User,
    @Body() body: { orderId: number; rating: number; comment?: string },
  ) {
    return this.reviewsService.submit(
      Number(user.userId),
      body.orderId,
      body.rating,
      body.comment,
    );
  }

  @Get('order/:orderId/status')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(AuthGuard('jwt'))
  orderStatus(
    @CurrentUser() user: User,
    @Param('orderId', ParseIntPipe) orderId: number,
  ) {
    return this.reviewsService.getOrderStatus(orderId, Number(user.userId));
  }

  @Get('user/:userId')
  userReviews(@Param('userId', ParseIntPipe) userId: number) {
    return this.reviewsService.getUserReviews(userId);
  }
}
