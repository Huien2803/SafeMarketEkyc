import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { FollowsModule } from '../follows/follows.module';
import { OrdersModule } from '../orders/orders.module';
import { User } from '../entities/user.entity';
import { Score } from '../entities/score.entity';
import { EkycProfile } from '../entities/ekyc-profile.entity';
import { Product } from '../entities/product.entity';
import { Order } from '../entities/order.entity';
import { Review } from '../entities/review.entity';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      Score,
      EkycProfile,
      Product,
      Order,
      Review,
    ]),
    AuthModule,
    OrdersModule,
    FollowsModule,
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
