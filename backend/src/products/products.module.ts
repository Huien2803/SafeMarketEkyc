import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { Category } from '../entities/category.entity';
import { Product } from '../entities/product.entity';
import { ProductImage } from '../entities/product-image.entity';
import { Score } from '../entities/score.entity';
import { Review } from '../entities/review.entity';
import { User } from '../entities/user.entity';
import { Order } from '../entities/order.entity';
import { Payment } from '../entities/payment.entity';
import { Report } from '../entities/report.entity';
import { ChatThread } from '../entities/chat-thread.entity';
import { CategoriesService } from './categories.service';
import { ProductsService } from './products.service';
import { ProductsController } from './products.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Category,
      Product,
      ProductImage,
      Score,
      Review,
      User,
      Order,
      Payment,
      Report,
      ChatThread,
    ]),
    AuthModule,
    NotificationsModule,
  ],
  controllers: [ProductsController],
  providers: [CategoriesService, ProductsService],
  exports: [CategoriesService, ProductsService],
})
export class ProductsModule {}
