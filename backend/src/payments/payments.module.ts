import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { Order } from '../entities/order.entity';
import { Payment } from '../entities/payment.entity';
import { Product } from '../entities/product.entity';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { VnpayService } from './vnpay.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Order, Payment, Product]),
    AuthModule,
  ],
  controllers: [PaymentsController],
  providers: [PaymentsService, VnpayService],
  exports: [PaymentsService],
})
export class PaymentsModule {}
