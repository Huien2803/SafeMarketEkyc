import {
  BadRequestException,
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
import { OcrProviderService } from './ocr-provider.service';
import { EkycSessionService } from './ekyc-session.service';
import {
  ScanIdFrontResponseDto,
  ScanIdBackResponseDto,
  FaceMatchResponseDto,
} from './dto/ekyc-response.dto';
import {
  SubmitEkycDto,
  StartSessionResponseDto,
  CompleteLivenessDto,
} from './dto/submit-ekyc.dto';
import { EkycStatusDto } from './dto/ekyc-status.dto';
import { ConfigService } from '@nestjs/config';

/**
 * eKYC chuẩn ngân hàng / VNeID (luồng bắt buộc):
 *   1) POST /session/start
 *   2) POST /scan-id-front  (+ sessionId)
 *   3) POST /scan-id-back   (+ sessionId)
 *   4) POST /liveness/complete (+ sessionId + selfie + points) → token
 *   5) POST /face-match     (+ sessionId + selfie) → so khớp CCCD
 *   6) POST /submit         (sessionId + livenessToken)
 */
@ApiTags('ekyc')
@ApiBearerAuth('JWT-auth')
@UseGuards(AuthGuard('jwt'))
@Controller('ekyc')
export class EkycController {
  constructor(
    private readonly ekycService: EkycService,
    private readonly ocr: OcrProviderService,
    private readonly sessions: EkycSessionService,
    private readonly config: ConfigService,
  ) {}

  @Post('session/start')
  @ApiOperation({ summary: 'Mở phiên eKYC mới (TTL ~30 phút)' })
  @ApiResponse({ status: 201, type: StartSessionResponseDto })
  startSession(@CurrentUser() user: User): StartSessionResponseDto {
    return this.sessions.start(Number(user.userId));
  }

  @Post('scan-id-front')
  @ApiOperation({ summary: 'Bước 1 — Quét mặt trước CCCD (gắn session)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        image: { type: 'string', format: 'binary' },
        sessionId: { type: 'string' },
      },
      required: ['image', 'sessionId'],
    },
  })
  @ApiResponse({ status: 201, type: ScanIdFrontResponseDto })
  @UseInterceptors(FileInterceptor('image'))
  async scanIdFront(
    @CurrentUser() user: User,
    @UploadedFile() image: Express.Multer.File,
    @Body('sessionId') sessionId: string,
  ): Promise<ScanIdFrontResponseDto & { sessionId: string }> {
    if (!sessionId?.trim()) {
      throw new BadRequestException('Thiếu sessionId — hãy bắt đầu phiên eKYC.');
    }
    if (!image?.buffer?.length) {
      throw new BadRequestException('Thiếu ảnh mặt trước CCCD.');
    }
    const ocr = await this.ocr.scanIdCardFront(image);
    const snap = this.sessions.saveFront(
      Number(user.userId),
      sessionId.trim(),
      ocr,
      image,
    );
    return {
      sessionId: sessionId.trim(),
      idNumber: snap.idNumber,
      fullName: snap.fullName,
      dob: snap.dob,
      sex: snap.sex,
      nationality: snap.nationality,
      home: snap.home,
      address: snap.address,
      doe: snap.doe,
      type: snap.type,
    };
  }

  @Post('scan-id-back')
  @ApiOperation({ summary: 'Bước 2 — Quét mặt sau CCCD (gắn session)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        image: { type: 'string', format: 'binary' },
        sessionId: { type: 'string' },
      },
      required: ['image', 'sessionId'],
    },
  })
  @ApiResponse({ status: 201, type: ScanIdBackResponseDto })
  @UseInterceptors(FileInterceptor('image'))
  async scanIdBack(
    @CurrentUser() user: User,
    @UploadedFile() image: Express.Multer.File,
    @Body('sessionId') sessionId: string,
  ): Promise<ScanIdBackResponseDto & { sessionId: string }> {
    if (!sessionId?.trim()) {
      throw new BadRequestException('Thiếu sessionId.');
    }
    if (!image?.buffer?.length) {
      throw new BadRequestException('Thiếu ảnh mặt sau CCCD.');
    }
    const ocr = await this.ocr.scanIdCardBack(image);
    const snap = this.sessions.saveBack(
      Number(user.userId),
      sessionId.trim(),
      ocr,
      image,
    );
    return {
      sessionId: sessionId.trim(),
      features: snap.features,
      issueDate: snap.issueDate,
      issueLoc: snap.issueLoc,
    };
  }

  @Post('liveness/complete')
  @ApiOperation({
    summary:
      'Bước 3a — Xác nhận Face ID (liveness): lưu selfie + phát token server',
  })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('selfie'))
  async completeLiveness(
    @CurrentUser() user: User,
    @UploadedFile() selfie: Express.Multer.File,
    @Body() body: CompleteLivenessDto,
  ) {
    const points = Number(body.recognitionPoints);
    return this.sessions.completeLiveness(
      Number(user.userId),
      String(body.sessionId ?? '').trim(),
      selfie,
      points,
    );
  }

  @Post('face-match')
  @ApiOperation({
    summary:
      'Bước 3b — So khớp selfie với ảnh chân dung CCCD (bắt buộc trước submit)',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        sessionId: { type: 'string' },
        selfie: { type: 'string', format: 'binary' },
        idCard: { type: 'string', format: 'binary' },
      },
      required: ['sessionId'],
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
    @CurrentUser() user: User,
    @UploadedFiles()
    files: { idCard?: Express.Multer.File[]; selfie?: Express.Multer.File[] },
    @Body('sessionId') sessionId: string,
  ): Promise<FaceMatchResponseDto> {
    if (!sessionId?.trim()) {
      throw new BadRequestException('Thiếu sessionId.');
    }
    const uid = Number(user.userId);
    const state = this.sessions.getForUser(uid, sessionId.trim());
    if (!state.front || !state.liveness) {
      throw new BadRequestException(
        'Cần hoàn tất CCCD mặt trước và Face ID trước khi so khớp khuôn mặt.',
      );
    }

    const idCard =
      files.idCard?.[0] ??
      this.sessions.readFileAsMulter(state.front.filePath, 'front.jpg');
    const selfie =
      files.selfie?.[0] ??
      this.sessions.readFileAsMulter(state.liveness.selfiePath, 'selfie.jpg');

    const result = await this.runFaceMatch(idCard, selfie);
    this.sessions.markFaceMatch(uid, sessionId.trim(), result);
    return {
      isMatch: result.isMatch,
      similarity: result.similarity,
      message: result.message,
      mode: result.mode,
    };
  }

  @Post('submit')
  @ApiOperation({
    summary: 'Nộp hồ sơ eKYC — chỉ chấp nhận session đã đủ bước',
  })
  @ApiResponse({ status: 201, type: EkycStatusDto })
  submit(
    @CurrentUser() user: User,
    @Body() dto: SubmitEkycDto,
  ): Promise<EkycStatusDto> {
    return this.ekycService.submit(Number(user.userId), dto);
  }

  @Get('my-status')
  @ApiOperation({ summary: 'Trạng thái eKYC hiện tại' })
  @ApiResponse({ status: 200, type: EkycStatusDto })
  myStatus(@CurrentUser() user: User): Promise<EkycStatusDto> {
    return this.ekycService.getMyStatus(Number(user.userId));
  }

  /**
   * So khớp thật selfie vs CCCD (VNPT/FPT).
   * `attested` chỉ khi EKYC_FACE_MATCH_MODE=attested (demo) — không tự fallback.
   */
  private async runFaceMatch(
    idCard: Express.Multer.File,
    selfie: Express.Multer.File,
  ): Promise<{
    similarity: number;
    isMatch: boolean;
    mode: 'fpt' | 'vnpt' | 'attested';
    message: string;
  }> {
    const mode = (
      this.config.get<string>('EKYC_FACE_MATCH_MODE', 'auto') || 'auto'
    )
      .trim()
      .toLowerCase();

    if (mode === 'attested') {
      return {
        similarity: 0.85,
        isMatch: true,
        mode: 'attested',
        message:
          'Chế độ attested: bỏ qua so khớp CCCD (chỉ Face ID sống). Không dùng khi bảo vệ.',
      };
    }

    const r = await this.ocr.matchFace(idCard, selfie);
    return {
      similarity: r.similarity,
      isMatch: r.isMatch,
      mode: this.ocr.activeProvider,
      message: r.message || 'So khớp khuôn mặt với CCCD thành công.',
    };
  }
}
