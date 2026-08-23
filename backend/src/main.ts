import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { ensureProductUploadDir } from './products/product-upload.config';
import { ensureChatUploadDir } from './chat/chat-upload.config';
import { ensureOrderUploadDir } from './orders/order-upload.config';
import { ensureAvatarUploadDir } from './users/avatar-upload.config';
import { getLanIPv4 } from './common/utils/lan-host.util';
import { DevService } from './dev/dev.service';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: ['log', 'error', 'warn', 'debug'],
  });

  const config = app.get(ConfigService);
  const isProd =
    config.get<string>('NODE_ENV', 'development') === 'production';

  if (isProd) {
    const secret = config.get<string>('JWT_SECRET', '');
    if (
      !secret ||
      secret.includes('change_me') ||
      secret.includes('dev_secret') ||
      secret.length < 32
    ) {
      throw new Error(
        'Production yêu cầu JWT_SECRET mạnh (≥32 ký tự, không dùng giá trị mẫu).',
      );
    }
    const smtpHost = config.get<string>('SMTP_HOST', '').trim();
    const smtpUser = config.get<string>('SMTP_USER', '').trim();
    const smtpPass = config.get<string>('SMTP_PASS', '').trim();
    if (!smtpHost || !smtpUser || !smtpPass) {
      throw new Error(
        'Production yêu cầu cấu hình SMTP_HOST / SMTP_USER / SMTP_PASS.',
      );
    }
    const corsOrigins = config.get<string>('CORS_ORIGINS', '').trim();
    if (!corsOrigins) {
      throw new Error(
        'Production yêu cầu CORS_ORIGINS (danh sách origin cách nhau bởi dấu phẩy).',
      );
    }
  }

  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );

  ensureProductUploadDir();
  ensureChatUploadDir();
  ensureOrderUploadDir();
  ensureAvatarUploadDir();
  app.useStaticAssets(join(process.cwd(), 'uploads'), {
    prefix: '/uploads/',
  });

  const corsRaw = config.get<string>('CORS_ORIGINS', '').trim();
  if (corsRaw) {
    const allowlist = corsRaw.split(',').map((o) => o.trim()).filter(Boolean);
    app.enableCors({
      origin: allowlist,
      credentials: true,
    });
  } else {
    app.enableCors({
      origin: true,
      credentials: true,
    });
  }

  app.setGlobalPrefix('api');

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  const enableSwagger =
    !isProd || config.get<string>('ENABLE_SWAGGER', 'false') === 'true';
  if (enableSwagger) {
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
  }

  const port = parseInt(config.get<string>('PORT', '3000'), 10);
  // 0.0.0.0: cho phép điện thoại cùng WiFi gọi API (không chỉ localhost)
  await app.listen(port, '0.0.0.0');

  const lan = getLanIPv4();
  Logger.log(`SafeMarket API ready at http://localhost:${port}/api`, 'Bootstrap');
  if (lan) {
    Logger.log(
      `Điện thoại (WiFi):  http://${lan}:${port}/api`,
      'Bootstrap',
    );
    Logger.log(
      `App config:         http://${lan}:${port}/api/dev/client-config`,
      'Bootstrap',
    );
  }
  Logger.log(
    `Điện thoại (adb):   http://127.0.0.1:${port}/api  (sau adb reverse)`,
    'Bootstrap',
  );
  if (!isProd) {
    try {
      const devService = app.get(DevService);
      const logs = await devService.runPhoneSetup();
      for (const line of logs) {
        Logger.log(line, 'PhoneSetup');
      }
    } catch (e) {
      Logger.warn(`PhoneSetup: ${(e as Error).message}`, 'Bootstrap');
    }
  }
  if (enableSwagger) {
    Logger.log(`Swagger UI:        http://localhost:${port}/api/docs`, 'Bootstrap');
  }
  Logger.log(`Uploads static:    http://localhost:${port}/uploads/`, 'Bootstrap');
  Logger.log(
    'HTTPS: terminate TLS tại reverse proxy (Nginx/Caddy), Nest lắng nghe HTTP nội bộ.',
    'Bootstrap',
  );
}

bootstrap();
