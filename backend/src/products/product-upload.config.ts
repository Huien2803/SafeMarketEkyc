import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { existsSync, mkdirSync } from 'fs';
import { BadRequestException } from '@nestjs/common';

/** Thư mục lưu ảnh sản phẩm upload từ Flutter (file thật, không dùng URL ngoài) */
export const PRODUCT_UPLOAD_DIR = join(process.cwd(), 'uploads', 'products');

/** Số ảnh tối đa cho mỗi sản phẩm */
export const MAX_PRODUCT_IMAGES = 8;

export function ensureProductUploadDir(): void {
  if (!existsSync(PRODUCT_UPLOAD_DIR)) {
    mkdirSync(PRODUCT_UPLOAD_DIR, { recursive: true });
  }
}

export const productImageStorage = diskStorage({
  destination: (_req, _file, cb) => {
    ensureProductUploadDir();
    cb(null, PRODUCT_UPLOAD_DIR);
  },
  filename: (_req, file, cb) => {
    const ext = extname(file.originalname).toLowerCase() || '.jpg';
    const safeExt = ['.jpg', '.jpeg', '.png', '.webp'].includes(ext)
      ? ext
      : '.jpg';
    const name = `product-${Date.now()}-${Math.round(Math.random() * 1e6)}${safeExt}`;
    cb(null, name);
  },
});

export function productImageFilter(
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
export function toPublicUploadPath(filename: string): string {
  return `/uploads/products/${filename}`;
}
