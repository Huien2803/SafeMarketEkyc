import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../entities/user.entity';
import { Score } from '../entities/score.entity';
import { Report } from '../entities/report.entity';
import { EkycProfile } from '../entities/ekyc-profile.entity';
import { Order } from '../entities/order.entity';
import { Product } from '../entities/product.entity';

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(Score) private readonly scoreRepo: Repository<Score>,
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

  async getReports() {
    const rows = await this.reportRepo.find({
      where: { status: 'Open' },
      relations: ['reported'],
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
        name: r.reported?.displayName ?? r.reported?.email ?? 'User',
        reason: r.reason,
        severity: r.severity,
        score: scoreCache.get(uid),
      });
    }
    return result;
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
    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) throw new NotFoundException('User không tồn tại');
    user.accountStatus = 'Locked';
    user.lockReason = reason;
    user.lockedAt = new Date();
    await this.userRepo.save(user);
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
}
