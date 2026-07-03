import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { AppModule } from './app.module';
import { ensureProductUploadDir } from './products/product-upload.config';
import { ensureChatUploadDir } from './chat/chat-upload.config';
import { ensureOrderUploadDir } from './orders/order-upload.config';
import { ensureAvatarUploadDir } from './users/avatar-upload.config';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: ['log', 'error', 'warn', 'debug'],
  });

  // Phục vụ ảnh upload từ thư mục backend/uploads/ tại http://host:3000/uploads/...
  ensureProductUploadDir();
  ensureChatUploadDir();
  ensureOrderUploadDir();
  ensureAvatarUploadDir();
  app.useStaticAssets(join(process.cwd(), 'uploads'), {
    prefix: '/uploads/',
  });

  app.enableCors({
    origin: true,
    credentials: true,
  });

  app.setGlobalPrefix('api');

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  const swaggerConfig = new DocumentBuilder()
    .setTitle('SafeMarket API')
    .setDescription(
      'API cho hệ thống Marketplace đồ cũ an toàn (eKYC + Trust Score). ' +
        'KLTN HUFLIT 2026 - Trương Trí Hiền & Lê Tấn Lộc.',
    )
    .setVersion('0.1.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        in: 'header',
      },
      'JWT-auth',
    )
    .addTag('auth', 'Đăng ký, đăng nhập, JWT')
    .addTag('users', 'Hồ sơ người dùng & điểm tín nhiệm')
    .addTag('ekyc', 'Xác thực danh tính qua FPT.AI')
    .addTag('products', 'Quản lý sản phẩm rao bán')
    .addTag('orders', 'Đơn hàng')
    .addTag('payments', 'Thanh toán (VNPay/MoMo)')
    .addTag('admin', 'Thống kê & duyệt báo cáo')
    .addTag('chat', 'Nhắn tin mua bán')
    .addTag('reviews', 'Đánh giá sau giao dịch')
    .addTag('reports', 'Báo cáo vi phạm')
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document, {
    swaggerOptions: { persistAuthorization: true },
  });

  const config = app.get(ConfigService);
  const port = parseInt(config.get<string>('PORT', '3000'), 10);
  await app.listen(port);

  Logger.log(`SafeMarket API ready at http://localhost:${port}/api`, 'Bootstrap');
  Logger.log(`Swagger UI:        http://localhost:${port}/api/docs`, 'Bootstrap');
  Logger.log(`Uploads static:    http://localhost:${port}/uploads/`, 'Bootstrap');
}

bootstrap();
