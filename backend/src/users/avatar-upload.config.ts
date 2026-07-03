import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { existsSync, mkdirSync } from 'fs';
import { BadRequestException } from '@nestjs/common';

/** Thư mục lưu ảnh đại diện upload từ Flutter (file thật, không dùng URL ngoài) */
export const AVATAR_UPLOAD_DIR = join(process.cwd(), 'uploads', 'avatars');

export function ensureAvatarUploadDir(): void {
  if (!existsSync(AVATAR_UPLOAD_DIR)) {
    mkdirSync(AVATAR_UPLOAD_DIR, { recursive: true });
  }
}

export const avatarStorage = diskStorage({
  destination: (_req, _file, cb) => {
    ensureAvatarUploadDir();
    cb(null, AVATAR_UPLOAD_DIR);
  },
  filename: (_req, file, cb) => {
    const ext = extname(file.originalname).toLowerCase() || '.jpg';
    const safeExt = ['.jpg', '.jpeg', '.png', '.webp'].includes(ext)
      ? ext
      : '.jpg';
    const name = `avatar-${Date.now()}-${Math.round(Math.random() * 1e6)}${safeExt}`;
    cb(null, name);
  },
});

export function avatarImageFilter(
  _req: Express.Request,
  file: Express.Multer.File,
  cb: (error: Error | null, acceptFile: boolean) => void,
): void {
  if (!file.mimetype.startsWith('image/')) {
    cb(new BadRequestException('Chỉ chấp nhận file ảnh (jpg, png, webp)'), false);
    return;
  }
  cb(null, true);
}

/** Đường dẫn public lưu vào DB, Flutter ghép với host backend */
export function toPublicAvatarPath(filename: string): string {
  return `/uploads/avatars/${filename}`;
}
