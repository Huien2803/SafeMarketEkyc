/**
 * PM2 ecosystem config cho SafeMarket Backend.
 *
 * Trên Windows, PM2 KHÔNG chạy được `npm` trực tiếp (vì npm là batch file).
 * Cách chuẩn: build production trước, rồi PM2 chạy node dist/main.js.
 *
 * Quy trình:
 *   1. npm run build                            ← build TypeScript → dist/
 *   2. pm2 start ecosystem.config.js            ← PM2 chạy dist/main.js
 *   3. pm2 save                                  ← lưu để auto-start khi reboot
 *
 * Khi sửa code:
 *   npm run build && pm2 restart safemarket-api
 *
 * Lệnh hay dùng:
 *   pm2 list                       ← xem process đang chạy
 *   pm2 logs safemarket-api        ← xem log real-time
 *   pm2 stop safemarket-api        ← dừng
 *   pm2 restart safemarket-api     ← restart
 *   pm2 delete safemarket-api      ← xóa khỏi danh sách
 *   pm2 monit                      ← dashboard CPU/RAM (đẹp khi demo)
 */
module.exports = {
  apps: [
    {
      name: 'safemarket-api',
      script: './dist/main.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',
      env: {
        NODE_ENV: 'production',
        PORT: '3000',
      },
      out_file: './logs/safemarket-out.log',
      error_file: './logs/safemarket-error.log',
      merge_logs: true,
      time: true,
    },
  ],
};
