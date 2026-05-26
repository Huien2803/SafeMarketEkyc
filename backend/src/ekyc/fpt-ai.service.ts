import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError } from 'axios';
import FormData = require('form-data');

/**
 * Kết quả OCR mặt trước CCCD/CMND từ FPT.AI
 * (đã chuẩn hóa lại field name cho dễ dùng phía Flutter)
 */
export interface IdCardFrontOcr {
  idNumber: string;
  fullName: string;
  dob: string; // dd/MM/yyyy
  sex: string;
  nationality: string;
  home: string;
  address: string;
  doe: string; // ngày hết hạn dd/MM/yyyy
  type: string; // 'cccd' | 'cmnd' | 'chip_front'
  rawResponse: Record<string, unknown>;
}

export interface IdCardBackOcr {
  features: string; // đặc điểm nhận dạng
  issueDate: string; // dd/MM/yyyy
  issueLoc: string; // nơi cấp
  mrzText?: string;
  rawResponse: Record<string, unknown>;
}

export interface FaceMatchResult {
  isMatch: boolean;
  similarity: number; // 0..1
  message: string;
  rawResponse: Record<string, unknown>;
}

/**
 * Service gọi FPT.AI Vision API
 *   - OCR CCCD/CMND  (https://api.fpt.ai/vision/idr/vnm)
 *   - Face Matching  (https://api.fpt.ai/dmp/checkface/v1/)
 *
 * Tài liệu chính thức: https://docs.fpt.ai/
 */
@Injectable()
export class FptAiService {
  private readonly logger = new Logger(FptAiService.name);
  private readonly apiKey: string;
  private readonly ocrUrl: string;
  private readonly faceMatchUrl: string;

  constructor(private readonly config: ConfigService) {
    this.apiKey = this.config.get<string>('FPT_AI_API_KEY', '');
    this.ocrUrl = this.config.get<string>(
      'FPT_AI_OCR_URL',
      'https://api.fpt.ai/vision/idr/vnm',
    );
    this.faceMatchUrl = this.config.get<string>(
      'FPT_AI_FACE_MATCH_URL',
      'https://api.fpt.ai/dmp/checkface/v1/',
    );

    if (!this.apiKey) {
      this.logger.warn(
        'FPT_AI_API_KEY trống - các endpoint eKYC sẽ trả về lỗi 500.',
      );
    }
  }

  /**
   * Quét MẶT TRƯỚC CCCD/CMND, trả về số CCCD, họ tên, ngày sinh, địa chỉ...
   */
  async scanIdCardFront(file: Express.Multer.File): Promise<IdCardFrontOcr> {
    const data = await this.callOcr(file);

    return {
      idNumber: String(data.id ?? ''),
      fullName: String(data.name ?? ''),
      dob: String(data.dob ?? ''),
      sex: String(data.sex ?? ''),
      nationality: String(data.nationality ?? ''),
      home: String(data.home ?? ''),
      address: String(data.address ?? ''),
      doe: String(data.doe ?? ''),
      type: String(data.type ?? ''),
      rawResponse: data,
    };
  }

  /**
   * Quét MẶT SAU CCCD/CMND, trả về đặc điểm nhận dạng + ngày cấp + nơi cấp.
   */
  async scanIdCardBack(file: Express.Multer.File): Promise<IdCardBackOcr> {
    const data = await this.callOcr(file);

    return {
      features: String(data.features ?? ''),
      issueDate: String(data.issue_date ?? ''),
      issueLoc: String(data.issue_loc ?? ''),
      mrzText: data.mrz ? String(data.mrz) : undefined,
      rawResponse: data,
    };
  }

  /**
   * So khớp khuôn mặt giữa: ảnh chân dung trên CCCD + ảnh selfie chụp trực tiếp.
   * FPT trả về `similarity` từ 0..1; > 0.8 thường coi là cùng người.
   */
  async matchFace(
    idCardImage: Express.Multer.File,
    selfieImage: Express.Multer.File,
  ): Promise<FaceMatchResult> {
    const form = new FormData();
    form.append('file[]', idCardImage.buffer, { filename: 'id.jpg' });
    form.append('file[]', selfieImage.buffer, { filename: 'selfie.jpg' });

    try {
      const res = await axios.post<Record<string, unknown>>(
        this.faceMatchUrl,
        form,
        {
          headers: {
            ...form.getHeaders(),
            'api-key': this.apiKey,
          },
          maxBodyLength: Infinity,
          timeout: 30_000,
        },
      );

      const body = res.data ?? {};
      const code = String(body.code ?? '');
      if (code !== '200') {
        throw new BadRequestException(
          `FPT.AI Face Match lỗi: ${body.message ?? 'không rõ'}`,
        );
      }

      const similarity = Number(body.similarity ?? 0);
      const isMatch = String(body.isMatch ?? 'false') === 'true' || similarity >= 0.8;

      return {
        isMatch,
        similarity,
        message: String(body.message ?? ''),
        rawResponse: body,
      };
    } catch (err) {
      this.handleAxiosError(err, 'Face Match');
    }
  }

  /** Gọi chung cho OCR mặt trước & mặt sau */
  private async callOcr(
    file: Express.Multer.File,
  ): Promise<Record<string, any>> {
    if (!file || !file.buffer) {
      throw new BadRequestException('Thiếu ảnh CCCD/CMND');
    }

    const form = new FormData();
    form.append('image', file.buffer, {
      filename: file.originalname || 'idcard.jpg',
      contentType: file.mimetype || 'image/jpeg',
    });

    try {
      const res = await axios.post<{
        errorCode: number;
        errorMessage?: string;
        data?: Array<Record<string, any>>;
      }>(this.ocrUrl, form, {
        headers: {
          ...form.getHeaders(),
          'api-key': this.apiKey,
        },
        maxBodyLength: Infinity,
        timeout: 30_000,
      });

      const body = res.data;
      if (body.errorCode !== 0 || !body.data || body.data.length === 0) {
        throw new BadRequestException(
          `FPT.AI OCR lỗi: ${body.errorMessage ?? 'không nhận diện được ảnh'}`,
        );
      }

      return body.data[0];
    } catch (err) {
      this.handleAxiosError(err, 'OCR');
    }
  }

  private handleAxiosError(err: unknown, label: string): never {
    if (err instanceof BadRequestException) throw err;
    if (axios.isAxiosError(err)) {
      const ax = err as AxiosError<any>;
      this.logger.error(
        `${label} FPT.AI HTTP ${ax.response?.status} - ${JSON.stringify(ax.response?.data)}`,
      );
      throw new BadRequestException(
        `FPT.AI ${label} thất bại: ${ax.response?.data?.message ?? ax.message}`,
      );
    }
    this.logger.error(`${label} lỗi không xác định: ${(err as Error).message}`);
    throw new BadRequestException(`FPT.AI ${label} lỗi không xác định`);
  }
}
