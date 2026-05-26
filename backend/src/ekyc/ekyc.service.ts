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
import { FptAiService } from './fpt-ai.service';
import { SubmitEkycDto } from './dto/submit-ekyc.dto';
import { EkycStatusDto } from './dto/ekyc-status.dto';

/**
 * Logic eKYC: lưu hồ sơ vào DB, đổi trạng thái user thành Pending/Verified.
 * Trigger SQL [Identity].[trg_SyncKycStatusOnVerify] sẽ tự động set
 * Users.kyc_status = 'Verified' khi verified_at được set.
 */
@Injectable()
export class EkycService {
  private readonly logger = new Logger(EkycService.name);

  /** Ngưỡng similarity face match. >= 0.75 => coi như verified. */
  private readonly FACE_MATCH_THRESHOLD = 0.75;

  constructor(
    @InjectRepository(EkycProfile)
    private readonly ekycRepo: Repository<EkycProfile>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    readonly fptAi: FptAiService,
  ) {}

  /**
   * Sau khi Flutter chạy xong scan-id + face-match, nó gọi /ekyc/submit
   * với toàn bộ thông tin đã trích xuất. Backend sẽ:
   *   1. Validate similarity >= ngưỡng
   *   2. Upsert vào [Identity].[eKYC_Profiles]
   *   3. Set verified_at = now() để trigger SQL chuyển kyc_status -> Verified
   */
  async submit(userId: number, dto: SubmitEkycDto): Promise<EkycStatusDto> {
    if (dto.faceSimilarity < this.FACE_MATCH_THRESHOLD) {
      throw new BadRequestException(
        `Khuôn mặt không khớp với CCCD (similarity ${dto.faceSimilarity.toFixed(
          2,
        )} < ${this.FACE_MATCH_THRESHOLD}). Vui lòng chụp lại.`,
      );
    }

    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) throw new NotFoundException('Không tìm thấy user');

    let profile = await this.ekycRepo.findOne({ where: { userId } });
    const now = new Date();
    const dobDate = this.parseDob(dto.dob);

    if (!profile) {
      profile = this.ekycRepo.create({
        userId,
        idNumber: dto.idNumber,
        fullName: dto.fullName,
        dob: dobDate,
        address: dto.address,
        idFrontUrl: dto.idFrontUrl ?? null,
        idBackUrl: dto.idBackUrl ?? null,
        faceVideoUrl: dto.selfieUrl ?? null,
        submittedAt: now,
        verifiedAt: now,
        rejectionReason: null,
      });
    } else {
      profile.idNumber = dto.idNumber;
      profile.fullName = dto.fullName;
      profile.dob = dobDate;
      profile.address = dto.address;
      profile.idFrontUrl = dto.idFrontUrl ?? profile.idFrontUrl;
      profile.idBackUrl = dto.idBackUrl ?? profile.idBackUrl;
      profile.faceVideoUrl = dto.selfieUrl ?? profile.faceVideoUrl;
      profile.submittedAt = profile.submittedAt ?? now;
      profile.verifiedAt = now;
      profile.rejectionReason = null;
    }

    await this.ekycRepo.save(profile);

    // Trigger SQL sẽ tự set user.kyc_status = 'Verified'. Reload để chắc chắn.
    const refreshed = await this.userRepo.findOne({ where: { userId } });

    this.logger.log(
      `eKYC user ${userId} verified, similarity=${dto.faceSimilarity}`,
    );

    return this.toStatusDto(refreshed!, profile);
  }

  /** Lấy trạng thái eKYC hiện tại của user đang đăng nhập */
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

  /** Cho phép cả 'dd/MM/yyyy' (FPT trả về) hoặc 'yyyy-MM-dd' */
  private parseDob(input: string): Date {
    if (/^\d{4}-\d{2}-\d{2}/.test(input)) return new Date(input);
    const m = input.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (m) return new Date(`${m[3]}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}`);
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
