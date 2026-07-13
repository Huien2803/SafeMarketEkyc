import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { Wallet } from '../entities/wallet.entity';
import { WalletTransaction } from '../entities/wallet-transaction.entity';
import { Withdrawal } from '../entities/withdrawal.entity';
import { User } from '../entities/user.entity';
import { formatVnd } from '../common/utils/format.util';
import { CreateWithdrawalDto } from './dto/withdraw.dto';

@Injectable()
export class WalletService {
  private readonly logger = new Logger(WalletService.name);

  constructor(
    @InjectRepository(Wallet)
    private readonly walletRepo: Repository<Wallet>,
    @InjectRepository(WalletTransaction)
    private readonly txnRepo: Repository<WalletTransaction>,
    @InjectRepository(Withdrawal)
    private readonly withdrawalRepo: Repository<Withdrawal>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly dataSource: DataSource,
  ) {}

  /** Lấy (hoặc tạo mới) ví của người dùng. */
  private async ensureWallet(userId: number): Promise<Wallet> {
    let wallet = await this.walletRepo.findOne({ where: { userId } });
    if (!wallet) {
      wallet = this.walletRepo.create({ userId, balance: 0 });
      wallet = await this.walletRepo.save(wallet);
    }
    return wallet;
  }

  /**
   * Cộng tiền vào ví người bán khi escrow được giải ngân (đơn hoàn tất).
   * Idempotent theo ref: nếu đã cộng cho ref này rồi thì bỏ qua.
   */
  async creditSale(
    userId: number,
    amount: number,
    ref: string,
    note?: string,
  ): Promise<void> {
    if (amount <= 0) return;
    const existed = await this.txnRepo.findOne({
      where: { userId, ref, type: 'CREDIT_SALE' },
    });
    if (existed) return;

    await this.dataSource.transaction(async (manager) => {
      const wallet =
        (await manager.findOne(Wallet, { where: { userId } })) ??
        manager.create(Wallet, { userId, balance: 0 });
      wallet.balance = Number(wallet.balance) + amount;
      await manager.save(wallet);
      await manager.save(
        manager.create(WalletTransaction, {
          userId,
          amount,
          type: 'CREDIT_SALE',
          ref,
          note: note ?? 'Giải ngân escrow đơn hàng',
        }),
      );
    });
    this.logger.log(`Wallet +${amount} cho user #${userId} (ref ${ref})`);
  }

