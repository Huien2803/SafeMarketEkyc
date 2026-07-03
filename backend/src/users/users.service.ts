import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../entities/user.entity';
import { Score } from '../entities/score.entity';
import { EkycProfile } from '../entities/ekyc-profile.entity';
import { Product } from '../entities/product.entity';
import { Order } from '../entities/order.entity';
import { Review } from '../entities/review.entity';
import { UserProfileDto } from './dto/user-profile.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { OrdersService } from '../orders/orders.service';
import { FollowsService } from '../follows/follows.service';
import { toPublicAvatarPath } from './avatar-upload.config';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(Score) private readonly scoreRepo: Repository<Score>,
    @InjectRepository(EkycProfile)
    private readonly ekycRepo: Repository<EkycProfile>,
    @InjectRepository(Product) private readonly productRepo: Repository<Product>,
    @InjectRepository(Order) private readonly orderRepo: Repository<Order>,
    @InjectRepository(Review) private readonly reviewRepo: Repository<Review>,
    private readonly ordersService: OrdersService,
    private readonly followsService: FollowsService,
  ) {}

  async getProfile(userId: number, viewerId?: number): Promise<UserProfileDto> {
    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    const score = await this.scoreRepo.findOne({ where: { userId } });
    const ekyc = await this.ekycRepo.findOne({ where: { userId } });

    const activeListingCount = await this.productRepo.count({
      where: { sellerId: userId, status: 'Available' },
    });

    const soldCount = await this.productRepo.count({
      where: { sellerId: userId, status: 'Sold' },
    });

    const boughtCount = await this.orderRepo.count({
      where: { buyerId: userId, orderStatus: 'Completed' },
    });

    const reviewRows = await this.reviewRepo.find({
      where: { revieweeId: userId },
    });
    const reviewCount = reviewRows.length;
    const averageRating =
      reviewCount > 0
        ? reviewRows.reduce((s, r) => s + r.rating, 0) / reviewCount
        : 0;

    const [followerCount, followingCount, isFollowing] = await Promise.all([
      this.followsService.followerCount(userId),
      this.followsService.followingCount(userId),
      viewerId != null
        ? this.followsService.isFollowing(viewerId, userId)
        : Promise.resolve(false),
    ]);

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
      activeListingCount,
      soldCount,
      boughtCount,
      reviewCount,
      averageRating: Math.round(averageRating * 10) / 10,
      followerCount,
      followingCount,
      isFollowing,
    };
  }

  getSoldProducts(userId: number) {
    return this.ordersService.getSoldProducts(userId);
  }

  getUserListings(userId: number) {
    return this.ordersService.getSoldProducts(userId);
  }

  async updateProfile(
    userId: number,
    dto: UpdateProfileDto,
  ): Promise<UserProfileDto> {
    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) throw new NotFoundException('Người dùng không tồn tại');

    if (dto.phoneNumber != null) {
      const phone = dto.phoneNumber.trim();
      const existing = await this.userRepo.findOne({
        where: { phoneNumber: phone },
      });
      if (existing && Number(existing.userId) !== userId) {
        throw new BadRequestException('Số điện thoại đã được sử dụng');
      }
      user.phoneNumber = phone;
    }

    if (dto.displayName != null) {
      user.displayName = dto.displayName.trim() || null;
    }
    if (dto.location != null) {
      user.location = dto.location.trim() || null;
    }
    if (dto.avatarUrl !== undefined) {
      const url = dto.avatarUrl?.trim() ?? '';
      user.avatarUrl = url.length === 0 ? null : url;
    }

    await this.userRepo.save(user);
    return this.getProfile(userId);
  }

  /** Cập nhật ảnh đại diện từ file đã upload (lưu đường dẫn /uploads/avatars/...). */
  async updateAvatarFile(
    userId: number,
    filename: string,
  ): Promise<UserProfileDto> {
    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) throw new NotFoundException('Người dùng không tồn tại');
    user.avatarUrl = toPublicAvatarPath(filename);
    await this.userRepo.save(user);
    return this.getProfile(userId);
  }

  private maskIdNumber(id: string | null): string | null {
    if (!id) return null;
    if (id.length <= 6) return id;
    return id.slice(0, 6) + 'x'.repeat(id.length - 6);
  }
}
