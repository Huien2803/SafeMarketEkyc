import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { createHash, randomBytes } from 'crypto';
import { IsNull, Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from '../entities/user.entity';
import { RefreshToken } from '../entities/refresh-token.entity';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
import { JwtPayload } from './strategies/jwt.strategy';
import { MailService } from '../mail/mail.service';

const BCRYPT_ROUNDS = 10;

interface PendingRegistration {
  dto: RegisterDto;
  otp: string;
  expiresAt: number;
  attempts: number;
  lastSentAt: number;
}

interface PendingReset {
  email: string;
  otp: string;
  expiresAt: number;
  attempts: number;
  lastSentAt: number;
}

const DISPOSABLE_EMAIL_DOMAINS = new Set<string>([
  'mailinator.com',
  'guerrillamail.com',
  'guerrillamail.info',
  '10minutemail.com',
  '10minutemail.net',
  'temp-mail.org',
  'tempmail.com',
  'tempmail.net',
  'throwawaymail.com',
  'yopmail.com',
  'getnada.com',
  'trashmail.com',
  'maildrop.cc',
  'fakeinbox.com',
  'sharklasers.com',
  'dispostable.com',
  'mohmal.com',
  'mailnesia.com',
  'tempmailo.com',
  'emailondeck.com',
  'tempr.email',
  'spam4.me',
  'mintemail.com',
]);

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly OTP_TTL_MS = 5 * 60 * 1000;
  private readonly OTP_MAX_ATTEMPTS = 5;
  private readonly OTP_RESEND_COOLDOWN_MS = 30 * 1000;
  private readonly pending = new Map<string, PendingRegistration>();
  private readonly pendingResets = new Map<string, PendingReset>();

  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(RefreshToken)
    private readonly refreshRepo: Repository<RefreshToken>,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly mailService: MailService,
  ) {}

  private get isProduction(): boolean {
    return this.config.get<string>('NODE_ENV', 'development') === 'production';
  }

  async requestRegistrationOtp(
    dto: RegisterDto,
  ): Promise<{ email: string; expiresInSeconds: number; devOtp?: string }> {
    const email = dto.email.trim().toLowerCase();
    this.assertNotDisposableEmail(email);

    const existing = await this.userRepo.findOne({
      where: [{ email }, { phoneNumber: dto.phoneNumber }],
    });
    if (existing) {
      throw new ConflictException(
        existing.email === email
          ? 'Email đã được sử dụng'
          : 'Số điện thoại đã được sử dụng',
      );
    }

    const now = Date.now();
    const prev = this.pending.get(email);
    if (prev && now - prev.lastSentAt < this.OTP_RESEND_COOLDOWN_MS) {
      const wait = Math.ceil(
        (this.OTP_RESEND_COOLDOWN_MS - (now - prev.lastSentAt)) / 1000,
      );
      throw new BadRequestException(
        `Vui lòng đợi ${wait} giây trước khi gửi lại mã.`,
      );
    }

    const otp = this.generateOtp();
    this.pending.set(email, {
      dto: { ...dto, email },
      otp,
      expiresAt: now + this.OTP_TTL_MS,
      attempts: 0,
      lastSentAt: now,
    });

    const sentViaEmail = await this.mailService.sendRegistrationOtp(email, otp);
    this.cleanupExpired();

    return {
      email,
      expiresInSeconds: Math.floor(this.OTP_TTL_MS / 1000),
      ...(!this.isProduction && !sentViaEmail ? { devOtp: otp } : {}),
    };
  }

  async verifyRegistrationOtp(
    emailRaw: string,
    otp: string,
  ): Promise<AuthResponseDto> {
    const email = emailRaw.trim().toLowerCase();
    const entry = this.pending.get(email);
    if (!entry) {
      throw new BadRequestException(
        'Không tìm thấy yêu cầu đăng ký. Vui lòng đăng ký lại.',
      );
    }
    if (Date.now() > entry.expiresAt) {
      this.pending.delete(email);
      throw new BadRequestException('Mã OTP đã hết hạn. Vui lòng gửi lại mã.');
    }
    if (entry.attempts >= this.OTP_MAX_ATTEMPTS) {
      this.pending.delete(email);
      throw new BadRequestException(
        'Bạn đã nhập sai quá nhiều lần. Vui lòng đăng ký lại.',
      );
    }
    if (entry.otp !== otp.trim()) {
      entry.attempts += 1;
      const left = this.OTP_MAX_ATTEMPTS - entry.attempts;
      throw new BadRequestException(
        `Mã OTP không đúng.${left > 0 ? ` Còn ${left} lần thử.` : ''}`,
      );
    }

    this.pending.delete(email);
    return this.register(entry.dto);
  }

  async requestPasswordResetOtp(
    emailRaw: string,
  ): Promise<{ email: string; expiresInSeconds: number; devOtp?: string }> {
    const email = emailRaw.trim().toLowerCase();
    const expiresInSeconds = Math.floor(this.OTP_TTL_MS / 1000);

    const now = Date.now();
    const prev = this.pendingResets.get(email);
    if (prev && now - prev.lastSentAt < this.OTP_RESEND_COOLDOWN_MS) {
      const wait = Math.ceil(
        (this.OTP_RESEND_COOLDOWN_MS - (now - prev.lastSentAt)) / 1000,
      );
      throw new BadRequestException(
        `Vui lòng đợi ${wait} giây trước khi gửi lại mã.`,
      );
    }

    const user = await this.userRepo.findOne({ where: { email } });
    if (!user) {
      return { email, expiresInSeconds };
    }

    const otp = this.generateOtp();
    this.pendingResets.set(email, {
      email,
      otp,
      expiresAt: now + this.OTP_TTL_MS,
      attempts: 0,
      lastSentAt: now,
    });

    const sentViaEmail = await this.mailService.sendPasswordResetOtp(email, otp);
    this.cleanupExpiredResets();

    return {
      email,
      expiresInSeconds,
      ...(!this.isProduction && !sentViaEmail ? { devOtp: otp } : {}),
    };
  }

  async resetPassword(
    emailRaw: string,
    otp: string,
    newPassword: string,
  ): Promise<{ message: string }> {
    const email = emailRaw.trim().toLowerCase();
    const entry = this.pendingResets.get(email);
    if (!entry) {
      throw new BadRequestException(
        'Không tìm thấy yêu cầu đặt lại mật khẩu. Vui lòng gửi lại mã.',
      );
    }
    if (Date.now() > entry.expiresAt) {
      this.pendingResets.delete(email);
      throw new BadRequestException('Mã OTP đã hết hạn. Vui lòng gửi lại mã.');
    }
    if (entry.attempts >= this.OTP_MAX_ATTEMPTS) {
      this.pendingResets.delete(email);
      throw new BadRequestException(
        'Bạn đã nhập sai quá nhiều lần. Vui lòng gửi lại mã.',
      );
    }
    if (entry.otp !== otp.trim()) {
      entry.attempts += 1;
      const left = this.OTP_MAX_ATTEMPTS - entry.attempts;
      throw new BadRequestException(
        `Mã OTP không đúng.${left > 0 ? ` Còn ${left} lần thử.` : ''}`,
      );
    }

    const user = await this.userRepo.findOne({ where: { email } });
    if (!user) {
      this.pendingResets.delete(email);
      throw new BadRequestException('Tài khoản không tồn tại.');
    }

    user.passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
    await this.userRepo.save(user);
    this.pendingResets.delete(email);

    // Thu hồi mọi refresh token sau khi đổi mật khẩu.
    await this.refreshRepo.update(
      { userId: Number(user.userId), revokedAt: IsNull() },
      { revokedAt: new Date() },
    );

    return { message: 'Đặt lại mật khẩu thành công. Vui lòng đăng nhập lại.' };
  }

  private cleanupExpiredResets(): void {
    const now = Date.now();
    for (const [key, value] of this.pendingResets.entries()) {
      if (now > value.expiresAt) this.pendingResets.delete(key);
    }
  }

  private async register(dto: RegisterDto): Promise<AuthResponseDto> {
    const existing = await this.userRepo.findOne({
      where: [{ email: dto.email }, { phoneNumber: dto.phoneNumber }],
    });
    if (existing) {
      throw new ConflictException(
        existing.email === dto.email
          ? 'Email đã được sử dụng'
          : 'Số điện thoại đã được sử dụng',
      );
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);
    const user = this.userRepo.create({
      phoneNumber: dto.phoneNumber,
      email: dto.email,
      passwordHash,
      displayName: dto.displayName ?? null,
      location: dto.location ?? null,
      kycStatus: 'Unverified',
      accountStatus: 'Active',
      isAdmin: false,
    });

    const saved = await this.userRepo.save(user);
    return this.buildAuthResponse(saved);
  }

  private assertNotDisposableEmail(email: string): void {
    const domain = email.split('@')[1] ?? '';
    if (DISPOSABLE_EMAIL_DOMAINS.has(domain)) {
      throw new BadRequestException(
        'Email tạm thời / ảo không được chấp nhận. Vui lòng dùng email thật.',
      );
    }
  }

  private generateOtp(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  private cleanupExpired(): void {
    const now = Date.now();
    for (const [key, value] of this.pending.entries()) {
      if (now > value.expiresAt) this.pending.delete(key);
    }
  }

  async login(dto: LoginDto): Promise<AuthResponseDto> {
    const loginId = (dto.identifier ?? dto.email ?? '').trim();
    if (!loginId) {
      throw new UnauthorizedException('Email/SĐT hoặc mật khẩu không đúng');
    }
    const user = await this.findUserByLoginId(loginId);
    if (!user) {
      throw new UnauthorizedException('Email/SĐT hoặc mật khẩu không đúng');
    }

    const ok = await this.verifyPassword(dto.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('Email/SĐT hoặc mật khẩu không đúng');
    }

    await this.liftExpiredSuspension(user);

    if (user.accountStatus !== 'Active') {
      throw new UnauthorizedException(this.blockedMessage(user));
    }

    return this.buildAuthResponse(user);
  }

  /** Đổi refresh token cũ lấy cặp token mới (rotate). */
  async refresh(refreshTokenPlain: string): Promise<AuthResponseDto> {
    const hash = this.hashToken(refreshTokenPlain);
    const stored = await this.refreshRepo.findOne({
      where: { tokenHash: hash },
    });
    if (!stored || stored.revokedAt) {
      throw new UnauthorizedException('Refresh token không hợp lệ');
    }
    if (stored.expiresAt.getTime() <= Date.now()) {
      throw new UnauthorizedException('Refresh token đã hết hạn');
    }

    const user = await this.userRepo.findOne({
      where: { userId: stored.userId },
    });
    if (!user) {
      throw new UnauthorizedException('Tài khoản không tồn tại');
    }

    await this.liftExpiredSuspension(user);
    if (user.accountStatus !== 'Active') {
      throw new UnauthorizedException(this.blockedMessage(user));
    }

    const response = await this.buildAuthResponse(user);
    const newHash = this.hashToken(response.refreshToken);
    const newRow = await this.refreshRepo.findOne({
      where: { tokenHash: newHash },
    });

    stored.revokedAt = new Date();
    stored.replacedBy = newRow ? Number(newRow.tokenId) : null;
    await this.refreshRepo.save(stored);

    return response;
  }

  /** Thu hồi refresh token (logout). */
  async logout(refreshTokenPlain: string): Promise<{ message: string }> {
    const hash = this.hashToken(refreshTokenPlain);
    const stored = await this.refreshRepo.findOne({
      where: { tokenHash: hash },
    });
    if (stored && !stored.revokedAt) {
      stored.revokedAt = new Date();
      await this.refreshRepo.save(stored);
    }
    return { message: 'Đã đăng xuất' };
  }

  private async liftExpiredSuspension(user: User): Promise<boolean> {
    if (
      user.accountStatus === 'Locked' &&
      user.lockedUntil &&
      user.lockedUntil.getTime() <= Date.now()
    ) {
      user.accountStatus = 'Active';
      user.lockReason = null;
      user.lockedAt = null;
      user.lockedUntil = null;
      await this.userRepo.save(user);
      return true;
    }
    return false;
  }

  private blockedMessage(user: User): string {
    if (user.accountStatus === 'Deleted') {
      return 'Tài khoản đã bị xóa.';
    }
    const kind = user.accountStatus === 'Locked' ? 'khoá' : 'cấm';
    const until =
      user.accountStatus === 'Locked' && user.lockedUntil
        ? ` đến ${user.lockedUntil.toLocaleString('vi-VN')}`
        : '';
    const reason = user.lockReason ? `: ${user.lockReason}` : '';
    return `Tài khoản đang bị ${kind}${until}${reason}`;
  }

  private async verifyPassword(plain: string, hash: string): Promise<boolean> {
    if (!this.isProduction) {
      if (hash === 'HASH_DEMO' && plain === '123456') return true;
      if (hash === 'HASH_REPLACE_IN_PRODUCTION' && plain === 'admin123') {
        return true;
      }
    }
    if (!hash.startsWith('$2')) return false;
    return bcrypt.compare(plain, hash);
  }

  private async findUserByLoginId(loginId: string): Promise<User | null> {
    if (loginId.includes('@')) {
      return this.userRepo.findOne({ where: { email: loginId } });
    }
    if (loginId.length <= 15) {
      const byPhone = await this.userRepo.findOne({
        where: { phoneNumber: loginId },
      });
      if (byPhone) return byPhone;
    }
    return this.userRepo.findOne({ where: { email: loginId } });
  }

  private async buildAuthResponse(user: User): Promise<AuthResponseDto> {
    const payload: JwtPayload = {
      sub: Number(user.userId),
      email: user.email,
      isAdmin: !!user.isAdmin,
    };

    const expiresIn = this.parseDurationSeconds(
      this.config.get<string>('JWT_EXPIRES_IN', '15m'),
    );
    const accessToken = this.jwtService.sign(payload);
    const refreshToken = await this.issueRefreshToken(Number(user.userId));

    return {
      accessToken,
      refreshToken,
      tokenType: 'Bearer',
      expiresIn,
      user: {
        userId: Number(user.userId),
        email: user.email,
        phoneNumber: user.phoneNumber,
        displayName: user.displayName,
        kycStatus: user.kycStatus,
        accountStatus: user.accountStatus,
        isAdmin: !!user.isAdmin,
      },
    };
  }

  private async issueRefreshToken(userId: number): Promise<string> {
    const plain = randomBytes(48).toString('hex');
    const tokenHash = this.hashToken(plain);
    const ttlSec = this.parseDurationSeconds(
      this.config.get<string>('JWT_REFRESH_EXPIRES_IN', '7d'),
    );
    const expiresAt = new Date(Date.now() + ttlSec * 1000);

    await this.refreshRepo.save(
      this.refreshRepo.create({
        userId,
        tokenHash,
        expiresAt,
        revokedAt: null,
        replacedBy: null,
      }),
    );

    return plain;
  }

  private hashToken(plain: string): string {
    return createHash('sha256').update(plain).digest('hex');
  }

  private parseDurationSeconds(input: string): number {
    const match = /^(\d+)([smhd])?$/.exec(input);
    if (!match) {
      throw new BadRequestException(`JWT duration không hợp lệ: ${input}`);
    }
    const value = Number(match[1]);
    const unit = match[2] ?? 's';
    const multiplier: Record<string, number> = {
      s: 1,
      m: 60,
      h: 3600,
      d: 86400,
    };
    return value * multiplier[unit];
  }
}
