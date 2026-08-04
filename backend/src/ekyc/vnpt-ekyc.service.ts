import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError } from 'axios';
import { createPublicKey, publicEncrypt, constants, randomUUID } from 'crypto';
import FormData = require('form-data');
import {
  IdCardBackOcr,
  IdCardFrontOcr,
} from './fpt-ai.service';

/**
 * VNPT eKYC REST OCR (api.idg.vnpt.vn)
 *
 * Flow:
 *  1) POST /file-service/v1/addFile  → hash
 *  2) RSA-PKCS1 encrypt challenge bằng TOKEN_KEY → body.token
 *  3) POST /ai/v1/ocr/id  { img_front|img_back, token, type, client_session }
 */
@Injectable()
export class VnptEkycService {
  private readonly logger = new Logger(VnptEkycService.name);
  private readonly baseUrl: string;
  private readonly tokenId: string;
  private readonly tokenKey: string;
  private readonly accessToken: string;
  /** Mã loại giấy tờ VNPT (thường -1 CMND/CCCD, 9 CCCD chip). */
  private readonly docType: string;
  /** Hash mặt trước gần nhất — VNPT OCR mặt sau thường cần kèm img_front. */
  private lastFrontHash: { hash: string; at: number } | null = null;

  constructor(private readonly config: ConfigService) {
    this.baseUrl = this.config
      .get<string>('VNPT_EKYC_BASE_URL', 'https://api.idg.vnpt.vn')
      .replace(/\/$/, '');
    this.tokenId = this.config.get<string>('VNPT_TOKEN_ID', '').trim();
    this.tokenKey = this.config.get<string>('VNPT_TOKEN_KEY', '').trim();
    this.accessToken = this.config
      .get<string>('VNPT_ACCESS_TOKEN', '')
      .trim()
      .replace(/^Bearer\s+/i, '');
    this.docType = this.config.get<string>('VNPT_DOC_TYPE', '-1').trim();

    if (!this.isConfigured()) {
      this.logger.warn(
        'VNPT eKYC chưa đủ VNPT_TOKEN_ID / VNPT_TOKEN_KEY / VNPT_ACCESS_TOKEN.',
      );
    } else {
      this.logger.log('VNPT eKYC OCR sẵn sàng (api.idg.vnpt.vn).');
    }
  }

  isConfigured(): boolean {
    return !!(this.tokenId && this.tokenKey && this.accessToken);
  }

  async scanIdCardFront(file: Express.Multer.File): Promise<IdCardFrontOcr> {
    this.assertConfigured();
    const hash = await this.uploadFile(file, 'cccd_front');
    this.lastFrontHash = { hash, at: Date.now() };
    const raw = await this.callOcr({ img_front: hash });
    return this.mapFront(raw);
  }

  async scanIdCardBack(file: Express.Multer.File): Promise<IdCardBackOcr> {
    this.assertConfigured();
    const backHash = await this.uploadFile(file, 'cccd_back');

    // VNPT /ai/v1/ocr/id thường bắt buộc có img_front; gửi kèm hash mặt trước
    // nếu vừa quét, không thì gửi ảnh mặt sau vào cả hai field.
    const frontHash =
      this.lastFrontHash && Date.now() - this.lastFrontHash.at < 30 * 60 * 1000
        ? this.lastFrontHash.hash
        : backHash;

    let raw: Record<string, any>;
    try {
      raw = await this.callOcr({
        img_front: frontHash,
        img_back: backHash,
      });
    } catch (firstErr) {
      // Fallback: một số gói chỉ nhận diện mặt sau qua img_front.
      this.logger.warn(
        `OCR img_back thất bại, thử img_front=back: ${(firstErr as Error).message}`,
      );
      raw = await this.callOcr({ img_front: backHash });
    }
    return this.mapBack(raw);
  }

