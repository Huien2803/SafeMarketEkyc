/**
 * Kiểm tra cấu hình SMTP trong .env trước khi demo đăng ký.
 * Chạy: node scripts/test-smtp.js
 * (từ thư mục backend, sau khi đã điền SMTP_USER / SMTP_PASS)
 */
/* eslint-disable @typescript-eslint/no-require-imports */
const fs = require('fs');
const path = require('path');
const nodemailer = require('nodemailer');

function loadEnv(filePath) {
  const out = {};
  if (!fs.existsSync(filePath)) return out;
  for (const line of fs.readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const i = t.indexOf('=');
    if (i < 0) continue;
    out[t.slice(0, i).trim()] = t.slice(i + 1).trim();
  }
  return out;
}

async function main() {
  const env = loadEnv(path.join(__dirname, '..', '.env'));
  const user = (env.SMTP_USER || '').trim();
  const pass = (env.SMTP_PASS || '').trim().replace(/\s+/g, '');
  const host = (env.SMTP_HOST || 'smtp.gmail.com').trim();

  if (!user || !pass) {
    console.error(
      'Thiếu SMTP_USER hoặc SMTP_PASS trong backend/.env\n' +
        '→ Gmail: bật 2FA → https://myaccount.google.com/apppasswords',
    );
    process.exit(1);
  }

  const to = process.argv[2] || user;
  const otp = String(Math.floor(100000 + Math.random() * 900000));
  const transporter = nodemailer.createTransport({
    service: host.includes('gmail') ? 'gmail' : undefined,
    host: host.includes('gmail') ? undefined : host,
    port: parseInt(env.SMTP_PORT || '587', 10),
    secure: env.SMTP_SECURE === 'true',
    auth: { user, pass },
  });

  console.log(`Đang verify SMTP (${user})...`);
  await transporter.verify();
  console.log('SMTP OK. Đang gửi mail thử...');
  const info = await transporter.sendMail({
    from: `SafeMarket <${user}>`,
    to,
    subject: 'SafeMarket — kiểm tra OTP',
    text: `Mã OTP thử: ${otp}`,
    html: `<p>Mã OTP thử SafeMarket: <b>${otp}</b></p>`,
  });
  console.log(`Đã gửi tới ${to}. messageId=${info.messageId}`);
  console.log(`OTP thử: ${otp} — mở Gmail (cả mục Spam) trên điện thoại để xác nhận.`);
}

main().catch((e) => {
  console.error('Lỗi SMTP:', e.message);
  process.exit(1);
});
