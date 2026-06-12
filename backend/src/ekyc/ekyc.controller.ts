import {
  Body,
  Controller,
  Get,
  Post,
  UploadedFile,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import {
  FileFieldsInterceptor,
  FileInterceptor,
} from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../entities/user.entity';
import { EkycService } from './ekyc.service';
import { FptAiService } from './fpt-ai.service';
import {
  ScanIdFrontResponseDto,
  ScanIdBackResponseDto,
  FaceMatchResponseDto,
} from './dto/ekyc-response.dto';
import { SubmitEkycDto } from './dto/submit-ekyc.dto';
import { EkycStatusDto } from './dto/ekyc-status.dto';

/**
 * Endpoints eKYC (yêu cầu JWT):
 *   POST /api/ekyc/scan-id-front  - upload ảnh mặt trước CCCD -> OCR
 *   POST /api/ekyc/scan-id-back   - upload ảnh mặt sau CCCD -> OCR
 *   POST /api/ekyc/face-match     - upload 2 ảnh (CCCD + selfie) -> so khớp
 *   POST /api/ekyc/submit         - lưu hồ sơ vào DB, đánh dấu Verified
 *   GET  /api/ekyc/my-status      - xem trạng thái eKYC của tôi
 */
@ApiTags('ekyc')
@ApiBearerAuth('JWT-auth')
@UseGuards(AuthGuard('jwt'))
@Controller('ekyc')
export class EkycController {
  constructor(
    private readonly ekycService: EkycService,
    private readonly fptAi: FptAiService,
  ) {}

  // ---------- 1. OCR mặt trước ----------
  @Post('scan-id-front')
  @ApiOperation({ summary: 'Quét mặt trước CCCD/CMND qua FPT.AI OCR' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        image: { type: 'string', format: 'binary' },
      },
      required: ['image'],
    },
  })
  @ApiResponse({ status: 201, type: ScanIdFrontResponseDto })
  @UseInterceptors(FileInterceptor('image'))
  async scanIdFront(
    @UploadedFile() image: Express.Multer.File,
  ): Promise<ScanIdFrontResponseDto> {
    const ocr = await this.fptAi.scanIdCardFront(image);
    return {
      idNumber: ocr.idNumber,
      fullName: ocr.fullName,
      dob: ocr.dob,
      sex: ocr.sex,
      nationality: ocr.nationality,
      home: ocr.home,
      address: ocr.address,
      doe: ocr.doe,
      type: ocr.type,
    };
  }

  // ---------- 2. OCR mặt sau ----------
  @Post('scan-id-back')
  @ApiOperation({ summary: 'Quét mặt sau CCCD/CMND qua FPT.AI OCR' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { image: { type: 'string', format: 'binary' } },
      required: ['image'],
    },
  })
  @ApiResponse({ status: 201, type: ScanIdBackResponseDto })
  @UseInterceptors(FileInterceptor('image'))
  async scanIdBack(
    @UploadedFile() image: Express.Multer.File,
  ): Promise<ScanIdBackResponseDto> {
    const ocr = await this.fptAi.scanIdCardBack(image);
    return {
      features: ocr.features,
      issueDate: ocr.issueDate,
      issueLoc: ocr.issueLoc,
    };
  }

  // ---------- 3. Face Match ----------
  @Post('face-match')
  @ApiOperation({
    summary: 'So khớp ảnh CCCD vs ảnh selfie qua FPT.AI Face Match',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        idCard: { type: 'string', format: 'binary' },
        selfie: { type: 'string', format: 'binary' },
      },
      required: ['idCard', 'selfie'],
    },
  })
  @ApiResponse({ status: 201, type: FaceMatchResponseDto })
  @UseInterceptors(
    FileFieldsInterceptor([
      { name: 'idCard', maxCount: 1 },
      { name: 'selfie', maxCount: 1 },
    ]),
  )
  async faceMatch(
    @UploadedFiles()
    files: { idCard?: Express.Multer.File[]; selfie?: Express.Multer.File[] },
  ): Promise<FaceMatchResponseDto> {
    const idCard = files.idCard?.[0];
    const selfie = files.selfie?.[0];
    if (!idCard || !selfie) {
      throw new Error('Thiếu ảnh idCard hoặc selfie');
    }
    const r = await this.fptAi.matchFace(idCard, selfie);
    return {
      isMatch: r.isMatch,
      similarity: r.similarity,
      message: r.message,
    };
  }

  // ---------- 4. Liveness (demo — không cần FPT.AI) ----------
  @Post('liveness-check')
  @ApiOperation({ summary: 'Kiểm tra liveness selfie (demo)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { selfie: { type: 'string', format: 'binary' } },
      required: ['selfie'],
    },
  })
  @UseInterceptors(FileInterceptor('selfie'))
  livenessCheck(@UploadedFile() _selfie: Express.Multer.File) {
    return {
      passed: true,
      livenessToken: `live-${Date.now()}`,
    };
  }

  // ---------- 5. Submit / lưu DB ----------
  @Post('submit')
  @ApiOperation({
    summary: 'Lưu hồ sơ eKYC vào DB và đánh dấu user Verified',
  })
  @ApiResponse({ status: 201, type: EkycStatusDto })
  submit(
    @CurrentUser() user: User,
    @Body() dto: SubmitEkycDto,
  ): Promise<EkycStatusDto> {
    return this.ekycService.submit(Number(user.userId), dto);
  }

  // ---------- 6. Status ----------
  @Get('my-status')
  @ApiOperation({ summary: 'Trạng thái eKYC hiện tại của tôi' })
  @ApiResponse({ status: 200, type: EkycStatusDto })
  myStatus(@CurrentUser() user: User): Promise<EkycStatusDto> {
    return this.ekycService.getMyStatus(Number(user.userId));
  }
}