  private assertConfigured(): void {
    if (!this.isConfigured()) {
      throw new ServiceUnavailableException(
        'Chưa cấu hình VNPT eKYC (VNPT_TOKEN_ID / VNPT_TOKEN_KEY / VNPT_ACCESS_TOKEN).',
      );
    }
  }

  private authHeaders(): Record<string, string> {
    return {
      Authorization: `Bearer ${this.accessToken}`,
      'Token-id': this.tokenId,
      'Token-key': this.tokenKey,
      'Accept-Language': 'vi',
    };
  }

  private encryptChallenge(challenge: string): string {
    const key = createPublicKey({
      key: Buffer.from(this.tokenKey, 'base64'),
      format: 'der',
      type: 'spki',
    });
    return publicEncrypt(
      { key, padding: constants.RSA_PKCS1_PADDING },
      Buffer.from(challenge, 'utf8'),
    ).toString('base64');
  }

  private async uploadFile(
    file: Express.Multer.File,
    title: string,
  ): Promise<string> {
    if (!file?.buffer?.length) {
      throw new BadRequestException('Thiếu ảnh CCCD để upload VNPT.');
    }
    const form = new FormData();
    form.append('file', file.buffer, {
      filename: file.originalname || `${title}.jpg`,
      contentType: file.mimetype || 'image/jpeg',
    });
    form.append('title', title);
    form.append('description', title);

    try {
      const res = await axios.post(
        `${this.baseUrl}/file-service/v1/addFile`,
        form,
        {
          headers: { ...this.authHeaders(), ...form.getHeaders() },
          maxBodyLength: Infinity,
          timeout: 45_000,
        },
      );
      const hash = res.data?.object?.hash as string | undefined;
      if (!hash) {
        throw new BadRequestException(
          `VNPT upload thất bại: ${res.data?.message ?? 'không có hash'}`,
        );
      }
      return hash;
    } catch (err) {
      this.handleAxiosError(err, 'Upload');
    }
  }

  private async callOcr(imgs: {
    img_front?: string;
    img_back?: string;
  }): Promise<Record<string, any>> {
    const clientSession = randomUUID();
    const token = this.encryptChallenge(clientSession);
    const body = {
      ...imgs,
      token,
      type: this.docType,
      client_session: clientSession,
    };

    try {
      const res = await axios.post(`${this.baseUrl}/ai/v1/ocr/id`, body, {
        headers: {
          ...this.authHeaders(),
          'Content-Type': 'application/json',
        },
        timeout: 60_000,
      });

      const payload = this.unwrapVnptPayload(res.data);
      if (payload.statusCode && String(payload.statusCode) !== '200') {
        const errors = Array.isArray(payload.errors)
          ? payload.errors.join('; ')
          : payload.message || payload.error || 'OCR thất bại';
        throw new BadRequestException(`VNPT OCR lỗi: ${errors}`);
      }
      return payload;
    } catch (err) {
      if (err instanceof BadRequestException) throw err;
      this.handleAxiosError(err, 'OCR');
    }
  }

  /** VNPT thường bọc kết quả trong dataBase64. */
  private unwrapVnptPayload(data: any): Record<string, any> {
    if (data?.dataBase64) {
      try {
        return JSON.parse(
          Buffer.from(String(data.dataBase64), 'base64').toString('utf8'),
        );
      } catch {
        return data;
      }
    }
    return data?.object ?? data ?? {};
  }

  /** Lấy chuỗi từ field phẳng hoặc { value / text / data }; tìm sâu trong object lồng. */
  private pickStr(obj: Record<string, any>, ...keys: string[]): string {
    for (const key of keys) {
      if (!(key in obj) || obj[key] == null) continue;
      const v = obj[key];
      if (typeof v === 'string' || typeof v === 'number') {
        const s = String(v).trim();
        if (s && !/^n\/?a$/i.test(s) && s !== '-' && s !== 'null') return s;
      }
      if (typeof v === 'object') {
        const nested = v.value ?? v.text ?? v.data ?? v.label;
        if (nested != null) {
          const s = String(nested).trim();
          if (s && !/^n\/?a$/i.test(s) && s !== '-') return s;
        }
      }
    }
    return '';
  }

