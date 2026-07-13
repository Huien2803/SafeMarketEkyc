import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { User } from '../entities/user.entity';
import { Score } from '../entities/score.entity';
import { Report } from '../entities/report.entity';
import { EkycProfile } from '../entities/ekyc-profile.entity';
import { Order } from '../entities/order.entity';
import { Product } from '../entities/product.entity';
import { Payment } from '../entities/payment.entity';
import { PointLog } from '../entities/point-log.entity';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { AdminGuard } from '../common/guards/admin.guard';
import { NotificationsModule } from '../notifications/notifications.module';
import { PaymentsModule } from '../payments/payments.module';
import { WalletModule } from '../wallet/wallet.module';
import { ReputationModule } from '../reputation/reputation.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      Score,
      PointLog,
      Report,
      EkycProfile,
      Order,
      Product,
      Payment,
    ]),
    AuthModule,
    NotificationsModule,
    PaymentsModule,
    WalletModule,
    ReputationModule,
  ],
  controllers: [AdminController],
  providers: [AdminService, AdminGuard],
})
export class AdminModule {}
