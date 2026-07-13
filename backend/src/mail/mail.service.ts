import {
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

/** Giá trị mẫu trong .env.example — không coi là SMTP thật. */
const SMTP_PLACEHOLDER_MARKERS = [
  'your_email@gmail.com',
  'your_gmail_app_password',
  'email_cua_ban@gmail.com',
  'app_password_16_ky_tu',
  'changeme',
];

/**
 * Gửi email (OTP đăng ký...). Đọc cấu hình SMTP từ .env:
 *   SMTP_HOST, SMTP_PORT, SMTP_SECURE, SMTP_USER, SMTP_PASS, MAIL_FROM
 *
 * Nếu chưa cấu hình SMTP (môi trường dev), OTP sẽ được in ra console để
 * vẫn test được luồng mà không cần mail thật.
 */
@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter | null = null;
  private readonly from: string;
  private readonly isDev: boolean;

  constructor(private readonly config: ConfigService) {
    this.isDev = this.config.get<string>('NODE_ENV', 'development') !== 'production';
    const host = this.config.get<string>('SMTP_HOST', '').trim();
    const user = this.config.get<string>('SMTP_USER', '').trim();
    const pass = this.config.get<string>('SMTP_PASS', '').trim();
    this.from = this.config.get<string>(
      'MAIL_FROM',
      user || 'no-reply@safemarket.vn',
    );

    if (this.isRealSmtpConfig(host, user, pass)) {
      const port = parseInt(this.config.get<string>('SMTP_PORT', '587'), 10);
      const secure =
        this.config.get<string>('SMTP_SECURE', 'false') === 'true' ||
        port === 465;
      this.transporter = nodemailer.createTransport({
        host,
        port,
        secure,
        auth: { user, pass },
        requireTLS: !secure && port === 587,
        tls: { minVersion: 'TLSv1.2' },
      });
    } else {
      this.logger.warn(
        'SMTP chưa cấu hình hoặc đang dùng giá trị mẫu — OTP sẽ in ra console thay vì gửi email.',
      );
    }
  }

  /** true nếu OTP được gửi qua SMTP; false nếu chỉ in ra console (dev). */
  async sendRegistrationOtp(email: string, otp: string): Promise<boolean> {
    const subject = 'Mã xác thực đăng ký SafeMarket';
    const text = `Mã OTP đăng ký SafeMarket của bạn là: ${otp}\nMã có hiệu lực trong 5 phút. Không chia sẻ mã này cho người khác.`;

    if (!this.transporter) {
      if (!this.isDev) {
        throw new ServiceUnavailableException(
          'SMTP chưa cấu hình. Không thể gửi email trên production.',
        );
      }
      this.logDevOtp(email, otp);
      return false;
    }

    try {
      await this.transporter.sendMail({
        from: this.from,
        to: email,
        subject,
        text,
        html: this.buildOtpHtml(otp),
      });
      this.logger.log(`Đã gửi OTP đăng ký tới ${email}`);
      return true;
    } catch (err) {
      this.logger.error(
        `Gửi OTP tới ${email} thất bại: ${(err as Error).message}`,
      );
      if (this.isDev) {
        this.logger.warn(
          'SMTP lỗi trong môi trường dev — fallback in OTP ra console.',
        );
        this.logDevOtp(email, otp);
        return false;
      }
      throw new ServiceUnavailableException(
        'Không thể gửi email xác thực. Kiểm tra cấu hình SMTP trong .env.',
      );
    }
  }

  /** true nếu OTP được gửi qua SMTP; false nếu chỉ in ra console (dev). */
  async sendPasswordResetOtp(email: string, otp: string): Promise<boolean> {
    const subject = 'Mã đặt lại mật khẩu SafeMarket';
    const text = `Mã OTP đặt lại mật khẩu SafeMarket của bạn là: ${otp}\nMã có hiệu lực trong 5 phút. Nếu bạn không yêu cầu, hãy bỏ qua email này.`;

    if (!this.transporter) {
      if (!this.isDev) {
        throw new ServiceUnavailableException(
          'SMTP chưa cấu hình. Không thể gửi email trên production.',
        );
      }
      this.logDevOtp(email, otp);
      return false;
    }

    try {
      await this.transporter.sendMail({
        from: this.from,
        to: email,
        subject,
        text,
        html: this.buildResetHtml(otp),
      });
      this.logger.log(`Đã gửi OTP đặt lại mật khẩu tới ${email}`);
      return true;
    } catch (err) {
      this.logger.error(
        `Gửi OTP reset tới ${email} thất bại: ${(err as Error).message}`,
      );
      if (this.isDev) {
        this.logDevOtp(email, otp);
        return false;
      }
      throw new ServiceUnavailableException(
        'Không thể gửi email. Kiểm tra cấu hình SMTP trong .env.',
      );
    }
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
