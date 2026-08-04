import { randomBytes, createHmac, timingSafeEqual } from 'crypto';
import { existsSync, mkdirSync, writeFileSync, readFileSync } from 'fs';
import { join } from 'path';
import {
  BadRequestException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { IdCardBackOcr, IdCardFrontOcr } from './fpt-ai.service';

export type EkycFrontSnapshot = IdCardFrontOcr & { filePath: string; url: string };
export type EkycBackSnapshot = IdCardBackOcr & { filePath: string; url: string };

export interface EkycSessionState {
  sessionId: string;
  userId: number;
  createdAt: number;
  expiresAt: number;
  front?: EkycFrontSnapshot;
  back?: EkycBackSnapshot;
  liveness?: {
    tokenHash: string;
    tokenPreview: string;
    recognitionPoints: number;
    selfiePath: string;
    selfieUrl: string;
    at: number;
  };
  faceMatch?: {
    similarity: number;
    isMatch: boolean;
    mode: 'fpt' | 'attested';
    at: number;
  };
  consumed: boolean;
}

/**
 * Phiên eKYC phía server (kiểu ngân hàng / VNeID):
 * - Gắn từng bước (front → back → liveness → face-match) vào 1 sessionId
 * - Khóa số CCCD / họ tên từ OCR (client không tự bịa khi submit)
 * - Token liveness do server phát hành, one-time, có TTL
 */
@Injectable()
export class EkycSessionService {
  private readonly logger = new Logger(EkycSessionService.name);
  private readonly sessions = new Map<string, EkycSessionState>();
  /** userId -> sessionId hiện tại */
  private readonly byUser = new Map<number, string>();
  private readonly secret: string;
  private readonly ttlMs: number;
  private readonly uploadRoot: string;

  constructor(private readonly config: ConfigService) {
    this.secret =
      this.config.get<string>('EKYC_SESSION_SECRET')?.trim() ||
      this.config.get<string>('JWT_SECRET')?.trim() ||
      'safemarket-ekyc-dev-secret';
    this.ttlMs =
      Number(this.config.get<string>('EKYC_SESSION_TTL_MIN', '30')) * 60_000;
    this.uploadRoot = join(process.cwd(), 'uploads', 'ekyc');
    if (!existsSync(this.uploadRoot)) {
      mkdirSync(this.uploadRoot, { recursive: true });
    }
    // Dọn session hết hạn mỗi 5 phút
    setInterval(() => this.sweep(), 5 * 60_000).unref?.();
  }

  start(userId: number): { sessionId: string; expiresAt: string } {
    const prev = this.byUser.get(userId);
    if (prev) this.sessions.delete(prev);

    const sessionId = randomBytes(16).toString('hex');
    const now = Date.now();
    const state: EkycSessionState = {
      sessionId,
      userId,
      createdAt: now,
      expiresAt: now + this.ttlMs,
      consumed: false,
    };
    this.sessions.set(sessionId, state);
    this.byUser.set(userId, sessionId);
    this.logger.log(`eKYC session ${sessionId} started for user ${userId}`);
    return {
      sessionId,
      expiresAt: new Date(state.expiresAt).toISOString(),
    };
  }

  getForUser(userId: number, sessionId: string): EkycSessionState {
    const s = this.sessions.get(sessionId);
    if (!s || s.userId !== userId) {
      throw new BadRequestException(
        'Phiên xác thực không hợp lệ. Vui lòng bắt đầu lại từ đầu.',
      );
    }
    if (s.consumed) {
      throw new BadRequestException(
        'Phiên xác thực đã hoàn tất. Không thể dùng lại.',
      );
    }
    if (Date.now() > s.expiresAt) {
      this.sessions.delete(sessionId);
      throw new BadRequestException(
        'Phiên xác thực đã hết hạn (30 phút). Vui lòng bắt đầu lại.',
      );
    }
    return s;
  }

  saveFront(
    userId: number,
    sessionId: string,
    ocr: IdCardFrontOcr,
    file: Express.Multer.File,
  ): EkycFrontSnapshot {
    const s = this.getForUser(userId, sessionId);
    this.assertIdNumber(ocr.idNumber);
    this.assertFullName(ocr.fullName);

    const saved = this.saveUpload(userId, sessionId, 'front', file);
    const snap: EkycFrontSnapshot = {
      ...ocr,
      filePath: saved.path,
      url: saved.url,
    };
    s.front = snap;
    // Quay lại bước front → hủy các bước sau
    s.back = undefined;
    s.liveness = undefined;
    s.faceMatch = undefined;
    return snap;
  }

  saveBack(
    userId: number,
    sessionId: string,
    ocr: IdCardBackOcr,
    file: Express.Multer.File,
  ): EkycBackSnapshot {
    const s = this.getForUser(userId, sessionId);
    if (!s.front) {
      throw new BadRequestException(
        'Chưa quét mặt trước CCCD. Vui lòng hoàn tất bước 1 trước.',
      );
    }
    if (!String(ocr.issueDate ?? '').trim() || !String(ocr.issueLoc ?? '').trim()) {
      throw new BadRequestException(
        'Mặt sau chưa đọc đủ ngày cấp / nơi cấp. Chụp lại rõ hơn, đủ 4 góc.',
      );
    }
    const saved = this.saveUpload(userId, sessionId, 'back', file);
    const snap: EkycBackSnapshot = {
      ...ocr,
      filePath: saved.path,
      url: saved.url,
    };
    s.back = snap;
    s.liveness = undefined;
    s.faceMatch = undefined;
    return snap;
  }

  /**
   * Xác nhận liveness: lưu selfie + phát hành token server-side (one-time).
   */
  completeLiveness(
    userId: number,
    sessionId: string,
    file: Express.Multer.File,
    recognitionPoints: number,
  ): { livenessToken: string; recognitionPoints: number } {
    const s = this.getForUser(userId, sessionId);
    if (!s.front || !s.back) {
      throw new BadRequestException(
        'Chưa hoàn tất quét CCCD (mặt trước + mặt sau).',
      );
    }
    const minPoints = Number(
      this.config.get<string>('EKYC_MIN_RECOGNITION_POINTS', '8'),
    );
    if (!Number.isFinite(recognitionPoints) || recognitionPoints < minPoints) {
      throw new BadRequestException(
        `Chưa lấy đủ điểm nhận dạng khuôn mặt (${recognitionPoints}/${minPoints}). ` +
          'Giữ mặt trong khung, đủ sáng, hoàn tất xoay trái/phải.',
      );
    }
    if (!file?.buffer?.length) {
      throw new BadRequestException('Thiếu ảnh selfie từ bước Face ID.');
    }

    const saved = this.saveUpload(userId, sessionId, 'selfie', file);
    const rawToken = `ekyc.${sessionId}.${randomBytes(24).toString('hex')}`;
    const tokenHash = this.hashToken(rawToken);
    s.liveness = {
      tokenHash,
      tokenPreview: rawToken.slice(0, 18) + '…',
      recognitionPoints,
      selfiePath: saved.path,
      selfieUrl: saved.url,
      at: Date.now(),
    };
    s.faceMatch = undefined;
    return { livenessToken: rawToken, recognitionPoints };
  }

  markFaceMatch(
    userId: number,
    sessionId: string,
    result: { similarity: number; isMatch: boolean; mode: 'fpt' | 'attested' },
  ): void {
    const s = this.getForUser(userId, sessionId);
    if (!s.liveness) {
      throw new BadRequestException(
        'Chưa hoàn tất xác minh khuôn mặt sống (Face ID).',
      );
    }
    const threshold = Number(
      this.config.get<string>('EKYC_FACE_MATCH_THRESHOLD', '0.72'),
    );
    if (!result.isMatch || result.similarity < threshold) {
      throw new BadRequestException(
        `Khuôn mặt không khớp ảnh trên CCCD (độ tương đồng ${(result.similarity * 100).toFixed(0)}%, cần ≥ ${(threshold * 100).toFixed(0)}%). ` +
          'Hãy tự chụp lại Face ID, đủ sáng, không đội mũ/khẩu trang.',
      );
    }
    s.faceMatch = { ...result, at: Date.now() };
  }

  /**
   * Kiểm tra đủ điều kiện nộp hồ sơ + xác thực token liveness.
   * Trả về snapshot để lưu DB (không tin payload client cho CCCD).
   */
  assertReadyToSubmit(
    userId: number,
    sessionId: string,
    livenessToken: string,
    supplements?: { dob?: string; address?: string; home?: string },
  ): {
    idNumber: string;
    fullName: string;
    dob: string;
    address: string;
    faceSimilarity: number;
    recognitionPoints: number;
    idFrontUrl: string;
    idBackUrl: string;
    selfieUrl: string;
  } {
    const s = this.getForUser(userId, sessionId);
    if (!s.front || !s.back || !s.liveness || !s.faceMatch) {
      throw new BadRequestException(
        'Chưa hoàn tất đủ các bước: CCCD trước → CCCD sau → Face ID → so khớp khuôn mặt.',
      );
    }
    if (!this.verifyLivenessToken(livenessToken, s.liveness.tokenHash)) {
      throw new BadRequestException(
        'Token xác minh khuôn mặt không hợp lệ hoặc đã hết hạn. Vui lòng quét Face ID lại.',
      );
    }

    const dob =
      this.normalizeDob(supplements?.dob) ||
      this.normalizeDob(s.front.dob) ||
      '';
    if (!dob) {
      throw new BadRequestException(
        'Thiếu ngày sinh. Bổ sung ngày sinh dạng dd/MM/yyyy ở bước mặt trước.',
      );
    }

    const address = (
      supplements?.address?.trim() ||
      s.front.address?.trim() ||
      supplements?.home?.trim() ||
      s.front.home?.trim() ||
      ''
    ).trim();
    if (address.length < 2) {
      throw new BadRequestException(
        'Thiếu địa chỉ thường trú. Bổ sung ở bước mặt trước CCCD.',
      );
    }

    return {
      idNumber: s.front.idNumber,
      fullName: s.front.fullName,
      dob,
      address,
      faceSimilarity: s.faceMatch.similarity,
      recognitionPoints: s.liveness.recognitionPoints,
      idFrontUrl: s.front.url,
      idBackUrl: s.back.url,
      selfieUrl: s.liveness.selfieUrl,
    };
  }

  consume(sessionId: string): void {
    const s = this.sessions.get(sessionId);
    if (s) {
      s.consumed = true;
      s.expiresAt = Date.now(); // hết hạn ngay
    }
  }

  readFileAsMulter(path: string, filename: string): Express.Multer.File {
    const buffer = readFileSync(path);
    return {
      fieldname: 'file',
      originalname: filename,
      encoding: '7bit',
      mimetype: 'image/jpeg',
      size: buffer.length,
      buffer,
      destination: '',
      filename,
      path,
      stream: undefined as any,
    };
  }

  private saveUpload(
    userId: number,
    sessionId: string,
    kind: 'front' | 'back' | 'selfie',
    file: Express.Multer.File,
  ): { path: string; url: string } {
    if (!file?.buffer?.length) {
      throw new BadRequestException('File ảnh trống hoặc không hợp lệ.');
    }
    if (file.size > 8 * 1024 * 1024) {
      throw new BadRequestException('Ảnh quá lớn (tối đa 8MB).');
    }
    const dir = join(this.uploadRoot, String(userId), sessionId);
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
    const ext =
      (file.mimetype || '').includes('png') ||
      (file.originalname || '').toLowerCase().endsWith('.png')
        ? 'png'
        : 'jpg';
    const filename = `${kind}.${ext}`;
    const full = join(dir, filename);
    writeFileSync(full, file.buffer);
    return {
      path: full,
      url: `/uploads/ekyc/${userId}/${sessionId}/${filename}`,
    };
  }

  private hashToken(raw: string): string {
    return createHmac('sha256', this.secret).update(raw).digest('hex');
  }

  private verifyLivenessToken(raw: string, hash: string): boolean {
    try {
      const a = Buffer.from(this.hashToken(raw), 'hex');
      const b = Buffer.from(hash, 'hex');
      if (a.length !== b.length) return false;
      return timingSafeEqual(a, b);
    } catch {
      return false;
    }
  }

  private assertIdNumber(id: string): void {
    const s = String(id ?? '').trim();
    if (!/^\d{9}$|^\d{12}$/.test(s)) {
      throw new BadRequestException(
        'Số CCCD/CMND không hợp lệ (cần 9 hoặc 12 chữ số). Chụp lại mặt trước.',
      );
    }
  }

  private assertFullName(name: string): void {
    const s = String(name ?? '').trim();
    if (s.length < 2) {
      throw new BadRequestException('Họ tên trên CCCD không hợp lệ.');
    }
  }

  private normalizeDob(input?: string): string {
    const s = String(input ?? '').trim();
    if (!s) return '';
    if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
    const m = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (m) {
      return `${m[3]}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}`;
    }
    return '';
  }

  private sweep(): void {
    const now = Date.now();
    for (const [id, s] of this.sessions) {
      if (now > s.expiresAt + 60_000 || s.consumed) {
        this.sessions.delete(id);
        if (this.byUser.get(s.userId) === id) this.byUser.delete(s.userId);
      }
    }
  }
}
