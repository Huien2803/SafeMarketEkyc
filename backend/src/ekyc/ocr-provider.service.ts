import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  FptAiService,
  IdCardBackOcr,
  IdCardFrontOcr,
  FaceMatchResult,
} from './fpt-ai.service';
import { VnptEkycService } from './vnpt-ekyc.service';
import {
  decodeCccdQrFromImage,
  mergeOcrWithQr,
} from './cccd-qr.util';

/**
 * Chọn nhà cung cấp OCR theo EKYC_OCR_PROVIDER=vnpt|fpt
 * (mặc định: vnpt nếu đã cấu hình đủ, không thì fpt).
 *
 * VNPT invalid_token / 401 → tự fallback FPT nếu còn API key.
 * Sau OCR: thiếu field → bổ sung từ QR CCCD chip.
 */
@Injectable()
export class OcrProviderService {
  private readonly logger = new Logger(OcrProviderService.name);
  private readonly provider: 'vnpt' | 'fpt';

  constructor(
    private readonly config: ConfigService,
    private readonly fpt: FptAiService,
    private readonly vnpt: VnptEkycService,
  ) {
    const raw = this.config
      .get<string>('EKYC_OCR_PROVIDER', '')
      .trim()
      .toLowerCase();
    if (raw === 'vnpt' || raw === 'fpt') {
      this.provider = raw;
    } else {
      this.provider = this.vnpt.isConfigured() ? 'vnpt' : 'fpt';
    }
  }

  get activeProvider(): 'vnpt' | 'fpt' {
    return this.provider;
  }

  async scanIdCardFront(file: Express.Multer.File): Promise<IdCardFrontOcr> {
    const ocr = await this.withProviderFallback(
      'front',
      () => this.vnpt.scanIdCardFront(file),
      () => this.fpt.scanIdCardFront(file),
    );
    return this.enrichWithQr(file, ocr);
  }

  async scanIdCardBack(file: Express.Multer.File): Promise<IdCardBackOcr> {
    return this.withProviderFallback(
      'back',
      () => this.vnpt.scanIdCardBack(file),
      () => this.fpt.scanIdCardBack(file),
    );
  }

  matchFace(
    idCard: Express.Multer.File,
    selfie: Express.Multer.File,
  ): Promise<FaceMatchResult> {
    return this.fpt.matchFace(idCard, selfie);
  }

  private async withProviderFallback<T>(
    side: string,
    vnptCall: () => Promise<T>,
    fptCall: () => Promise<T>,
  ): Promise<T> {
    if (this.provider === 'fpt') {
      return fptCall();
    }
    try {
      return await vnptCall();
    } catch (err) {
      const msg = String((err as Error)?.message ?? err);
      if (this.isAuthFailure(msg)) {
        this.logger.warn(
          `VNPT OCR ${side} auth lỗi → fallback FPT.AI: ${msg}`,
        );
        try {
          return await fptCall();
        } catch (fptErr) {
          throw err; // giữ lỗi VNPT gốc (hướng dẫn refresh token) nếu FPT cũng fail
        }
      }
      throw err;
    }
  }

  private isAuthFailure(msg: string): boolean {
    const lower = msg.toLowerCase();
    return (
      lower.includes('invalid_token') ||
      lower.includes('token hết hạn') ||
      lower.includes('unauthorized') ||
      lower.includes('401')
    );
  }

  private async enrichWithQr(
    file: Express.Multer.File,
    ocr: IdCardFrontOcr,
  ): Promise<IdCardFrontOcr> {
    const missing =
      !ocr.dob?.trim() || !ocr.home?.trim() || !ocr.address?.trim();
    try {
      const qr = await decodeCccdQrFromImage(file.buffer);
      if (!qr) {
        if (missing) {
          this.logger.warn(
            'OCR thiếu ngày sinh/quê/địa chỉ và không đọc được QR — nhập tay nếu cần.',
          );
        }
        return ocr;
      }
      if (qr.idNumber && qr.idNumber !== ocr.idNumber) {
        this.logger.warn(
          `QR CCCD (${qr.idNumber}) khác OCR (${ocr.idNumber}) — ưu tiên OCR.`,
        );
      }
      if (missing) {
        this.logger.log(
          `Bổ sung OCR từ QR (dob=${!!qr.dob}, home=${!!qr.home}, addr=${!!qr.address})`,
        );
      }
      return mergeOcrWithQr(ocr, qr);
    } catch (e) {
      this.logger.warn(`Giải mã QR CCCD lỗi: ${(e as Error).message}`);
      return ocr;
    }
  }
}
