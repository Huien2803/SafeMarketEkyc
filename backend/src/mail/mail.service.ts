import {
  Injectable,
  Logger,
  OnModuleInit,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

/** Giá trị mẫu trong .env — không coi là SMTP thật. */
const SMTP_PLACEHOLDER_MARKERS = [
  'your_email@gmail.com',
  'your_gmail_app_password',
  'email_cua_ban@gmail.com',
  'app_password_16_ky_tu',
  'changeme',
];

/**
 * Gửi email OTP (đăng ký / quên mật khẩu) qua SMTP (Gmail App Password khuyến nghị).
 *
 * Biến .env: SMTP_HOST, SMTP_PORT, SMTP_SECURE, SMTP_USER, SMTP_PASS, MAIL_FROM
 * Tuỳ chọn: SMTP_ALLOW_DEV_FALLBACK=true → khi chưa cấu hình/lỗi SMTP, in OTP ra console (dev).
 */
@Injectable()
export class MailService implements OnModuleInit {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter | null = null;
  private readonly from: string;
  private readonly isDev: boolean;
  private readonly allowDevFallback: boolean;
  private readonly smtpUser: string;

  constructor(private readonly config: ConfigService) {
    this.isDev =
      this.config.get<string>('NODE_ENV', 'development') !== 'production';
    // Dev mặc định cho phép fallback (OTP hiện app) nếu chưa cấu hình SMTP —
    // khớp hành vi lúc đầu đăng ký vẫn chạy được. Production luôn bắt buộc SMTP.
    const fallbackCfg = this.config
      .get<string>('SMTP_ALLOW_DEV_FALLBACK', '')
      .trim()
      .toLowerCase();
    this.allowDevFallback =
      !this.isDev
        ? false
        : fallbackCfg === ''
          ? true
          : fallbackCfg === 'true' || fallbackCfg === '1';

    const hostRaw = this.config.get<string>('SMTP_HOST', '').trim();
    const user = this.config.get<string>('SMTP_USER', '').trim();
    // Gmail App Password thường hiện dạng "xxxx xxxx xxxx xxxx" — bỏ khoảng trắng.
    const pass = this.config
      .get<string>('SMTP_PASS', '')
      .trim()
      .replace(/\s+/g, '');
    this.smtpUser = user;

    const host =
      !hostRaw || hostRaw.toLowerCase() === 'gmail'
        ? 'smtp.gmail.com'
        : hostRaw;

    const mailFromCfg = this.config.get<string>('MAIL_FROM', '').trim();
    // Gmail chỉ cho phép From trùng tài khoản đăng nhập (hoặc alias đã xác minh).
    this.from = this.resolveFrom(mailFromCfg, user);

    if (this.isRealSmtpConfig(host, user, pass)) {
      const port = parseInt(this.config.get<string>('SMTP_PORT', '587'), 10);
      const secure =
        this.config.get<string>('SMTP_SECURE', 'false') === 'true' ||
        port === 465;

      const isGmail =
        host.includes('gmail.com') || hostRaw.toLowerCase() === 'gmail';

      this.transporter = nodemailer.createTransport(
        isGmail
          ? {
              service: 'gmail',
              auth: { user, pass },
            }
          : {
              host,
              port,
              secure,
              auth: { user, pass },
              requireTLS: !secure && port === 587,
              tls: { minVersion: 'TLSv1.2' },
              connectionTimeout: 20_000,
              greetingTimeout: 15_000,
              socketTimeout: 30_000,
            },
      );
      this.logger.log(
        `SMTP sẵn sàng (${isGmail ? 'Gmail' : host}:${port}) — gửi từ ${this.from}`,
      );
    } else {
      this.logger.warn(
        'SMTP chưa cấu hình (điền SMTP_USER + SMTP_PASS trong backend/.env). ' +
          (this.allowDevFallback
            ? 'SMTP_ALLOW_DEV_FALLBACK=true → OTP in console.'
            : 'Đăng ký sẽ báo lỗi cho đến khi cấu hình SMTP.'),
      );
    }
  }

  async onModuleInit(): Promise<void> {
    if (!this.transporter) return;
    // Không await: verify SMTP có thể treo 15–20s và làm API trễ lúc vừa start.
    void this.transporter
      .verify()
      .then(() => this.logger.log('Kết nối SMTP OK — sẵn sàng gửi OTP email.'))
      .catch((err: Error) => {
        this.logger.error(
          `Không xác minh được SMTP: ${err.message}. ` +
            'Kiểm tra App Password Gmail (2FA + App passwords).',
        );
      });
  }

  /** true nếu OTP được gửi qua SMTP; false nếu chỉ in console (khi cho phép fallback). */
  async sendRegistrationOtp(email: string, otp: string): Promise<boolean> {
    return this.sendOtpMail({
      email,
      otp,
      subject: 'Mã xác thực đăng ký SafeMarket',
      text: `Mã OTP đăng ký SafeMarket của bạn là: ${otp}\nMã có hiệu lực trong 5 phút. Không chia sẻ mã này cho người khác.`,
      html: this.buildOtpHtml(otp),
      logLabel: 'đăng ký',
    });
  }

  async sendPasswordResetOtp(email: string, otp: string): Promise<boolean> {
    return this.sendOtpMail({
      email,
      otp,
      subject: 'Mã đặt lại mật khẩu SafeMarket',
      text: `Mã OTP đặt lại mật khẩu SafeMarket của bạn là: ${otp}\nMã có hiệu lực trong 5 phút. Nếu bạn không yêu cầu, hãy bỏ qua email này.`,
      html: this.buildResetHtml(otp),
      logLabel: 'đặt lại mật khẩu',
    });
  }

  private async sendOtpMail(opts: {
    email: string;
    otp: string;
    subject: string;
    text: string;
    html: string;
    logLabel: string;
  }): Promise<boolean> {
    if (!this.transporter) {
      if (this.allowDevFallback && this.isDev) {
        this.logDevOtp(opts.email, opts.otp);
        return false;
      }
      throw new ServiceUnavailableException(
        'Chưa cấu hình SMTP để gửi email OTP. Điền SMTP_USER và SMTP_PASS (Gmail App Password) trong backend/.env rồi khởi động lại server.',
      );
    }

    try {
      const info = await this.transporter.sendMail({
        from: this.from,
        to: opts.email,
        subject: opts.subject,
        text: opts.text,
        html: opts.html,
        replyTo: this.smtpUser || undefined,
      });
      this.logger.log(
        `Đã gửi OTP ${opts.logLabel} tới ${opts.email} (messageId=${info.messageId ?? 'n/a'})`,
      );
      return true;
    } catch (err) {
      const msg = (err as Error).message;
      this.logger.error(`Gửi OTP ${opts.logLabel} tới ${opts.email} thất bại: ${msg}`);

      if (this.allowDevFallback && this.isDev) {
        this.logger.warn('SMTP lỗi — fallback in OTP ra console (SMTP_ALLOW_DEV_FALLBACK).');
        this.logDevOtp(opts.email, opts.otp);
        return false;
      }

      throw new ServiceUnavailableException(
        'Không gửi được email OTP. Kiểm tra SMTP_USER/SMTP_PASS (Gmail cần App Password 16 ký tự), hộp thư spam, và kết nối mạng.',
      );
    }
  }

  private resolveFrom(mailFromCfg: string, smtpUser: string): string {
    if (!smtpUser) {
      return mailFromCfg || 'SafeMarket <no-reply@safemarket.vn>';
    }
    // no-reply@safemarket.vn sẽ bị Gmail từ chối khi auth bằng Gmail cá nhân.
    const invalidDomain =
      !mailFromCfg ||
      /no-reply@safemarket\.vn/i.test(mailFromCfg) ||
      /@safemarket\.vn/i.test(mailFromCfg);

    if (invalidDomain) {
      return `SafeMarket <${smtpUser}>`;
    }
    return mailFromCfg;
  }

  private isRealSmtpConfig(host: string, user: string, pass: string): boolean {
    if (!host || !user || !pass) return false;
    const combined = `${host} ${user} ${pass}`.toLowerCase();
    return !SMTP_PLACEHOLDER_MARKERS.some((marker) =>
      combined.includes(marker.toLowerCase()),
    );
  }

  private logDevOtp(email: string, otp: string): void {
    this.logger.log(`[DEV OTP] Gửi tới ${email}: ${otp}`);
  }

  private buildOtpHtml(otp: string): string {
    return `
      <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto">
        <h2 style="color:#2563eb">SafeMarket</h2>
        <p>Mã xác thực đăng ký tài khoản của bạn:</p>
        <div style="font-size:32px;font-weight:bold;letter-spacing:8px;
             color:#111;background:#f1f5f9;padding:16px;text-align:center;
             border-radius:8px">${otp}</div>
        <p style="color:#64748b;font-size:13px;margin-top:16px">
          Mã có hiệu lực trong 5 phút. Vui lòng không chia sẻ mã này cho bất kỳ ai.
        </p>
      </div>`;
  }

  private buildResetHtml(otp: string): string {
    return `
      <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto">
        <h2 style="color:#2563eb">SafeMarket</h2>
        <p>Mã xác thực để đặt lại mật khẩu của bạn:</p>
        <div style="font-size:32px;font-weight:bold;letter-spacing:8px;
             color:#111;background:#f1f5f9;padding:16px;text-align:center;
             border-radius:8px">${otp}</div>
        <p style="color:#64748b;font-size:13px;margin-top:16px">
          Mã có hiệu lực trong 5 phút. Nếu bạn không yêu cầu đặt lại mật khẩu,
          hãy bỏ qua email này.
        </p>
      </div>`;
  }
}
