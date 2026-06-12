import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { Category } from '../entities/category.entity';
import { Product } from '../entities/product.entity';
import { ProductImage } from '../entities/product-image.entity';
import { Score } from '../entities/score.entity';
import { Review } from '../entities/review.entity';
import { CategoriesService } from './categories.service';
import { ProductsService } from './products.service';
import { ProductsController } from './products.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([Category, Product, ProductImage, Score, Review]),
    AuthModule,
    NotificationsModule,
  ],
  controllers: [ProductsController],
  providers: [CategoriesService, ProductsService],
  exports: [CategoriesService, ProductsService],
})
export class ProductsModule {}
