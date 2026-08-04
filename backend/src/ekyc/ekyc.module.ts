import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { EkycProfile } from '../entities/ekyc-profile.entity';
import { User } from '../entities/user.entity';
import { EkycController } from './ekyc.controller';
import { EkycService } from './ekyc.service';
import { FptAiService } from './fpt-ai.service';
import { OcrProviderService } from './ocr-provider.service';
import { VnptEkycService } from './vnpt-ekyc.service';
import { EkycSessionService } from './ekyc-session.service';

@Module({
  imports: [TypeOrmModule.forFeature([EkycProfile, User]), AuthModule],
  controllers: [EkycController],
  providers: [
    EkycService,
    FptAiService,
    VnptEkycService,
    OcrProviderService,
    EkycSessionService,
  ],
  exports: [EkycService, FptAiService, VnptEkycService, OcrProviderService],
})
export class EkycModule {}
