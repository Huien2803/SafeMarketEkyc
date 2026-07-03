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
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from '../entities/user.entity';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
import { JwtPayload } from './strategies/jwt.strategy';
import { MailService } from '../mail/mail.service';

const BCRYPT_ROUNDS = 10;

/** Hồ sơ đăng ký đang chờ xác thực OTP (lưu tạm trong RAM). */
interface PendingRegistration {
  dto: RegisterDto;
  otp: string;
  expiresAt: number;
  attempts: number;
  lastSentAt: number;
}

/**
 * Danh sách domain email "ảo" / dùng một lần thường gặp — chặn để tránh
 * tạo tài khoản bằng mail ảo. OTP gửi tới hộp thư thật mới tạo được tài khoản.
 */
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

  /** OTP còn hiệu lực 5 phút. */
  private readonly OTP_TTL_MS = 5 * 60 * 1000;
  /** Tối đa 5 lần nhập sai. */
  private readonly OTP_MAX_ATTEMPTS = 5;
  /** Chỉ cho gửi lại OTP sau 30 giây. */
  private readonly OTP_RESEND_COOLDOWN_MS = 30 * 1000;

  /** Hồ sơ chờ xác thực, key = email (lowercase). */
  private readonly pending = new Map<string, PendingRegistration>();

  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly mailService: MailService,
  ) {}

  /**
   * Bước 1: nhận thông tin đăng ký, kiểm tra trùng + chặn mail ảo, sinh OTP
   * và gửi về email. Chưa tạo tài khoản cho tới khi OTP được xác thực.
   */
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

    const isDev =
      this.config.get<string>('NODE_ENV', 'development') !== 'production';
    return {
      email,
      expiresInSeconds: Math.floor(this.OTP_TTL_MS / 1000),
      ...(isDev && !sentViaEmail ? { devOtp: otp } : {}),
    };
  }

  /**
   * Bước 2: xác thực OTP. Đúng -> tạo tài khoản thật + đăng nhập luôn.
   */
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

    if (user.accountStatus !== 'Active') {
      throw new UnauthorizedException(
        `Tài khoản đang bị ${
          user.accountStatus === 'Locked' ? 'khoá' : 'cấm'
        }${user.lockReason ? `: ${user.lockReason}` : ''}`,
      );
    }

    return this.buildAuthResponse(user);
  }

  /** Mật khẩu seed SQL (HASH_DEMO / HASH_REPLACE_IN_PRODUCTION) cho môi trường demo. */
  private async verifyPassword(plain: string, hash: string): Promise<boolean> {
    if (hash === 'HASH_DEMO' && plain === '123456') return true;
    if (hash === 'HASH_REPLACE_IN_PRODUCTION' && plain === 'admin123') {
      return true;
    }
    if (!hash.startsWith('$2')) return false;
    return bcrypt.compare(plain, hash);
  }

  /** Tránh bind email dài vào cột phone_number (varchar 15) — lỗi TDS SQL Server. */
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

  private buildAuthResponse(user: User): AuthResponseDto {
    const payload: JwtPayload = {
      sub: Number(user.userId),
      email: user.email,
      isAdmin: !!user.isAdmin,
    };

    const expiresIn = this.parseDurationSeconds(
      this.config.get<string>('JWT_EXPIRES_IN', '7d'),
    );
    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
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

  private parseDurationSeconds(input: string): number {
    const match = /^(\d+)([smhd])?$/.exec(input);
    if (!match) {
      throw new BadRequestException(`JWT_EXPIRES_IN không hợp lệ: ${input}`);
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
