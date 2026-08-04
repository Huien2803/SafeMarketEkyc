// eslint-disable-next-line @typescript-eslint/no-require-imports
const sharp: any = require('sharp');
// eslint-disable-next-line @typescript-eslint/no-require-imports
const jsQR = require('jsqr') as (
  data: Uint8ClampedArray,
  width: number,
  height: number,
  options?: { inversionAttempts?: string },
) => { data: string } | null;

export type CccdQrFields = {
  idNumber?: string;
  fullName?: string;
  dob?: string;
  sex?: string;
  home?: string;
  address?: string;
  issueDate?: string;
};

/** Chuẩn hóa ngày: ddMMyyyy / yyyy-MM-dd / dd-MM-yyyy → dd/MM/yyyy */
export function normalizeVnDate(raw: string): string {
  const s = String(raw ?? '').trim();
  if (!s) return '';
  const slash = s.match(/^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{4})$/);
  if (slash) {
    return `${slash[1].padStart(2, '0')}/${slash[2].padStart(2, '0')}/${slash[3]}`;
  }
  const compact = s.match(/^(\d{2})(\d{2})(\d{4})$/);
  if (compact) {
    return `${compact[1]}/${compact[2]}/${compact[3]}`;
  }
  const iso = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (iso) {
    return `${iso[3]}/${iso[2]}/${iso[1]}`;
  }
  return s;
}

/**
 * Parse nội dung QR CCCD gắn chip (Bộ Công an).
 * Thường: id|cmnd9|họ tên|ngày sinh|giới tính|địa chỉ thường trú|ngày cấp
 * Một số bản: thêm quê quán / quốc tịch ở giữa.
 */
export function parseCccdQrPayload(raw: string): CccdQrFields | null {
  const text = String(raw ?? '').trim();
  if (!text || !text.includes('|')) return null;

  const parts = text.split('|').map((p) => p.trim());
  if (parts.length < 4) return null;

  const idNumber = parts[0] ?? '';
  if (!/^\d{9,12}$/.test(idNumber)) return null;

  const result: CccdQrFields = { idNumber };

  // Họ tên: thường phần tử 2 (sau số CMND cũ có thể rỗng)
  if (parts.length >= 3 && parts[2]) result.fullName = parts[2];

  // Ngày sinh: phần tử 3
  if (parts.length >= 4 && parts[3]) {
    result.dob = normalizeVnDate(parts[3]);
  }

  // Giới tính
  if (parts.length >= 5 && parts[4]) result.sex = parts[4];

  // 7 trường chuẩn: [5]=địa chỉ, [6]=ngày cấp
  // 8+ trường: có thể [5]=quê quán, [6]=địa chỉ hoặc [5]=quốc tịch
  if (parts.length === 7) {
    if (parts[5]) result.address = parts[5];
    if (parts[6]) result.issueDate = normalizeVnDate(parts[6]);
  } else if (parts.length >= 8) {
    const p5 = parts[5] ?? '';
    const p6 = parts[6] ?? '';
    const p7 = parts[7] ?? '';
    // Nếu p5 ngắn như "Việt Nam" / "VN" thì quê/địa chỉ nằm sau
    if (/^(việt nam|viet nam|vn)$/i.test(p5)) {
      if (p6) result.home = p6;
      if (p7) result.address = p7;
      if (parts[8]) result.issueDate = normalizeVnDate(parts[8]);
    } else {
      // Coi p5 = quê quán, p6 = địa chỉ (hoặc cả hai là địa chỉ dài)
      if (p5 && p6 && p5.length < 80 && p6.length > p5.length) {
        result.home = p5;
        result.address = p6;
      } else if (p5) {
        result.address = p5;
        if (p6 && !/^\d{8}$/.test(p6.replace(/\D/g, '').slice(0, 8))) {
          result.home = p5;
          result.address = p6;
        }
      }
      const lastDate = [...parts].reverse().find((p) =>
        /^\d{8}$|^\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{4}$/.test(p),
      );
      if (lastDate) result.issueDate = normalizeVnDate(lastDate);
    }
  } else if (parts.length >= 6) {
    if (parts[5]) result.address = parts[5];
  }

  return result;
}

/** Đọc QR từ buffer ảnh (JPEG/PNG). Thử scale + tăng tương phản; ưu tiên góc QR. */
export async function decodeCccdQrFromImage(
  buffer: Buffer,
): Promise<CccdQrFields | null> {
  const attempts: Array<() => Promise<Buffer>> = [
    async () => buffer,
    async () =>
      sharp(buffer).greyscale().normalize().sharpen().toBuffer(),
    async () => {
      const meta = await sharp(buffer).metadata();
      const w = meta.width ?? 1000;
      const h = meta.height ?? 1000;
      // QR CCCD thường góc phải trên — crop ~35% góc đó rồi phóng to
      return sharp(buffer)
        .extract({
          left: Math.floor(w * 0.55),
          top: 0,
          width: Math.floor(w * 0.45),
          height: Math.floor(h * 0.45),
        })
        .greyscale()
        .normalize()
        .resize({ width: 800 })
        .toBuffer();
    },
  ];

  for (const makeBuf of attempts) {
    try {
      const src = await makeBuf();
      for (const scale of [1, 1.5, 2, 2.5]) {
        let pipeline = sharp(src).ensureAlpha().rotate();
        if (scale !== 1) {
          const meta = await sharp(src).metadata();
          const w = Math.round((meta.width ?? 800) * scale);
          pipeline = pipeline.resize({ width: w });
        }
        const { data, info } = await pipeline
          .raw()
          .toBuffer({ resolveWithObject: true });
        const code = jsQR(
          new Uint8ClampedArray(data.buffer, data.byteOffset, data.byteLength),
          info.width,
          info.height,
          { inversionAttempts: 'attemptBoth' },
        );
        if (!code?.data) continue;
        const parsed = parseCccdQrPayload(code.data);
        if (parsed) return parsed;
      }
    } catch {
      // thử attempt tiếp
    }
  }
  return null;
}

/** Điền field trống từ QR vào kết quả OCR. */
export function mergeOcrWithQr<T extends Record<string, any>>(
  ocr: T,
  qr: CccdQrFields | null,
): T {
  if (!qr) return ocr;
  const out = { ...ocr };
  const fill = (key: keyof T & string, value?: string) => {
    const cur = String(out[key] ?? '').trim();
    if ((!cur || cur === '—' || /^n\/?a$/i.test(cur)) && value?.trim()) {
      (out as Record<string, unknown>)[key] = value.trim();
    }
  };
  fill('idNumber' as keyof T & string, qr.idNumber);
  fill('fullName' as keyof T & string, qr.fullName);
  fill('dob' as keyof T & string, qr.dob);
  fill('sex' as keyof T & string, qr.sex);
  fill('home' as keyof T & string, qr.home);
  fill('address' as keyof T & string, qr.address);
  // QR chuẩn thường chỉ có địa chỉ thường trú (không có quê quán riêng).
  // Nếu thiếu quê → không bịa; user nhập tay hoặc OCR điền.
  return out;
}
