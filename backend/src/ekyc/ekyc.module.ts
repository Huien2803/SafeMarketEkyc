import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { EkycProfile } from '../entities/ekyc-profile.entity';
import { User } from '../entities/user.entity';
import { EkycController } from './ekyc.controller';
import { EkycService } from './ekyc.service';
import { FptAiService } from './fpt-ai.service';

@Module({
  imports: [TypeOrmModule.forFeature([EkycProfile, User]), AuthModule],
  controllers: [EkycController],
  providers: [EkycService, FptAiService],
  exports: [EkycService, FptAiService],
})
export class EkycModule {}
