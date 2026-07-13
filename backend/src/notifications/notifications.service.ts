import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification, NotificationType } from '../entities/notification.entity';
import { Product } from '../entities/product.entity';
import { User } from '../entities/user.entity';
import { UserFollow } from '../entities/user-follow.entity';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(Notification)
    private readonly notifRepo: Repository<Notification>,
    @InjectRepository(UserFollow)
    private readonly followRepo: Repository<UserFollow>,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
  ) {}

  async listForUser(userId: number): Promise<Record<string, unknown>[]> {
    const rows = await this.notifRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 100,
    });
    return rows.map((n) => this.toJson(n));
  }

  async markRead(notificationId: number, userId: number): Promise<void> {
    const row = await this.notifRepo.findOne({
      where: { notificationId, userId },
    });
    if (!row || row.readAt) return;
    row.readAt = new Date();
    await this.notifRepo.save(row);
  }

  async markAllRead(userId: number): Promise<void> {
    await this.notifRepo
      .createQueryBuilder()
      .update(Notification)
      .set({ readAt: new Date() })
      .where('user_id = :userId AND read_at IS NULL', { userId })
      .execute();
  }

  async notifyNewProduct(sellerId: number, product: Product): Promise<void> {
    const seller = await this.userRepo.findOne({ where: { userId: sellerId } });
    const sellerName = seller?.displayName ?? seller?.email ?? 'Người bán';
    const followers = await this.followRepo.find({
      where: { followeeId: sellerId },
    });
    const price = Number(product.price);
    for (const f of followers) {
      const followerId = Number(f.followerId);
      if (followerId === sellerId) continue;
      await this.create(followerId, {
        type: 'NEW_PRODUCT',
        title: `${sellerName} vừa đăng tin mới`,
        body: product.title,
        payload: {
          productId: Number(product.productId),
          sellerId,
          sellerName,
          productTitle: product.title,
          price,
        },
      });
    }
  }

  async notifyProductSold(sellerId: number, product: Product): Promise<void> {
    const seller = await this.userRepo.findOne({ where: { userId: sellerId } });
    const sellerName = seller?.displayName ?? seller?.email ?? 'Người bán';
    const followers = await this.followRepo.find({
      where: { followeeId: sellerId },
    });
    for (const f of followers) {
      const followerId = Number(f.followerId);
      if (followerId === sellerId) continue;
      await this.create(followerId, {
        type: 'PRODUCT_SOLD',
        title: `${sellerName} vừa bán được hàng`,
        body: product.title,
        payload: {
          productId: Number(product.productId),
          sellerId,
          sellerName,
          productTitle: product.title,
        },
      });
    }
  }

  /** Báo cho người bán: người mua đã xác nhận nhận hàng (kèm ảnh bằng chứng). */
  async notifyOrderReceived(
    sellerId: number,
    data: {
      orderId: number;
      productId: number;
      productTitle: string;
      buyerName: string;
      proofUrl: string | null;
    },
  ): Promise<void> {
    await this.create(sellerId, {
      type: 'ORDER_RECEIVED',
      title: `${data.buyerName} đã xác nhận nhận hàng`,
      body: `Đơn "${data.productTitle}" đã được người mua xác nhận nhận hàng kèm ảnh.`,
      payload: {
        orderId: data.orderId,
        productId: data.productId,
        productTitle: data.productTitle,
        buyerName: data.buyerName,
        proofUrl: data.proofUrl,
      },
    });
  }

  /**
   * Thông báo cho user về một hành động kỷ luật từ admin
   * (cảnh cáo, trừ điểm, đình chỉ, khóa...). Kèm lý do trong payload.
   */
  async notifyAdminAction(
    userId: number,
    input: {
      title: string;
      body: string;
      payload?: Record<string, unknown>;
    },
  ): Promise<void> {
    await this.create(userId, {
      type: 'ADMIN_ACTION',
      title: input.title,
      body: input.body,
      payload: input.payload,
    });
  }

  private async create(
    userId: number,
    input: {
      type: NotificationType;
      title: string;
      body: string;
      payload?: Record<string, unknown>;
    },
  ): Promise<void> {
    await this.notifRepo.save({
      userId,
      type: input.type,
      title: input.title,
      body: input.body,
      payloadJson: input.payload ? JSON.stringify(input.payload) : null,
    });
  }

  private toJson(n: Notification): Record<string, unknown> {
    let payload: Record<string, unknown> | null = null;
    if (n.payloadJson) {
      try {
        payload = JSON.parse(n.payloadJson) as Record<string, unknown>;
      } catch {
        payload = null;
      }
    }
    return {
      id: Number(n.notificationId),
      type: n.type,
      title: n.title,
      body: n.body,
      payload,
      read: !!n.readAt,
      createdAt: n.createdAt.toISOString(),
    };
  }
}
