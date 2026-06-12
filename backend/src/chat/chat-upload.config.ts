import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { existsSync, mkdirSync } from 'fs';
import { BadRequestException } from '@nestjs/common';

export const CHAT_UPLOAD_DIR = join(process.cwd(), 'uploads', 'chat');

export function ensureChatUploadDir(): void {
  if (!existsSync(CHAT_UPLOAD_DIR)) {
    mkdirSync(CHAT_UPLOAD_DIR, { recursive: true });
  }
}

export const chatImageStorage = diskStorage({
  destination: (_req, _file, cb) => {
    ensureChatUploadDir();
    cb(null, CHAT_UPLOAD_DIR);
  },
  filename: (_req, file, cb) => {
    const ext = extname(file.originalname).toLowerCase() || '.jpg';
    const safeExt = ['.jpg', '.jpeg', '.png', '.webp'].includes(ext)
      ? ext
      : '.jpg';
    const name = `chat-${Date.now()}-${Math.round(Math.random() * 1e6)}${safeExt}`;
    cb(null, name);
  },
});

export function chatImageFilter(
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

export function toPublicChatPath(filename: string): string {
  return `/uploads/chat/${filename}`;
}
