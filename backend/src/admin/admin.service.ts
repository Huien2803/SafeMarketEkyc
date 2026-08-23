import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { existsSync, readFileSync } from 'fs';
import { join } from 'path';
import { User } from '../entities/user.entity';
import { Score, RankLevel } from '../entities/score.entity';
import { PointLog } from '../entities/point-log.entity';
import { Report } from '../entities/report.entity';
import { EkycProfile } from '../entities/ekyc-profile.entity';
import { Order } from '../entities/order.entity';
import { Product } from '../entities/product.entity';
import { Payment } from '../entities/payment.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import { WalletService } from '../wallet/wallet.service';
import { ReputationService } from '../reputation/reputation.service';
import { OcrProviderService } from '../ekyc/ocr-provider.service';

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(Score) private readonly scoreRepo: Repository<Score>,
    @InjectRepository(PointLog) private readonly pointLogRepo: Repository<PointLog>,
    @InjectRepository(Report) private readonly reportRepo: Repository<Report>,
    @InjectRepository(EkycProfile) private readonly ekycRepo: Repository<EkycProfile>,
    @InjectRepository(Order) private readonly orderRepo: Repository<Order>,
    @InjectRepository(Product) private readonly productRepo: Repository<Product>,
    @InjectRepository(Payment) private readonly paymentRepo: Repository<Payment>,
    private readonly notificationsService: NotificationsService,
    private readonly paymentsService: PaymentsService,
    private readonly walletService: WalletService,
    private readonly reputationService: ReputationService,
    private readonly ocr: OcrProviderService,
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
    const vnDays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    const emptyTrend = (): { label: string; count: number }[] => {
      const trend: { label: string; count: number }[] = [];
      for (let i = 6; i >= 0; i--) {
        const d = new Date();
        d.setHours(0, 0, 0, 0);
        d.setDate(d.getDate() - i);
        trend.push({ label: vnDays[d.getDay()], count: 0 });
      }
      return trend;
    };

    try {
      // Gom theo offset ngày trên SQL — tránh lệch timezone và String(Date).slice(0,10)
      // (mssql trả Date object → "Thu Aug 20..." không khớp "2026-08-20").
      const raw: { offsetDays: number | string; cnt: number | string }[] =
        await this.ekycRepo.query(`
          WITH days AS (
            SELECT n AS offsetDays,
                   CAST(DATEADD(day, -n, CAST(GETDATE() AS date)) AS date) AS dayDate
            FROM (VALUES (0),(1),(2),(3),(4),(5),(6)) AS t(n)
          )
          SELECT
            d.offsetDays,
            COUNT(p.kyc_id) AS cnt
          FROM days d
          LEFT JOIN [Identity].[eKYC_Profiles] p
            ON p.verified_at IS NOT NULL
           AND CAST(p.verified_at AS date) = d.dayDate
          GROUP BY d.offsetDays
          ORDER BY d.offsetDays DESC
        `);

      const byOffset = new Map<number, number>();
      for (const row of raw) {
        byOffset.set(
          Number(row.offsetDays),
          parseInt(String(row.cnt), 10) || 0,
        );
      }

      const trend: { label: string; count: number }[] = [];
      for (let i = 6; i >= 0; i--) {
        const d = new Date();
        d.setHours(0, 0, 0, 0);
        d.setDate(d.getDate() - i);
        trend.push({
          label: vnDays[d.getDay()],
          count: byOffset.get(i) ?? 0,
        });
      }
      return trend;
    } catch (err) {
      this.logger.warn(`getEkycTrend failed: ${err}`);
      return emptyTrend();
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
        lockedUntil: u.lockedUntil ? u.lockedUntil.toISOString() : null,
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
      const dob = profile?.dob
        ? (profile.dob instanceof Date
            ? profile.dob.toISOString().slice(0, 10)
            : String(profile.dob).slice(0, 10))
        : null;
      const faceCheck = await this.compareStoredFace(profile);
      result.push({
        userId: Number(u.userId),
        displayName: u.displayName ?? u.email,
        email: u.email,
        fullName: profile?.fullName ?? u.displayName ?? '',
        idNumber: profile?.idNumber ?? '',
        dob,
        address: profile?.address ?? '',
        idFrontUrl: profile?.idFrontUrl ?? null,
        idBackUrl: profile?.idBackUrl ?? null,
        faceUrl: profile?.faceVideoUrl ?? null,
        submittedAt: profile?.submittedAt
          ? profile.submittedAt.toISOString()
          : null,
        hasProfile: !!profile,
        faceMatchIsMatch: faceCheck?.isMatch ?? null,
        faceSimilarity: faceCheck?.similarity ?? null,
        faceMatchMessage: faceCheck?.message ?? null,
      });
    }
    return result;
  }

  /** So khớp lại ảnh CCCD mặt trước với selfie đã lưu — dùng khi duyệt hồ sơ. */
  private async compareStoredFace(profile: EkycProfile | null): Promise<{
    isMatch: boolean;
    similarity: number;
    message: string;
  } | null> {
    if (!profile?.idFrontUrl || !profile?.faceVideoUrl) return null;
    const idCard = this.readUploadAsMulter(profile.idFrontUrl, 'id.jpg');
    const selfie = this.readUploadAsMulter(profile.faceVideoUrl, 'selfie.jpg');
    if (!idCard || !selfie) return null;
    try {
      return await this.ocr.matchFace(idCard, selfie);
    } catch (err) {
      this.logger.warn(
        `Admin face-check user ${profile.userId}: ${(err as Error).message}`,
      );
      return null;
    }
  }

  private readUploadAsMulter(
    url: string,
    filename: string,
  ): Express.Multer.File | null {
    const rel = url.replace(/^\/+/, '');
    const full = join(process.cwd(), ...rel.split('/').filter(Boolean));
    if (!existsSync(full)) {
      this.logger.warn(`Không thấy file eKYC: ${full}`);
      return null;
    }
    const buffer = readFileSync(full);
    return {
      fieldname: 'file',
      originalname: filename,
      encoding: '7bit',
      mimetype: 'image/jpeg',
      size: buffer.length,
      buffer,
      destination: '',
      filename,
      path: full,
      stream: undefined as any,
    };
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
      lockedUntil: u.lockedUntil ? u.lockedUntil.toISOString() : null,
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

    const faceCheck = await this.compareStoredFace(profile);
    if (faceCheck && !faceCheck.isMatch) {
      throw new BadRequestException(
        faceCheck.message ||
          'Khuôn mặt không khớp ảnh CCCD — không được phê duyệt. Hãy từ chối hồ sơ.',
      );
    }

    profile.verifiedAt = new Date();
    profile.rejectionReason = null;
    await this.ekycRepo.save(profile);

    user.kycStatus = 'Verified';
    await this.userRepo.save(user);

    // Thưởng điểm tín nhiệm khi eKYC được duyệt (một lần / user).
    await this.reputationService.adjustPoints(
      userId,
      50,
      'EKYC_VERIFIED',
      `Xác thực eKYC thành công [EKYC-${userId}]`,
      { idempotentKey: `EKYC-${userId}` },
    );
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

  /** Cảnh cáo người dùng: gửi thông báo + ghi nhật ký, không phạt điểm. */
  async warnUser(userId: number, reason: string) {
    const user = await this.requireNonAdminUser(userId);
    await this.pointLogRepo.save({
      userId,
      delta: 0,
      reasonCode: 'ADMIN_WARNING',
      note: reason,
    });
    await this.notify(userId, {
      title: 'Cảnh cáo từ quản trị viên',
      body: `Bạn nhận được một cảnh cáo: ${reason}. Vui lòng tuân thủ quy định để tránh bị xử lý nặng hơn.`,
      payload: { action: 'WARN', reason },
    });
    return { userId: Number(user.userId), action: 'WARN' };
  }

  async lockUser(userId: number, reason: string) {
    const user = await this.requireNonAdminUser(userId);
    user.accountStatus = 'Locked';
    user.lockReason = reason;
    user.lockedAt = new Date();
    user.lockedUntil = null;
    await this.userRepo.save(user);
    await this.notify(userId, {
      title: 'Tài khoản bị khóa',
      body: `Tài khoản của bạn đã bị khóa vô thời hạn. Lý do: ${reason}.`,
      payload: { action: 'LOCK', reason },
    });
  }

  /** Đình chỉ tạm thời: khóa có thời hạn, hệ thống tự mở khi hết hạn. */
  async suspendUser(userId: number, days: number, reason: string) {
    const user = await this.requireNonAdminUser(userId);
    if (!Number.isFinite(days) || days < 1 || days > 365) {
      throw new BadRequestException('Số ngày đình chỉ phải từ 1 đến 365');
    }
    const until = new Date();
    until.setDate(until.getDate() + Math.floor(days));

    user.accountStatus = 'Locked';
    user.lockReason = reason;
    user.lockedAt = new Date();
    user.lockedUntil = until;
    await this.userRepo.save(user);

    await this.notify(userId, {
      title: 'Tài khoản bị đình chỉ tạm thời',
      body: `Tài khoản của bạn bị đình chỉ ${Math.floor(days)} ngày (đến ${this.formatVn(until)}). Lý do: ${reason}.`,
      payload: {
        action: 'SUSPEND',
        reason,
        days: Math.floor(days),
        lockedUntil: until.toISOString(),
      },
    });

    return {
      userId: Number(user.userId),
      action: 'SUSPEND',
      lockedUntil: until.toISOString(),
      days: Math.floor(days),
    };
  }

  async banUser(userId: number, reason: string) {
    const user = await this.requireNonAdminUser(userId);
    user.accountStatus = 'Banned';
    user.lockReason = reason;
    user.lockedAt = new Date();
    user.lockedUntil = null;
    await this.userRepo.save(user);
    await this.notify(userId, {
      title: 'Tài khoản bị cấm vĩnh viễn',
      body: `Tài khoản của bạn đã bị cấm vĩnh viễn. Lý do: ${reason}.`,
      payload: { action: 'BAN', reason },
    });
  }

  async punishUser(userId: number, points: number, reason: string) {
    const user = await this.requireNonAdminUser(userId);
    if (points <= 0 || points > 500) {
      throw new BadRequestException('Số điểm trừ phải từ 1 đến 500');
    }

    // Chỉ ghi Point_Logs — trigger trg_UpdateScoreAndRank sẽ trừ đúng 1 lần.
    // (Trước đây vừa save Scores vừa insert log → bị trừ gấp đôi.)
    let score = await this.scoreRepo.findOne({ where: { userId } });
    if (!score) {
      score = await this.scoreRepo.save(
        this.scoreRepo.create({
          userId,
          currentPoint: 500,
          rankLevel: 'Silver',
        }),
      );
    }

    await this.pointLogRepo.save({
      userId,
      delta: -points,
      reasonCode: 'ADMIN_PENALTY',
      note: reason,
    });

    score = (await this.scoreRepo.findOne({ where: { userId } })) ?? score;
    const next = score.currentPoint;

    await this.notify(userId, {
      title: 'Bị trừ điểm tín nhiệm',
      body: `Bạn bị trừ ${points} điểm tín nhiệm (còn ${next} điểm, hạng ${score.rankLevel}). Lý do: ${reason}.`,
      payload: {
        action: 'PUNISH',
        reason,
        deducted: points,
        trustScore: next,
        rankLevel: score.rankLevel,
      },
    });

    return {
      userId: Number(user.userId),
      trustScore: next,
      rankLevel: score.rankLevel,
      deducted: points,
    };
  }

  /**
   * Xóa tài khoản (soft-delete an toàn).
   * DB gốc chỉ cho Active/Locked/Banned — phải mở constraint cho 'Deleted' trước khi lưu.
   * Không xóa cứng vì nhiều FK (Point_Logs, Orders, Reports...) sẽ gây 500.
   */
  async deleteUser(userId: number) {
    const user = await this.requireNonAdminUser(userId);
    if (user.accountStatus === 'Deleted') {
      return { mode: 'soft' as const, userId: Number(userId), alreadyDeleted: true };
    }

    await this.ensureAccountStatusAllowsDeleted();

    const productCount = await this.productRepo.count({
      where: { sellerId: userId },
    });

    if (productCount > 0) {
      await this.productRepo
        .createQueryBuilder()
        .update(Product)
        .set({ status: 'Hidden' })
        .where('seller_id = :userId', { userId })
        .execute();
    }

    // Thu hồi phiên đăng nhập (bảng có thể chưa tồn tại trên DB cũ).
    await this.safeExec(
      `DELETE FROM [Identity].[RefreshTokens] WHERE [user_id] = @0`,
      [userId],
    );

    const anonId = `deleted_${userId}`;
    const phone = `d${userId}`.slice(0, 15);

    user.accountStatus = 'Deleted';
    user.displayName = 'Tài khoản đã xóa';
    user.avatarUrl = null;
    user.location = null;
    user.email = `${anonId}@deleted.local`;
    user.phoneNumber = phone;
    user.passwordHash = 'ACCOUNT_DELETED';
    user.lockReason = 'Tài khoản đã bị quản trị viên xóa';
    user.lockedAt = new Date();
    user.lockedUntil = null;
    user.kycStatus = 'Unverified';

    try {
      await this.userRepo.save(user);
    } catch (err) {
      // Fallback nếu constraint vẫn chưa nhận 'Deleted'
      user.accountStatus = 'Banned';
      user.lockReason =
        '[DELETED] Tài khoản đã bị quản trị viên xóa (không thể đăng nhập)';
      await this.userRepo.save(user);
    }

    try {
      await this.ekycRepo.delete({ userId });
    } catch {
      // Không chặn xóa tài khoản nếu eKYC lỗi
    }

    return {
      mode: 'soft' as const,
      userId: Number(userId),
      hiddenProducts: productCount,
    };
  }

  /** Mở CHECK account_status để cho phép giá trị Deleted (một lần / process). */
  private accountStatusPatched = false;
  private async ensureAccountStatusAllowsDeleted(): Promise<void> {
    if (this.accountStatusPatched) return;
    try {
      await this.userRepo.query(`
        IF EXISTS (
          SELECT 1 FROM sys.check_constraints
          WHERE name = N'CK_Users_AccountStatus'
            AND parent_object_id = OBJECT_ID(N'[Identity].[Users]')
        )
        BEGIN
          ALTER TABLE [Identity].[Users] DROP CONSTRAINT CK_Users_AccountStatus;
        END
      `);
      await this.userRepo.query(`
        IF NOT EXISTS (
          SELECT 1 FROM sys.check_constraints
          WHERE name = N'CK_Users_AccountStatus'
            AND parent_object_id = OBJECT_ID(N'[Identity].[Users]')
        )
        BEGIN
          ALTER TABLE [Identity].[Users] WITH NOCHECK ADD CONSTRAINT CK_Users_AccountStatus
            CHECK ([account_status] IN ('Active','Locked','Banned','Deleted'));
        END
      `);
    } catch {
      // DB có thể đã patch hoặc không đủ quyền — soft delete sẽ fallback Banned
    }
    this.accountStatusPatched = true;
  }

  private async safeExec(sql: string, params: unknown[] = []): Promise<void> {
    try {
      await this.userRepo.query(sql, params);
    } catch {
      // bảng/cột có thể chưa có trên môi trường demo
    }
  }

  async unlockUser(userId: number) {
    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) throw new NotFoundException('User không tồn tại');
    if (user.accountStatus === 'Deleted') {
      throw new BadRequestException(
        'Tài khoản đã xóa, không thể khôi phục từ đây',
      );
    }
    user.accountStatus = 'Active';
    user.lockReason = null;
    user.lockedAt = null;
    user.lockedUntil = null;
    await this.userRepo.save(user);
    await this.notify(userId, {
      title: 'Tài khoản đã được mở khóa',
      body: 'Quản trị viên đã mở khóa tài khoản của bạn. Bạn có thể tiếp tục sử dụng bình thường.',
      payload: { action: 'UNLOCK' },
    });
  }

  /** Gửi thông báo kỷ luật, không để lỗi thông báo làm hỏng thao tác chính. */
  private async notify(
    userId: number,
    input: { title: string; body: string; payload?: Record<string, unknown> },
  ): Promise<void> {
    try {
      await this.notificationsService.notifyAdminAction(userId, input);
    } catch {
      // Bỏ qua: thông báo là phụ, không chặn hành động quản trị.
    }
  }

  private formatVn(d: Date): string {
    return d.toLocaleString('vi-VN', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  async resolveReport(reportId: number, status: string) {
    const report = await this.reportRepo.findOne({ where: { reportId } });
    if (!report) throw new NotFoundException('Báo cáo không tồn tại');
    report.status = status;
    report.resolvedAt = new Date();
    await this.reportRepo.save(report);
  }

  /** Danh sách đơn đang khiếu nại chờ admin xử lý. */
  async getDisputes() {
    const rows = await this.orderRepo.find({
      where: { orderStatus: 'Disputed' },
      relations: ['buyer', 'product', 'product.seller'],
      order: { createdAt: 'DESC' },
      take: 50,
    });
    const result: Record<string, unknown>[] = [];
    for (const o of rows) {
      const product = o.product;
      const seller = product?.seller;
      const payment = await this.paymentRepo.findOne({
        where: { orderId: o.orderId },
      });
      result.push({
        orderId: Number(o.orderId),
        orderStatus: o.orderStatus,
        disputeType: o.disputeType,
        disputeNote: o.disputeNote,
        paymentMethod: o.paymentMethod,
        deliveryMethod: o.deliveryMethod,
        buyerId: Number(o.buyerId),
        buyerName: o.buyer?.displayName ?? o.buyer?.email ?? '',
        sellerId: seller ? Number(seller.userId) : null,
        sellerName: seller?.displayName ?? seller?.email ?? '',
        productId: product ? Number(product.productId) : null,
        productTitle: product?.title ?? '',
        productPrice: product ? Number(product.price) : 0,
        escrowStatus: payment?.escrowStatus ?? null,
        escrowAmount: payment ? Number(payment.amount) : 0,
        createdAt: o.createdAt?.toISOString?.() ?? null,
      });
    }
    return result;
  }

  /**
   * Xử lý khiếu nại:
   *  - REFUND_BUYER: hoàn escrow cho người mua, hủy đơn, mở lại sản phẩm, trừ điểm người bán (mặc định).
   *  - RELEASE_SELLER: giải ngân cho người bán, hoàn tất đơn, trừ điểm người mua (mặc định).
   */
  async resolveDispute(
    orderId: number,
    decision: 'REFUND_BUYER' | 'RELEASE_SELLER',
    opts?: {
      note?: string;
      penaltyPoints?: number;
      skipPenalty?: boolean;
    },
  ) {
    if (decision !== 'REFUND_BUYER' && decision !== 'RELEASE_SELLER') {
      throw new BadRequestException(
        'decision phải là REFUND_BUYER hoặc RELEASE_SELLER',
      );
    }
    const order = await this.orderRepo.findOne({
      where: { orderId },
      relations: ['product'],
    });
    if (!order) throw new NotFoundException('Đơn hàng không tồn tại');
    if (order.orderStatus !== 'Disputed') {
      throw new BadRequestException('Đơn không ở trạng thái khiếu nại');
    }

    const product = order.product;
    if (!product) throw new NotFoundException('Sản phẩm không tồn tại');
    const sellerId = Number(product.sellerId);
    const buyerId = Number(order.buyerId);
    const note = opts?.note?.trim() || '';
    const penaltyPoints = Math.min(
      200,
      Math.max(0, Number(opts?.penaltyPoints ?? 50)),
    );
    const skipPenalty = opts?.skipPenalty === true;

    if (decision === 'REFUND_BUYER') {
      const payment = await this.paymentRepo.findOne({ where: { orderId } });
      if (payment?.paymentMethod === 'ONLINE_ESCROW') {
        await this.paymentsService.refundEscrow(orderId);
      } else if (payment && payment.escrowStatus === 'Holding') {
        payment.escrowStatus = 'Refunded';
        await this.paymentRepo.save(payment);
      }

      order.orderStatus = 'Cancelled';
      order.cancelReason =
        note ||
        `Admin hoàn tiền người mua (khiếu nại: ${order.disputeType ?? ''})`;
      await this.orderRepo.save(order);

      if (product.status !== 'Sold') {
        product.status = 'Available';
        await this.productRepo.save(product);
      }

      if (!skipPenalty && penaltyPoints > 0) {
        await this.reputationService.adjustPoints(
          sellerId,
          -penaltyPoints,
          'DISPUTE_PENALTY',
          `Khiếu nại đơn #${orderId}: hoàn tiền người mua. ${note}`.slice(0, 255),
        );
      }

      await this.notify(buyerId, {
        title: 'Khiếu nại được chấp nhận',
        body: `Đơn #${orderId}: admin quyết định hoàn tiền cho bạn.${note ? ` Ghi chú: ${note}` : ''}`,
        payload: { action: 'DISPUTE_RESOLVED', orderId, decision },
      });
      await this.notify(sellerId, {
        title: 'Khiếu nại: hoàn tiền người mua',
        body: `Đơn #${orderId}: admin hoàn tiền cho người mua.${
          !skipPenalty && penaltyPoints > 0
            ? ` Bạn bị trừ ${penaltyPoints} điểm tín nhiệm.`
            : ''
        }${note ? ` Ghi chú: ${note}` : ''}`,
        payload: {
          action: 'DISPUTE_RESOLVED',
          orderId,
          decision,
          penaltyPoints: skipPenalty ? 0 : penaltyPoints,
        },
      });

      return {
        orderId,
        decision,
        orderStatus: 'Cancelled',
        escrow: 'Refunded',
        penaltyUserId: sellerId,
        penaltyPoints: skipPenalty ? 0 : penaltyPoints,
      };
    }

    // RELEASE_SELLER
    const payment = await this.paymentRepo.findOne({ where: { orderId } });
    if (payment?.paymentMethod === 'ONLINE_ESCROW') {
      await this.paymentsService.releaseEscrow(orderId);
      await this.walletService.creditSale(
        sellerId,
        Number(payment.amount),
        `ORDER-${orderId}`,
        `Giải ngân sau khiếu nại đơn #${orderId}`,
      );
    } else if (payment && payment.escrowStatus === 'Holding') {
      payment.escrowStatus = 'Released';
      await this.paymentRepo.save(payment);
    }

    order.orderStatus = 'Completed';
    order.completedAt = new Date();
    order.cancelReason = null;
    await this.orderRepo.save(order);

    product.status = 'Sold';
    await this.productRepo.save(product);

    if (!skipPenalty && penaltyPoints > 0) {
      await this.reputationService.adjustPoints(
        buyerId,
        -penaltyPoints,
        'DISPUTE_PENALTY',
        `Khiếu nại đơn #${orderId}: giải ngân người bán. ${note}`.slice(0, 255),
      );
    }

    // Thưởng người bán (không thưởng người mua khi họ thua khiếu nại).
    await this.reputationService.adjustPoints(
      sellerId,
      20,
      'ORDER_COMPLETE',
      `Hoàn tất đơn #${orderId} sau khiếu nại [ORDER-${orderId}]`,
      { idempotentKey: `ORDER-${orderId}` },
    );

    await this.notify(sellerId, {
      title: 'Khiếu nại: giải ngân cho bạn',
      body: `Đơn #${orderId}: admin giải ngân / xác nhận giao dịch thành công.${note ? ` Ghi chú: ${note}` : ''}`,
      payload: { action: 'DISPUTE_RESOLVED', orderId, decision },
    });
    await this.notify(buyerId, {
      title: 'Khiếu nại bị từ chối',
      body: `Đơn #${orderId}: admin quyết định giải ngân cho người bán.${
        !skipPenalty && penaltyPoints > 0
          ? ` Bạn bị trừ ${penaltyPoints} điểm tín nhiệm.`
          : ''
      }${note ? ` Ghi chú: ${note}` : ''}`,
      payload: {
        action: 'DISPUTE_RESOLVED',
        orderId,
        decision,
        penaltyPoints: skipPenalty ? 0 : penaltyPoints,
      },
    });

    return {
      orderId,
      decision,
      orderStatus: 'Completed',
      escrow: 'Released',
      penaltyUserId: buyerId,
      penaltyPoints: skipPenalty ? 0 : penaltyPoints,
    };
  }

  listPendingWithdrawals(status?: string) {
    return this.walletService.listWithdrawalsForAdmin(status);
  }

  async approveWithdrawal(withdrawalId: number, note?: string) {
    const result = await this.walletService.approveWithdrawal(
      withdrawalId,
      note,
    );
    const userId = Number(result.userId);
    if (userId) {
      await this.notify(userId, {
        title: 'Yêu cầu rút tiền đã được duyệt',
        body: `Lệnh rút ${result.amountFormatted as string} đã được duyệt và chuyển khoản.`,
        payload: { action: 'WITHDRAWAL_APPROVED', withdrawalId },
      });
    }
    return result;
  }

  async rejectWithdrawal(withdrawalId: number, note?: string) {
    const result = await this.walletService.rejectWithdrawal(
      withdrawalId,
      note,
    );
    const userId = Number(result.userId);
    if (userId) {
      await this.notify(userId, {
        title: 'Yêu cầu rút tiền bị từ chối',
        body: `Lệnh rút ${result.amountFormatted as string} bị từ chối. Tiền đã hoàn về ví.${
          note ? ` Lý do: ${note}` : ''
        }`,
        payload: { action: 'WITHDRAWAL_REJECTED', withdrawalId },
      });
    }
    return result;
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