  /** VNPT hay đặt quê/địa chỉ ở object con với tên khác — tìm theo tên field (không phân biệt hoa thường). */
  private deepPick(root: unknown, keys: string[]): string {
    const want = new Set(keys.map((k) => k.toLowerCase()));
    const visit = (node: unknown, depth: number): string => {
      if (node == null || depth > 7) return '';
      if (typeof node !== 'object') return '';
      if (Array.isArray(node)) {
        for (const item of node) {
          const s = visit(item, depth + 1);
          if (s) return s;
        }
        return '';
      }
      const rec = node as Record<string, unknown>;
      for (const [k, v] of Object.entries(rec)) {
        if (want.has(k.toLowerCase())) {
          const s = this.pickStr({ [k]: v }, k);
          if (s.length >= 2) return s;
        }
      }
      for (const v of Object.values(rec)) {
        const s = visit(v, depth + 1);
        if (s) return s;
      }
      return '';
    };
    return visit(root, 0);
  }

  private mapFront(raw: Record<string, any>): IdCardFrontOcr {
    const root = (raw.object ?? raw.data ?? raw.ocr ?? raw) as Record<
      string,
      any
    >;
    const obj = (root.card_info ??
      root.data ??
      root.result ??
      root) as Record<string, any>;

    const idNumber =
      this.pickStr(
        obj,
        'id',
        'id_number',
        'idNumber',
        'so_cmt',
        'so_cccd',
        'card_number',
        'citizen_id',
      ) || this.deepPick(raw, ['id', 'id_number', 'so_cccd', 'so_cmt']);
    const fullName =
      this.pickStr(obj, 'name', 'full_name', 'fullName', 'ho_ten', 'hoten') ||
      this.deepPick(raw, ['name', 'full_name', 'ho_ten']);

    if (!idNumber || !fullName) {
      throw new BadRequestException(
        'VNPT không đọc được số CCCD / họ tên. Hãy chụp rõ nét, đủ 4 góc, đúng mặt trước.',
      );
    }

    const homeKeys = [
      'hometown',
      'home',
      'que_quan',
      'origin',
      'place_of_origin',
      'poe',
      'origin_location',
      'originLocation',
      'home_town',
      'quequan',
    ];
    const addressKeys = [
      'address',
      'residence',
      'permanent_address',
      'thuong_tru',
      'noi_thuong_tru',
      'resident',
      'place_of_residence',
      'recent_location',
      'recentLocation',
      'resident_address',
      'dia_chi',
      'diachi',
      'noi_o',
    ];

    const home =
      this.pickStr(obj, ...homeKeys) || this.deepPick(raw, homeKeys);
    const address =
      this.pickStr(obj, ...addressKeys) || this.deepPick(raw, addressKeys);

    if (!home || !address) {
      const keys = Object.keys(obj || {}).join(', ');
      this.logger.warn(
        `VNPT OCR thiếu quê/địa chỉ (home=${!!home}, addr=${!!address}). Keys top: [${keys}]`,
      );
    }

    return {
      idNumber,
      fullName,
      dob:
        this.pickStr(
          obj,
          'birthday',
          'dob',
          'birth_day',
          'birthDay',
          'ngay_sinh',
          'date_of_birth',
        ) || this.deepPick(raw, ['birthday', 'dob', 'ngay_sinh', 'birth_day']),
      sex:
        this.pickStr(obj, 'sex', 'gender', 'gioi_tinh') ||
        this.deepPick(raw, ['sex', 'gender', 'gioi_tinh']),
      nationality:
        this.pickStr(obj, 'nationality', 'quoc_tich') ||
        this.deepPick(raw, ['nationality', 'quoc_tich']) ||
        'Việt Nam',
      home,
      address,
      doe:
        this.pickStr(obj, 'expiry', 'doe', 'ngay_het_han', 'valid_to') ||
        this.deepPick(raw, ['expiry', 'doe', 'ngay_het_han']),
      type: this.pickStr(obj, 'type', 'type_id') || 'cccd',
      rawResponse: raw,
    };
  }

