import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['log', 'error', 'warn', 'debug'],
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
}

bootstrap();
