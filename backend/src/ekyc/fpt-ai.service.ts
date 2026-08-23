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
    this.apiKey = this.config.get<string>('FPT_AI_API_KEY', '').trim();
    this.ocrUrl = this.config.get<string>(
      'FPT_AI_OCR_URL',
      'https://api.fpt.ai/vision/idr/vnm',
    );
    this.faceMatchUrl = this.config.get<string>(
      'FPT_AI_FACE_MATCH_URL',
      'https://api.fpt.ai/dmp/checkface/v1/',
    );

    if (!this.hasRealApiKey()) {
      this.logger.warn(
        'FPT_AI_API_KEY chưa cấu hình (đang trống hoặc còn giá trị mẫu YOUR_FPT_AI_API_KEY). ' +
          'OCR CCCD sẽ thất bại — lấy key tại https://console.fpt.ai rồi điền vào backend/.env',
      );
    }
  }

  hasRealApiKey(): boolean {
    if (!this.apiKey) return false;
    const lower = this.apiKey.toLowerCase();
    return !(
      lower.includes('your_fpt') ||
      lower === 'changeme' ||
      lower.includes('xxx') ||
      lower === 'api_key_here'
    );
  }

  private assertApiKeyConfigured(): void {
    if (!this.hasRealApiKey()) {
      throw new BadRequestException(
        'Chưa cấu hình FPT.AI API key — không quét được ảnh CCCD. ' +
          'Mở backend/.env, điền FPT_AI_API_KEY (lấy tại https://console.fpt.ai), rồi khởi động lại server.',
      );
    }
  }

  /** Map mã lỗi FPT OCR sang tiếng Việt dễ hiểu khi demo. */
  private ocrErrorMessage(code: number, fallback?: string): string {
    const map: Record<number, string> = {
      1: 'Request OCR không hợp lệ (thiếu ảnh hoặc sai tham số).',
      2: 'Ảnh thiếu góc CCCD — hãy chụp đủ 4 góc, nằm ngang, không bị cắt.',
      3: 'Không nhận diện được CCCD trong ảnh — chụp rõ hơn, đủ sáng, tránh lóa/mờ.',
      7: 'File không phải ảnh hợp lệ.',
      8: 'Ảnh bị lỗi hoặc định dạng không hỗ trợ — thử chụp lại (JPEG).',
    };
    return map[code] ?? fallback ?? 'không nhận diện được ảnh';
  }

  /**
   * Quét MẶT TRƯỚC CCCD/CMND, trả về số CCCD, họ tên, ngày sinh, địa chỉ...
   *
   * FPT.AI trả về field `type` để phân biệt mặt: front/chip_front/new_front
   * (mặt trước) vs back/chip_back/new_back (mặt sau). Ta CHẶN nếu người dùng
   * chụp nhầm mặt sau, và yêu cầu phải đọc được số CCCD + họ tên.
   */
  async scanIdCardFront(file: Express.Multer.File): Promise<IdCardFrontOcr> {
    const data = await this.callOcr(file);
    const type = String(data.type ?? '').toLowerCase();

    if (type.includes('back')) {
      throw new BadRequestException(
        'Bạn đang chụp MẶT SAU. Vui lòng chụp MẶT TRƯỚC CCCD (mặt có ảnh chân dung và số CCCD).',
      );
    }

    const idNumber = String(data.id ?? '').trim();
    const fullName = String(data.name ?? '').trim();
    // Mặt trước hợp lệ phải đọc được số CCCD và họ tên.
    if (!idNumber || !fullName) {
      throw new BadRequestException(
        'Không đọc được số CCCD / họ tên ở mặt trước. Hãy chụp rõ nét, đủ 4 góc, tránh lóa sáng và đúng MẶT TRƯỚC.',
      );
    }

    return {
      idNumber,
      fullName,
      dob: this.cleanOcrField(data.dob),
      sex: this.cleanOcrField(data.sex),
      nationality: this.cleanOcrField(data.nationality),
      home: this.cleanOcrField(
        data.home ??
          data.hometown ??
          data.poe ??
          data.origin_location ??
          data.que_quan,
      ),
      address: this.cleanOcrField(
        data.address ??
          data.residence ??
          data.permanent_address ??
          data.recent_location ??
          data.resident ??
          data.noi_thuong_tru,
      ),
      doe: this.cleanOcrField(data.doe ?? data.expiry),
      type: String(data.type ?? ''),
      rawResponse: data,
    };
  }

  /** FPT hay trả "N/A" / "null" khi không chắc — coi như trống. */
  private cleanOcrField(value: unknown): string {
    const s = String(value ?? '').trim();
    if (!s) return '';
    const lower = s.toLowerCase();
    if (lower === 'n/a' || lower === 'na' || lower === 'null' || lower === '-') {
      return '';
    }
    return s;
  }

  /**
   * Quét MẶT SAU CCCD/CMND, trả về đặc điểm nhận dạng + ngày cấp + nơi cấp.
   * CHẶN nếu người dùng chụp nhầm mặt trước.
   */
  async scanIdCardBack(file: Express.Multer.File): Promise<IdCardBackOcr> {
    const data = await this.callOcr(file);
    const type = String(data.type ?? '').toLowerCase();

    // Mặt trước có số CCCD (id) — nếu thấy id/name mà không có dữ liệu mặt sau
    // thì người dùng đang chụp nhầm mặt trước.
    const looksLikeFront =
      type.includes('front') ||
      (!!String(data.id ?? '').trim() && !!String(data.name ?? '').trim());

    const features = String(data.features ?? '').trim();
    const issueDate = String(data.issue_date ?? '').trim();
    const issueLoc = String(data.issue_loc ?? '').trim();
    const mrz = data.mrz ? String(data.mrz) : '';
    const hasBackData = !!(features || issueDate || issueLoc || mrz);

    if (looksLikeFront && !hasBackData) {
      throw new BadRequestException(
        'Bạn đang chụp MẶT TRƯỚC. Vui lòng chụp MẶT SAU CCCD (mặt có ngày cấp, nơi cấp, đặc điểm nhận dạng).',
      );
    }

    if (!hasBackData) {
      throw new BadRequestException(
        'Không đọc được thông tin mặt sau (ngày cấp / nơi cấp). Hãy chụp rõ nét, đúng MẶT SAU CCCD.',
      );
    }

    return {
      features,
      issueDate,
      issueLoc,
      mrzText: mrz || undefined,
      rawResponse: data,
    };
  }

  /**
   * So khớp khuôn mặt: ảnh chân dung trên CCCD vs selfie đang xác thực.
   * FPT trả `{ code, data: { isMatch, similarity } }` — similarity là % (0..100),
   * isMatch theo ngưỡng ~80% của FPT.
   */
  async matchFace(
    idCardImage: Express.Multer.File,
    selfieImage: Express.Multer.File,
  ): Promise<FaceMatchResult> {
    this.assertApiKeyConfigured();
    const form = new FormData();
    form.append('file[]', idCardImage.buffer, {
      filename: 'id.jpg',
      contentType: 'image/jpeg',
    });
    form.append('file[]', selfieImage.buffer, {
      filename: 'selfie.jpg',
      contentType: 'image/jpeg',
    });

    try {
      const res = await axios.post<Record<string, unknown>>(
        this.faceMatchUrl,
        form,
        {
          headers: {
            ...form.getHeaders(),
            'api-key': this.apiKey,
            api_key: this.apiKey,
          },
          maxBodyLength: Infinity,
          timeout: 30_000,
        },
      );

      const body = res.data ?? {};
      const code = String(body.code ?? '');
      if (code && code !== '200') {
        throw new BadRequestException(
          this.faceMatchErrorMessage(code, body),
        );
      }

      const data =
        body.data && typeof body.data === 'object' && !Array.isArray(body.data)
          ? (body.data as Record<string, unknown>)
          : body;

      const rawSim = Number(
        data.similarity ?? data.Similarity ?? body.similarity ?? 0,
      );
      const similarity = this.normalizeSimilarity(rawSim);
      const fptSaysMatch =
        data.isMatch === true ||
        String(data.isMatch ?? '') === 'true' ||
        body.isMatch === true ||
        String(body.isMatch ?? '') === 'true';

      const threshold = Number(
        this.config.get<string>('EKYC_FACE_MATCH_THRESHOLD', '0.72'),
      );
      const isMatch = fptSaysMatch || similarity >= threshold;

      this.logger.log(
        `FPT Face Match: isMatch=${isMatch} fptFlag=${fptSaysMatch} ` +
          `similarity=${(similarity * 100).toFixed(1)}% raw=${rawSim}`,
      );

      return {
        isMatch,
        similarity,
        message: isMatch
          ? `Khuôn mặt khớp ảnh CCCD (${(similarity * 100).toFixed(0)}%).`
          : `Khuôn mặt không khớp ảnh trên CCCD (độ tương đồng ${(similarity * 100).toFixed(0)}%, cần ≥ ${(threshold * 100).toFixed(0)}%).`,
        rawResponse: body,
      };
    } catch (err) {
      this.handleAxiosError(err, 'Face Match');
    }
  }

  /** FPT similarity thường là 0..100; nội bộ hệ thống dùng 0..1. */
  private normalizeSimilarity(raw: number): number {
    if (!Number.isFinite(raw) || raw < 0) return 0;
    if (raw > 1) return Math.min(raw / 100, 1);
    return raw;
  }

  private faceMatchErrorMessage(
    code: string,
    body: Record<string, unknown>,
  ): string {
    switch (code) {
      case '407':
        return 'FPT.AI không nhận diện được khuôn mặt trên ảnh CCCD hoặc ảnh selfie. Chụp rõ mặt, đủ sáng.';
      case '408':
        return 'FPT.AI chỉ nhận ảnh JPG/JPEG. Hãy chụp lại Face ID.';
      case '409':
        return 'FPT.AI Face Match cần đúng 2 ảnh (CCCD + selfie).';
      default:
        return `FPT.AI Face Match lỗi (${code}): ${body.message ?? 'không rõ'}`;
    }
  }

  /** Gọi chung cho OCR mặt trước & mặt sau */
  private async callOcr(
    file: Express.Multer.File,
  ): Promise<Record<string, any>> {
    this.assertApiKeyConfigured();

    if (!file || !file.buffer || file.buffer.length === 0) {
      throw new BadRequestException(
        'Thiếu ảnh CCCD/CMND — hãy chụp hoặc chọn lại ảnh rồi nhấn Quét bằng FPT.AI.',
      );
    }

    const form = new FormData();
    const filename = this.normalizeUploadName(file);
    form.append('image', file.buffer, {
      filename,
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
        timeout: 45_000,
      });

      const body = res.data;
      if (body.errorCode !== 0 || !body.data || body.data.length === 0) {
        throw new BadRequestException(
          `FPT.AI OCR lỗi: ${this.ocrErrorMessage(body.errorCode, body.errorMessage)}`,
        );
      }

      return body.data[0];
    } catch (err) {
      this.handleAxiosError(err, 'OCR');
    }
  }

  private normalizeUploadName(file: Express.Multer.File): string {
    const raw = (file.originalname || 'idcard.jpg').toLowerCase();
    if (raw.endsWith('.png')) return 'idcard.png';
    if (raw.endsWith('.webp')) return 'idcard.webp';
    if (raw.endsWith('.heic') || raw.endsWith('.heif')) {
      // FPT thường không đọc HEIC tốt — vẫn gửi nhưng đặt tên .jpg sau khi client ép JPEG.
      return 'idcard.jpg';
    }
    return 'idcard.jpg';
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
