import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../entities/user.entity';
import { Score, RankLevel } from '../entities/score.entity';
import { PointLog } from '../entities/point-log.entity';
import { Report } from '../entities/report.entity';
import { EkycProfile } from '../entities/ekyc-profile.entity';
import { Order } from '../entities/order.entity';
import { Product } from '../entities/product.entity';

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(Score) private readonly scoreRepo: Repository<Score>,
    @InjectRepository(PointLog) private readonly pointLogRepo: Repository<PointLog>,
    @InjectRepository(Report) private readonly reportRepo: Repository<Report>,
    @InjectRepository(EkycProfile) private readonly ekycRepo: Repository<EkycProfile>,
    @InjectRepository(Order) private readonly orderRepo: Repository<Order>,
    @InjectRepository(Product) private readonly productRepo: Repository<Product>,
  ) {}

  async getStats() {
    const [
      totalUsers,
      verifiedUsers,
      openReports,
      lockedUsers,
      pendingEkyc,
      totalProducts,
      totalOrders,
      completedOrders,
    ] = await Promise.all([
      this.userRepo.count({ where: { isAdmin: false } }),
      this.userRepo.count({ where: { kycStatus: 'Verified', isAdmin: false } }),
      this.reportRepo.count({ where: { status: 'Open' } }),
      this.userRepo.count({
        where: [{ accountStatus: 'Locked' }, { accountStatus: 'Banned' }],
      }),
      this.userRepo.count({ where: { kycStatus: 'Pending', isAdmin: false } }),
      this.productRepo.count(),
      this.orderRepo.count(),
      this.orderRepo.count({ where: { orderStatus: 'Completed' } }),
    ]);
    const ekycTrend = await this.getEkycTrend();
    return {
      totalUsers,
      verifiedUsers,
      openReports,
      lockedUsers,
      pendingEkyc,
      totalProducts,
      totalOrders,
      completedOrders,
      ekycTrend,
    };
  }

  /** Số hồ sơ eKYC được duyệt trong 7 ngày gần nhất (cho biểu đồ admin). */
  private async getEkycTrend(): Promise<{ label: string; count: number }[]> {
    try {
      const raw: { dayDate: string; cnt: string }[] = await this.ekycRepo.query(`
        SELECT CAST(verified_at AS date) AS dayDate, COUNT(*) AS cnt
        FROM [Identity].[eKYC_Profiles]
        WHERE verified_at >= DATEADD(day, -6, CAST(GETDATE() AS date))
          AND verified_at IS NOT NULL
        GROUP BY CAST(verified_at AS date)
      `);
      const counts = new Map<string, number>();
      for (const row of raw) {
        const key = String(row.dayDate).slice(0, 10);
        counts.set(key, parseInt(row.cnt, 10) || 0);
      }
      const vnDays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
      const trend: { label: string; count: number }[] = [];
      for (let i = 6; i >= 0; i--) {
        const d = new Date();
        d.setHours(0, 0, 0, 0);
        d.setDate(d.getDate() - i);
        const key = d.toISOString().slice(0, 10);
        trend.push({ label: vnDays[d.getDay()], count: counts.get(key) ?? 0 });
      }
      return trend;
    } catch {
      return [
        { label: 'T2', count: 0 },
        { label: 'T3', count: 0 },
        { label: 'T4', count: 0 },
        { label: 'T5', count: 0 },
        { label: 'T6', count: 0 },
        { label: 'T7', count: 0 },
        { label: 'CN', count: 0 },
      ];
    }
  }

  async getUsers() {
    const users = await this.userRepo.find({
      where: { isAdmin: false },
      order: { userId: 'DESC' },
      take: 50,
    });

    const rows: Record<string, unknown>[] = [];
    for (const u of users) {
      const score = await this.scoreRepo.findOne({
        where: { userId: u.userId },
      });
      const orders = await this.orderRepo.count({
        where: { buyerId: u.userId, orderStatus: 'Completed' },
      });
      rows.push({
        userId: Number(u.userId),
        email: u.email,
        displayName: u.displayName,
        kycStatus: u.kycStatus,
        accountStatus: u.accountStatus,
        trustScore: score?.currentPoint ?? 500,
        rankLevel: score?.rankLevel ?? 'Bronze',
        orders,
      });
    }
    return rows;
  }

  /**
   * Xếp hạng người dùng theo điểm tín nhiệm.
   * - Người đã xác thực eKYC luôn xếp trên người chưa xác thực (chưa quét xếp chót).
   * - Trong cùng nhóm: sắp theo điểm tín nhiệm (desc mặc định, asc khi đảo chiều).
   */
  async getUserRanking(order: 'desc' | 'asc' = 'desc') {
    const users = await this.userRepo.find({
      where: { isAdmin: false },
    });

    const rows: Record<string, unknown>[] = [];
    for (const u of users) {
      const score = await this.scoreRepo.findOne({
        where: { userId: u.userId },
      });
      const completedOrders = await this.orderRepo.count({
        where: { buyerId: u.userId, orderStatus: 'Completed' },
      });
      const verified = u.kycStatus === 'Verified';
      rows.push({
        userId: Number(u.userId),
        email: u.email,
        displayName: u.displayName,
        kycStatus: u.kycStatus,
        accountStatus: u.accountStatus,
        trustScore: score?.currentPoint ?? 500,
        rankLevel: score?.rankLevel ?? 'Bronze',
        orders: completedOrders,
        verified,
      });
    }

    const dir = order === 'asc' ? 1 : -1;
    rows.sort((a, b) => {
      // eKYC verified luôn ưu tiên lên trên (chưa quét xếp chót).
      const av = a.verified ? 1 : 0;
      const bv = b.verified ? 1 : 0;
      if (av !== bv) return bv - av;
      const diff =
        (a.trustScore as number) - (b.trustScore as number);
      if (diff !== 0) return dir * diff;
      return (a.displayName as string ?? '').localeCompare(
        (b.displayName as string) ?? '',
      );
    });

    return rows.map((r, i) => ({ ...r, rank: i + 1 }));
  }

  async getReports() {
    const rows = await this.reportRepo.find({
      where: { status: 'Open' },
      relations: ['reported', 'reporter', 'product'],
      order: { createdAt: 'DESC' },
      take: 50,
    });
    const scoreCache = new Map<number, number>();
    const result: Record<string, unknown>[] = [];
    for (const r of rows) {
      const uid = Number(r.reportedId);
      if (!scoreCache.has(uid)) {
        const s = await this.scoreRepo.findOne({ where: { userId: uid } });
        scoreCache.set(uid, s?.currentPoint ?? 0);
      }
      result.push({
        reportId: Number(r.reportId),
        reportedUserId: uid,
        reporterName:
          r.reporter?.displayName ?? r.reporter?.email ?? 'Ẩn danh',
        name: r.reported?.displayName ?? r.reported?.email ?? 'User',
        reason: r.reason,
        severity: r.severity,
        score: scoreCache.get(uid),
        productId: r.productId ? Number(r.productId) : null,
        productTitle: r.product?.title ?? null,
        reportType: r.productId ? 'product' : 'user',
        createdAt: r.createdAt?.toISOString?.() ?? null,
      });
    }
    return result;
  }

  async hideReportedProduct(productId: number) {
    const product = await this.productRepo.findOne({ where: { productId } });
    if (!product) throw new NotFoundException('Sản phẩm không tồn tại');
    product.status = 'Hidden';
    await this.productRepo.save(product);
    return { productId: Number(productId), status: 'Hidden' };
  }

  async getPendingEkyc() {
    const users = await this.userRepo.find({
      where: { kycStatus: 'Pending' },
      take: 50,
    });
    const result: Record<string, unknown>[] = [];
    for (const u of users) {
      const profile = await this.ekycRepo.findOne({ where: { userId: u.userId } });
      result.push({
        userId: Number(u.userId),
        displayName: u.displayName ?? u.email,
        fullName: profile?.fullName ?? u.displayName ?? '',
        idNumber: profile?.idNumber ?? '',
        hasProfile: !!profile,
      });
    }
    return result;
  }

  async getLockedUsers() {
    const users = await this.userRepo.find({
      where: [{ accountStatus: 'Locked' }, { accountStatus: 'Banned' }],
    });
    return users.map((u) => ({
      userId: Number(u.userId),
      displayName: u.displayName ?? u.email,
      accountStatus: u.accountStatus,
      lockReason: u.lockReason ?? '',
    }));
  }

  async approveEkyc(userId: number) {
    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) throw new NotFoundException('User không tồn tại');

    let profile = await this.ekycRepo.findOne({ where: { userId } });
    if (!profile) {
      // Seed/demo: user Pending nhưng chưa có dòng eKYC_Profiles
      profile = this.ekycRepo.create({
        userId,
        fullName: user.displayName,
        submittedAt: new Date(),
      });
    }

    profile.verifiedAt = new Date();
    profile.rejectionReason = null;
    await this.ekycRepo.save(profile);

    user.kycStatus = 'Verified';
    await this.userRepo.save(user);
  }

  async rejectEkyc(userId: number, reason: string) {
    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) throw new NotFoundException('User không tồn tại');
    const profile = await this.ekycRepo.findOne({ where: { userId } });

    user.kycStatus = 'Rejected';
    await this.userRepo.save(user);

    if (profile) {
      profile.rejectionReason = reason;
      profile.verifiedAt = null;
      await this.ekycRepo.save(profile);
    }
  }

  async lockUser(userId: number, reason: string) {
    const user = await this.requireNonAdminUser(userId);
    user.accountStatus = 'Locked';
    user.lockReason = reason;
    user.lockedAt = new Date();
    await this.userRepo.save(user);
  }

  async banUser(userId: number, reason: string) {
    const user = await this.requireNonAdminUser(userId);
    user.accountStatus = 'Banned';
    user.lockReason = reason;
    user.lockedAt = new Date();
    await this.userRepo.save(user);
  }

  async punishUser(userId: number, points: number, reason: string) {
    const user = await this.requireNonAdminUser(userId);
    if (points <= 0 || points > 500) {
      throw new BadRequestException('Số điểm trừ phải từ 1 đến 500');
    }

    let score = await this.scoreRepo.findOne({ where: { userId } });
    if (!score) {
      score = this.scoreRepo.create({
        userId,
        currentPoint: 500,
        rankLevel: 'Bronze',
      });
    }

    const next = Math.max(0, score.currentPoint - points);
    score.currentPoint = next;
    score.rankLevel = this.rankFor(next);
    await this.scoreRepo.save(score);
    await this.pointLogRepo.save({
      userId,
      delta: -points,
      reasonCode: 'ADMIN_PENALTY',
      note: reason,
    });

    return {
      userId: Number(user.userId),
      trustScore: next,
      rankLevel: score.rankLevel,
      deducted: points,
    };
  }

  async deleteUser(userId: number) {
    const user = await this.requireNonAdminUser(userId);

    const productCount = await this.productRepo.count({
      where: { sellerId: userId },
    });
    const orderCount = await this.orderRepo.count({
      where: { buyerId: userId },
    });
    if (productCount > 0 || orderCount > 0) {
      throw new BadRequestException(
        'Không thể xóa: người dùng còn sản phẩm hoặc đơn hàng. Hãy khóa/cấm thay thế.',
      );
    }

    await this.ekycRepo.delete({ userId });
    await this.scoreRepo.delete({ userId });
    await this.pointLogRepo.delete({ userId });
    await this.userRepo.delete({ userId });
  }

  async unlockUser(userId: number) {
    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) throw new NotFoundException('User không tồn tại');
    user.accountStatus = 'Active';
    user.lockReason = null;
    user.lockedAt = null;
    await this.userRepo.save(user);
  }

  async resolveReport(reportId: number, status: string) {
    const report = await this.reportRepo.findOne({ where: { reportId } });
    if (!report) throw new NotFoundException('Báo cáo không tồn tại');
    report.status = status;
    report.resolvedAt = new Date();
    await this.reportRepo.save(report);
  }

  private async requireNonAdminUser(userId: number): Promise<User> {
    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) throw new NotFoundException('User không tồn tại');
    if (user.isAdmin) {
      throw new BadRequestException('Không thể thao tác trên tài khoản admin');
    }
    return user;
  }

  private rankFor(point: number): RankLevel {
    if (point >= 850) return 'Diamond';
    if (point >= 600) return 'Gold';
    if (point >= 300) return 'Silver';
    return 'Bronze';
  }
}
