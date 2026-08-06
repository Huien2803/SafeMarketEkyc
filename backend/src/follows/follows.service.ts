import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserFollow } from '../entities/user-follow.entity';
import { User } from '../entities/user.entity';

@Injectable()
export class FollowsService {
  constructor(
    @InjectRepository(UserFollow)
    private readonly followRepo: Repository<UserFollow>,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
  ) {}

  async follow(followerId: number, followeeId: number): Promise<{ following: boolean }> {
    if (followerId === followeeId) {
      throw new BadRequestException('Không thể theo dõi chính mình');
    }
    const target = await this.userRepo.findOne({ where: { userId: followeeId } });
    if (!target) throw new NotFoundException('Người dùng không tồn tại');

    const existing = await this.followRepo.findOne({
      where: { followerId, followeeId },
    });
    if (!existing) {
      await this.followRepo.save({ followerId, followeeId });
    }
    return { following: true };
  }

  async unfollow(followerId: number, followeeId: number): Promise<{ following: boolean }> {
    await this.followRepo.delete({ followerId, followeeId });
    return { following: false };
  }

  async isFollowing(followerId: number, followeeId: number): Promise<boolean> {
    if (followerId === followeeId) return false;
    const row = await this.followRepo.findOne({
      where: { followerId, followeeId },
    });
    return !!row;
  }

  async followerCount(userId: number): Promise<number> {
    return this.followRepo.count({ where: { followeeId: userId } });
  }

  async followingCount(userId: number): Promise<number> {
    return this.followRepo.count({ where: { followerId: userId } });
  }

  async listFollowers(userId: number) {
    const rows = await this.followRepo.find({
      where: { followeeId: userId },
      relations: ['follower'],
      order: { createdAt: 'DESC' },
    });
    return rows
      .map((r) => this.toUserCard(r.follower))
      .filter((u): u is NonNullable<typeof u> => u != null);
  }

  async listFollowing(userId: number) {
    const rows = await this.followRepo.find({
      where: { followerId: userId },
      relations: ['followee'],
      order: { createdAt: 'DESC' },
    });
    return rows
      .map((r) => this.toUserCard(r.followee))
      .filter((u): u is NonNullable<typeof u> => u != null);
  }

  private toUserCard(user?: User | null) {
    if (!user) return null;
    return {
      userId: Number(user.userId),
      displayName: user.displayName ?? null,
      email: user.email,
      avatarUrl: user.avatarUrl ?? null,
      kycStatus: user.kycStatus,
    };
  }

  async getFolloweeIds(userId: number): Promise<number[]> {
    const rows = await this.followRepo.find({
      where: { followerId: userId },
      select: ['followeeId'],
    });
    return rows.map((r) => Number(r.followeeId));
  }

  async getFollowerIds(userId: number): Promise<number[]> {
    const rows = await this.followRepo.find({
      where: { followeeId: userId },
      select: ['followerId'],
    });
    return rows.map((r) => Number(r.followerId));
  }
}
