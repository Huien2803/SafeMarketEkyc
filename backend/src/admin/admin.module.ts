import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { User } from '../entities/user.entity';
import { Score } from '../entities/score.entity';
import { Report } from '../entities/report.entity';
import { EkycProfile } from '../entities/ekyc-profile.entity';
import { Order } from '../entities/order.entity';
import { Product } from '../entities/product.entity';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { AdminGuard } from '../common/guards/admin.guard';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, Score, Report, EkycProfile, Order, Product]),
    AuthModule,
  ],
  controllers: [AdminController],
  providers: [AdminService, AdminGuard],
})
export class AdminModule {}
