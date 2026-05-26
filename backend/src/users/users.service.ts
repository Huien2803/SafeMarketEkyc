import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../entities/user.entity';
import { Score } from '../entities/score.entity';
import { EkycProfile } from '../entities/ekyc-profile.entity';
import { UserProfileDto } from './dto/user-profile.dto';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(Score) private readonly scoreRepo: Repository<Score>,
    @InjectRepository(EkycProfile)
    private readonly ekycRepo: Repository<EkycProfile>,
  ) {}

  async getProfile(userId: number): Promise<UserProfileDto> {
    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    const score = await this.scoreRepo.findOne({ where: { userId } });
    const ekyc = await this.ekycRepo.findOne({ where: { userId } });

    return {
      userId: Number(user.userId),
      email: user.email,
      phoneNumber: user.phoneNumber,
      displayName: user.displayName,
      location: user.location,
      avatarUrl: user.avatarUrl,
      accountStatus: user.accountStatus,
      isAdmin: !!user.isAdmin,
      createdAt: user.createdAt,
      trustScore: score
        ? {
            currentPoint: score.currentPoint,
            maxPoint: 1000,
            rankLevel: score.rankLevel,
            updatedAt: score.updatedAt,
          }
        : null,
      ekyc: {
        status: user.kycStatus,
        fullName: ekyc?.fullName ?? null,
        idNumber: ekyc ? this.maskIdNumber(ekyc.idNumber) : null,
        verifiedAt: ekyc?.verifiedAt ?? null,
      },
    };
  }

  /** Che số CCCD: 079202xxxxxx (chỉ hiện 6 đầu) */
  private maskIdNumber(id: string | null): string | null {
    if (!id) return null;
    if (id.length <= 6) return id;
    return id.slice(0, 6) + 'x'.repeat(id.length - 6);
  }
}
