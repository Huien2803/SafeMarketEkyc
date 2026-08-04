import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EkycProfile } from '../entities/ekyc-profile.entity';
import { User } from '../entities/user.entity';
import { SubmitEkycDto } from './dto/submit-ekyc.dto';
import { EkycStatusDto } from './dto/ekyc-status.dto';
import { EkycSessionService } from './ekyc-session.service';

/**
 * Lưu hồ sơ eKYC từ phiên server đã đủ bước (OCR + Face ID + face match).
 * Admin duyệt qua /admin/ekyc/:id/approve → Verified.
 */
@Injectable()
export class EkycService {
  private readonly logger = new Logger(EkycService.name);

  constructor(
    @InjectRepository(EkycProfile)
    private readonly ekycRepo: Repository<EkycProfile>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly sessions: EkycSessionService,
  ) {}

  async submit(userId: number, dto: SubmitEkycDto): Promise<EkycStatusDto> {
    if (!dto.sessionId?.trim() || !dto.livenessToken?.trim()) {
      throw new BadRequestException(
        'Thiếu sessionId hoặc livenessToken. Vui lòng hoàn tất đủ các bước xác thực.',
      );
    }

    const locked = this.sessions.assertReadyToSubmit(
      userId,
      dto.sessionId.trim(),
      dto.livenessToken.trim(),
      {
        dob: dto.dob,
        address: dto.address,
        home: dto.home,
      },
    );

    // Chống trùng CCCD với user khác đã Verified/Pending
    const existing = await this.ekycRepo.findOne({
      where: { idNumber: locked.idNumber },
    });
    if (existing && Number(existing.userId) !== userId) {
      const other = await this.userRepo.findOne({
        where: { userId: Number(existing.userId) },
      });
      if (
        other &&
        (other.kycStatus === 'Pending' || other.kycStatus === 'Verified')
      ) {
        throw new BadRequestException(
          'Số CCCD này đã được dùng cho tài khoản khác. Liên hệ hỗ trợ nếu đây là nhầm lẫn.',
        );
      }
    }

    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) throw new NotFoundException('Không tìm thấy user');

    let profile = await this.ekycRepo.findOne({ where: { userId } });
    const now = new Date();
    const dobDate = this.parseDob(locked.dob);

    if (!profile) {
      profile = this.ekycRepo.create({
        userId,
        idNumber: locked.idNumber,
        fullName: locked.fullName,
        dob: dobDate,
        address: locked.address,
        idFrontUrl: locked.idFrontUrl,
        idBackUrl: locked.idBackUrl,
        faceVideoUrl: locked.selfieUrl,
        submittedAt: now,
        verifiedAt: null,
        rejectionReason: null,
      });
    } else {
      profile.idNumber = locked.idNumber;
      profile.fullName = locked.fullName;
      profile.dob = dobDate;
      profile.address = locked.address;
      profile.idFrontUrl = locked.idFrontUrl;
      profile.idBackUrl = locked.idBackUrl;
      profile.faceVideoUrl = locked.selfieUrl;
      profile.submittedAt = now;
      profile.verifiedAt = null;
      profile.rejectionReason = null;
    }

    await this.ekycRepo.save(profile);
    user.kycStatus = 'Pending';
    await this.userRepo.save(user);

    this.sessions.consume(dto.sessionId.trim());

    const refreshed = await this.userRepo.findOne({ where: { userId } });
    this.logger.log(
      `eKYC user ${userId} submitted Pending | points=${locked.recognitionPoints} similarity=${locked.faceSimilarity}`,
    );
    return this.toStatusDto(refreshed!, profile);
  }

  async getMyStatus(userId: number): Promise<EkycStatusDto> {
    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) throw new NotFoundException('Không tìm thấy user');
    const profile = await this.ekycRepo.findOne({ where: { userId } });
    return this.toStatusDto(user, profile);
  }

  private toStatusDto(user: User, profile: EkycProfile | null): EkycStatusDto {
    return {
      status: user.kycStatus ?? 'Unverified',
      fullName: profile?.fullName ?? null,
      idNumber: this.maskIdNumber(profile?.idNumber ?? null),
      dob: profile?.dob ? this.formatDate(profile.dob) : null,
      address: profile?.address ?? null,
      submittedAt: profile?.submittedAt ?? null,
      verifiedAt: profile?.verifiedAt ?? null,
      rejectionReason: profile?.rejectionReason ?? null,
    };
  }

  private parseDob(input: string): Date {
    if (/^\d{4}-\d{2}-\d{2}/.test(input)) return new Date(input);
    const m = input.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (m) {
      return new Date(
        `${m[3]}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}`,
      );
    }
    throw new BadRequestException(`Ngày sinh không hợp lệ: ${input}`);
  }

  private formatDate(d: Date): string {
    const date = d instanceof Date ? d : new Date(d);
    return date.toISOString().slice(0, 10);
  }

  private maskIdNumber(id: string | null): string | null {
    if (!id) return null;
    if (id.length <= 6) return id;
    return id.slice(0, 6) + 'x'.repeat(id.length - 6);
  }
}
