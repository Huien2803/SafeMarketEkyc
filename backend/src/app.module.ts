import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { EkycModule } from './ekyc/ekyc.module';
import { ProductsModule } from './products/products.module';
import { OrdersModule } from './orders/orders.module';
import { ChatModule } from './chat/chat.module';
import { AdminModule } from './admin/admin.module';
import { ReviewsModule } from './reviews/reviews.module';
import { ReportsModule } from './reports/reports.module';
import { User } from './entities/user.entity';
import { Score } from './entities/score.entity';
import { EkycProfile } from './entities/ekyc-profile.entity';
import { PointLog } from './entities/point-log.entity';
import { Category } from './entities/category.entity';
import { Product } from './entities/product.entity';
import { ProductImage } from './entities/product-image.entity';
import { Order } from './entities/order.entity';
import { Payment } from './entities/payment.entity';
import { Review } from './entities/review.entity';
import { Report } from './entities/report.entity';
import { ChatThread } from './entities/chat-thread.entity';
import { ChatMessage } from './entities/chat-message.entity';
import { FollowsModule } from './follows/follows.module';
import { NotificationsModule } from './notifications/notifications.module';
import { PaymentsModule } from './payments/payments.module';
import { UserFollow } from './entities/user-follow.entity';
import { Notification } from './entities/notification.entity';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const host = config.get<string>('DB_HOST', 'localhost');
        const skipPort = host.includes('\\') || host.includes('(');
        const port = skipPort
          ? undefined
          : parseInt(config.get<string>('DB_PORT', '1433'), 10);

        return {
          type: 'mssql',
          host,
          ...(port ? { port } : {}),
          username: config.get<string>('DB_USERNAME'),
          password: config.get<string>('DB_PASSWORD'),
          database: config.get<string>('DB_DATABASE'),
          entities: [
            User,
            Score,
            EkycProfile,
            PointLog,
            Category,
            Product,
            ProductImage,
            Order,
            Payment,
            Review,
            Report,
            ChatThread,
            ChatMessage,
            UserFollow,
            Notification,
          ],
          synchronize: false,
          logging: ['error', 'warn'],
          options: {
            encrypt: config.get<string>('DB_ENCRYPT', 'false') === 'true',
            trustServerCertificate:
              config.get<string>('DB_TRUST_SERVER_CERT', 'true') === 'true',
            enableArithAbort: true,
          },
          extra: {
            trustServerCertificate: true,
          },
        };
      },
    }),
    AuthModule,
    UsersModule,
    EkycModule,
    ProductsModule,
    OrdersModule,
    ChatModule,
    AdminModule,
    ReviewsModule,
    ReportsModule,
    FollowsModule,
    NotificationsModule,
    PaymentsModule,
  ],
})
export class AppModule {}