  private mapBack(raw: Record<string, any>): IdCardBackOcr {
    const obj = (raw.object ?? raw.data ?? raw.ocr ?? raw) as Record<
      string,
      any
    >;
    const features = String(
      obj.features ??
        obj.characteristics ??
        obj.dac_diem ??
        obj.special_marks ??
        '',
    ).trim();
    const issueDate = String(
      obj.issue_date ??
        obj.issueDate ??
        obj.ngay_cap ??
        obj.issue_date_cover ??
        '',
    ).trim();
    const issueLoc = String(
      obj.issue_place ??
        obj.issue_loc ??
        obj.noi_cap ??
        obj.issued_at ??
        '',
    ).trim();
    const mrz = String(obj.mrz ?? obj.mrz_text ?? obj.MRZ ?? '').trim();

    // Một số response VNPT gom thông tin trong mảng warning/errors nhưng vẫn có object con.
    if (!(features || issueDate || issueLoc || mrz)) {
      // Cho phép tiếp tục với MRZ thô nếu parse được vài dòng.
      throw new BadRequestException(
        'VNPT không đọc được mặt sau CCCD (ngày cấp / nơi cấp / MRZ). Hãy chụp rõ, đủ 4 góc, đúng mặt sau.',
      );
    }

    return {
      features,
      issueDate: issueDate || (mrz ? 'Xem MRZ' : ''),
      issueLoc: issueLoc || (mrz ? 'Xem MRZ' : ''),
      mrzText: mrz || undefined,
      rawResponse: raw,
    };
  }

  private extractVnptErrorDetail(data: any): string | null {
    if (!data) return null;
    if (data.dataBase64) {
      try {
        const inner = JSON.parse(
          Buffer.from(String(data.dataBase64), 'base64').toString('utf8'),
        );
        if (Array.isArray(inner.errors) && inner.errors.length) {
          return inner.errors.join('; ');
        }
        if (inner.message) return String(inner.message);
        if (inner.error) return String(inner.error);
        if (Array.isArray(inner.messageFields) && inner.messageFields.length) {
          return inner.messageFields
            .map((f: any) => `${f.fieldName}: ${f.message}`)
            .join('; ');
        }
      } catch {
        /* ignore */
      }
    }
    if (Array.isArray(data.messageFields) && data.messageFields.length) {
      return data.messageFields
        .map((f: any) => `${f.fieldName}: ${f.message}`)
        .join('; ');
    }
    if (Array.isArray(data.errors) && data.errors.length) {
      return data.errors.join('; ');
    }
    if (data.message) return String(data.message);
    if (data.error) return String(data.error);
    return null;
  }

  private handleAxiosError(err: unknown, label: string): never {
    if (axios.isAxiosError(err)) {
      const ax = err as AxiosError<any>;
      const detail =
        this.extractVnptErrorDetail(ax.response?.data) || ax.message;
      this.logger.error(`VNPT ${label} HTTP ${ax.response?.status}: ${detail}`);
      const lower = String(detail).toLowerCase();
      if (
        lower.includes('invalid_token') ||
        lower.includes('unauthorized') ||
        ax.response?.status === 401
      ) {
        throw new BadRequestException(
          `VNPT ${label} thất bại: token hết hạn hoặc không hợp lệ (invalid_token). ` +
            'Vào https://ekyc.vnpt.vn lấy lại ACCESS_TOKEN mới, cập nhật VNPT_ACCESS_TOKEN trong backend/.env, rồi restart backend.',
        );
      }
      throw new BadRequestException(`VNPT ${label} thất bại: ${detail}`);
    }
    this.logger.error(`VNPT ${label}: ${(err as Error).message}`);
    throw new BadRequestException(`VNPT ${label} lỗi không xác định`);
  }
}
