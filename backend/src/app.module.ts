import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { User } from './entities/user.entity';
import { Score } from './entities/score.entity';
import { EkycProfile } from './entities/ekyc-profile.entity';
import { PointLog } from './entities/point-log.entity';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'mssql',
        host: config.get<string>('DB_HOST', 'localhost'),
        port: parseInt(config.get<string>('DB_PORT', '1433'), 10),
        username: config.get<string>('DB_USERNAME'),
        password: config.get<string>('DB_PASSWORD'),
        database: config.get<string>('DB_DATABASE'),
        entities: [User, Score, EkycProfile, PointLog],
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
      }),
    }),
    AuthModule,
    UsersModule,
  ],
})
export class AppModule {}