  async getWallet(userId: number): Promise<Record<string, unknown>> {
    const wallet = await this.ensureWallet(userId);
    const txns = await this.txnRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 50,
    });
    const balance = Number(wallet.balance);
    return {
      balance,
      balanceFormatted: formatVnd(balance),
      transactions: txns.map((t) => this.toTxnJson(t)),
    };
  }

  async getWithdrawals(userId: number): Promise<Record<string, unknown>[]> {
    const rows = await this.withdrawalRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 50,
    });
    return rows.map((w) => this.toWithdrawalJson(w));
  }

  /** Admin: danh sách yêu cầu rút tiền (mặc định Pending). */
  async listWithdrawalsForAdmin(
    status?: string,
  ): Promise<Record<string, unknown>[]> {
    const where =
      status && ['Pending', 'Completed', 'Rejected'].includes(status)
        ? { status: status as Withdrawal['status'] }
        : { status: 'Pending' as const };

    const rows = await this.withdrawalRepo.find({
      where,
      order: { createdAt: 'ASC' },
      take: 100,
    });

    const result: Record<string, unknown>[] = [];
    for (const w of rows) {
      const user = await this.userRepo.findOne({
        where: { userId: w.userId },
      });
      result.push({
        ...this.toWithdrawalJson(w),
        userId: Number(w.userId),
        displayName: user?.displayName ?? user?.email ?? `User #${w.userId}`,
        email: user?.email ?? '',
      });
    }
    return result;
  }

  /**
   * Người bán yêu cầu rút tiền → Pending, tạm trừ số dư ví.
   * Admin duyệt = Completed; từ chối = hoàn tiền về ví.
   */
  async requestWithdrawal(
    userId: number,
    dto: CreateWithdrawalDto,
  ): Promise<Record<string, unknown>> {
    return this.dataSource.transaction(async (manager) => {
      const wallet =
        (await manager.findOne(Wallet, { where: { userId } })) ??
        manager.create(Wallet, { userId, balance: 0 });
      const balance = Number(wallet.balance);
      if (dto.amount > balance) {
        throw new BadRequestException(
          `Số dư không đủ. Số dư hiện tại: ${formatVnd(balance)}`,
        );
      }

      const pendingCount = await manager.count(Withdrawal, {
        where: { userId, status: 'Pending' },
      });
      if (pendingCount >= 3) {
        throw new BadRequestException(
          'Bạn đang có quá nhiều lệnh rút chờ duyệt. Vui lòng đợi xử lý.',
        );
      }

      wallet.balance = balance - dto.amount;
      await manager.save(wallet);

      const ref = `WD-${userId}-${Date.now()}`;
      const withdrawal = await manager.save(
        manager.create(Withdrawal, {
          userId,
          amount: dto.amount,
          bankName: dto.bankName,
          bankAccount: dto.bankAccount,
          accountHolder: dto.accountHolder,
          status: 'Pending',
          transactionRef: ref,
          adminNote: null,
          processedAt: null,
        }),
      );

      await manager.save(
        manager.create(WalletTransaction, {
          userId,
          amount: -dto.amount,
          type: 'DEBIT_WITHDRAW',
          ref,
          note: `Yêu cầu rút về ${dto.bankName} - ${dto.bankAccount} (chờ duyệt)`,
        }),
      );

      this.logger.log(`Withdrawal Pending ${ref}: -${dto.amount} user #${userId}`);
      return {
        ...this.toWithdrawalJson(withdrawal),
        newBalance: Number(wallet.balance),
        newBalanceFormatted: formatVnd(Number(wallet.balance)),
      };
    });
  }

  async approveWithdrawal(
    withdrawalId: number,
    adminNote?: string,
  ): Promise<Record<string, unknown>> {
    const w = await this.withdrawalRepo.findOne({ where: { withdrawalId } });
    if (!w) throw new NotFoundException('Lệnh rút tiền không tồn tại');
    if (w.status !== 'Pending') {
      throw new BadRequestException('Lệnh rút này đã được xử lý');
    }

    w.status = 'Completed';
    w.processedAt = new Date();
    w.adminNote = adminNote?.trim() || 'Đã chuyển khoản';
    await this.withdrawalRepo.save(w);
    this.logger.log(`Withdrawal Approved #${withdrawalId}`);
    return this.toWithdrawalJson(w);
  }

  async rejectWithdrawal(
    withdrawalId: number,
    adminNote?: string,
  ): Promise<Record<string, unknown>> {
    return this.dataSource.transaction(async (manager) => {
      const w = await manager.findOne(Withdrawal, {
        where: { withdrawalId },
      });
      if (!w) throw new NotFoundException('Lệnh rút tiền không tồn tại');
      if (w.status !== 'Pending') {
        throw new BadRequestException('Lệnh rút này đã được xử lý');
      }

      const userId = Number(w.userId);
      const amount = Number(w.amount);
      const wallet =
        (await manager.findOne(Wallet, { where: { userId } })) ??
        manager.create(Wallet, { userId, balance: 0 });
      wallet.balance = Number(wallet.balance) + amount;
      await manager.save(wallet);

      const ref = w.transactionRef ?? `WD-REJ-${withdrawalId}`;
      await manager.save(
        manager.create(WalletTransaction, {
          userId,
          amount,
          type: 'REFUND_WITHDRAW',
          ref: `${ref}-REFUND`,
          note: adminNote?.trim() || 'Hoàn tiền do từ chối rút',
        }),
      );

      w.status = 'Rejected';
      w.processedAt = new Date();
      w.adminNote = adminNote?.trim() || 'Từ chối rút tiền';
      await manager.save(w);

      this.logger.log(`Withdrawal Rejected #${withdrawalId}, refund ${amount}`);
      return this.toWithdrawalJson(w);
    });
  }

  private toTxnJson(t: WalletTransaction): Record<string, unknown> {
    const amount = Number(t.amount);
    return {
      txnId: Number(t.txnId),
      amount,
      amountFormatted: `${amount >= 0 ? '+' : '-'}${formatVnd(Math.abs(amount))}`,
      type: t.type,
      note: t.note,
      createdAt: t.createdAt.toISOString(),
    };
  }

  private toWithdrawalJson(w: Withdrawal): Record<string, unknown> {
    const amount = Number(w.amount);
    return {
      withdrawalId: Number(w.withdrawalId),
      userId: Number(w.userId),
      amount,
      amountFormatted: formatVnd(amount),
      bankName: w.bankName,
      bankAccount: w.bankAccount,
      accountHolder: w.accountHolder,
      status: w.status,
      transactionRef: w.transactionRef,
      adminNote: w.adminNote,
      createdAt: w.createdAt.toISOString(),
      processedAt: w.processedAt?.toISOString() ?? null,
    };
  }
}
