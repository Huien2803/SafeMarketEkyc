import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { Review } from '../entities/review.entity';
import { Order } from '../entities/order.entity';
import { User } from '../entities/user.entity';
import { Score } from '../entities/score.entity';
import { PointLog } from '../entities/point-log.entity';
import { ReviewsController } from './reviews.controller';
import { ReviewsService } from './reviews.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Review, Order, User, Score, PointLog]),
    AuthModule,
  ],
  controllers: [ReviewsController],
  providers: [ReviewsService],
})
export class ReviewsModule {}
