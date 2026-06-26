import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { existsSync, mkdirSync } from 'fs';
import { BadRequestException } from '@nestjs/common';

export const ORDER_UPLOAD_DIR = join(process.cwd(), 'uploads', 'orders');

export function ensureOrderUploadDir(): void {
  if (!existsSync(ORDER_UPLOAD_DIR)) {
    mkdirSync(ORDER_UPLOAD_DIR, { recursive: true });
  }
}

export const orderProofStorage = diskStorage({
  destination: (_req, _file, cb) => {
    ensureOrderUploadDir();
    cb(null, ORDER_UPLOAD_DIR);
  },
  filename: (_req, file, cb) => {
    const ext = extname(file.originalname).toLowerCase() || '.jpg';
    const safeExt = ['.jpg', '.jpeg', '.png', '.webp'].includes(ext)
      ? ext
      : '.jpg';
    const name = `receipt-${Date.now()}-${Math.round(Math.random() * 1e6)}${safeExt}`;
    cb(null, name);
  },
});

export function orderProofFilter(
  _req: Express.Request,
  file: Express.Multer.File,
  cb: (error: Error | null, acceptFile: boolean) => void,
): void {
  if (!file.mimetype.startsWith('image/')) {
    cb(new BadRequestException('Chỉ chấp nhận file ảnh'), false);
    return;
  }
  cb(null, true);
}

export function toPublicOrderProofPath(filename: string): string {
  return `/uploads/orders/${filename}`;
}
