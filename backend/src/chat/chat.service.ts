import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ChatThread } from '../entities/chat-thread.entity';
import { ChatMessage } from '../entities/chat-message.entity';
import { User } from '../entities/user.entity';
import { Product } from '../entities/product.entity';
import { Score } from '../entities/score.entity';
import { OrdersService } from '../orders/orders.service';
import { formatVnd } from '../common/utils/format.util';

@Injectable()
export class ChatService {
  constructor(
    @InjectRepository(ChatThread) private readonly threadRepo: Repository<ChatThread>,
    @InjectRepository(ChatMessage) private readonly messageRepo: Repository<ChatMessage>,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(Product) private readonly productRepo: Repository<Product>,
    @InjectRepository(Score) private readonly scoreRepo: Repository<Score>,
    private readonly ordersService: OrdersService,
  ) {}

  async openThread(
    buyerId: number,
    sellerId: number,
    productId?: number,
    orderId?: number,
  ): Promise<{ threadId: number }> {
    if (buyerId === sellerId) {
      throw new BadRequestException('Không thể chat với chính mình');
    }

    const existing = await this.threadRepo.findOne({
      where: {
        buyerId,
        sellerId,
        productId: productId ?? undefined,
      },
    });
    if (existing) return { threadId: Number(existing.threadId) };

    const thread = await this.threadRepo.save({
      buyerId,
      sellerId,
      productId: productId ?? null,
      orderId: orderId ?? null,
    });
    return { threadId: Number(thread.threadId) };
  }

  async getThreads(userId: number): Promise<Record<string, unknown>[]> {
    const rows = await this.threadRepo.find({
      where: [{ buyerId: userId }, { sellerId: userId }],
      relations: ['buyer', 'seller', 'product'],
      order: { createdAt: 'DESC' },
    });

    const result: Record<string, unknown>[] = [];
    for (const t of rows) {
      const last = await this.messageRepo.findOne({
        where: { threadId: t.threadId },
        order: { createdAt: 'DESC' },
      });
      result.push({
        threadId: Number(t.threadId),
        buyerId: Number(t.buyerId),
        sellerId: Number(t.sellerId),
        sellerName: t.seller?.displayName ?? t.seller?.email ?? '',
        buyerName: t.buyer?.displayName ?? t.buyer?.email ?? '',
        productId: t.productId ? Number(t.productId) : null,
        productTitle: t.product?.title ?? null,
        orderId: t.orderId ? Number(t.orderId) : null,
        createdAt: t.createdAt.toISOString(),
        lastMessage: last?.body ?? null,
      });
    }
    return result;
  }

  async getThreadDetail(threadId: number, userId: number) {
    const t = await this.requireThread(threadId, userId);
    const product = t.productId
      ? await this.productRepo.findOne({ where: { productId: t.productId } })
      : null;

    let orderStatus: string | null = null;
    let paymentMethod: string | null = null;
    let deliveryMethod: string | null = null;
    if (t.orderId) {
      try {
        const order = await this.ordersService.getOrder(
          Number(t.orderId),
          userId,
        );
        orderStatus = (order.orderStatus as string) ?? null;
        paymentMethod = (order.paymentMethod as string) ?? null;
        deliveryMethod = (order.deliveryMethod as string) ?? null;
      } catch {
        // Đơn có thể đã bị xóa / không truy cập được — giữ null
      }
    }

    return {
      threadId: Number(t.threadId),
      buyerId: Number(t.buyerId),
      sellerId: Number(t.sellerId),
      sellerName: t.seller?.displayName ?? t.seller?.email ?? '',
      buyerName: t.buyer?.displayName ?? t.buyer?.email ?? '',
      productId: t.productId ? Number(t.productId) : null,
      productTitle: product?.title ?? null,
      productPrice: product ? Number(product.price) : null,
      productPriceFormatted: product ? formatVnd(Number(product.price)) : null,
      conditionPct: product?.conditionPct ?? null,
      productStatus: product?.status ?? null,
      productLocation: product?.location ?? null,
      thumbnailUrl: product?.thumbnailUrl ?? null,
      orderId: t.orderId ? Number(t.orderId) : null,
      orderStatus,
      paymentMethod,
      deliveryMethod,
      amBuyer: Number(t.buyerId) === userId,
      amSeller: Number(t.sellerId) === userId,
    };
  }

  async getMessages(threadId: number, userId: number) {
    await this.requireThread(threadId, userId);
    const rows = await this.messageRepo.find({
      where: { threadId },
      relations: ['sender'],
      order: { createdAt: 'ASC' },
    });
    return rows.map((m) => this.toMessageJson(m, userId));
  }

  async sendMessage(threadId: number, userId: number, body: string) {
    const thread = await this.requireThread(threadId, userId);
    const msg = await this.messageRepo.save({
      threadId,
      senderId: userId,
      body,
      messageType: 'TEXT',
    });

    let scamWarning: string | null = null;
    const counterpartyId =
      Number(thread.buyerId) === userId ? thread.sellerId : thread.buyerId;
    const score = await this.scoreRepo.findOne({
      where: { userId: Number(counterpartyId) },
    });
    if (score && score.currentPoint < 300) {
      scamWarning =
        'Cảnh báo: Người này có điểm tín nhiệm thấp. Hãy giao dịch qua escrow SafeMarket.';
    }

    const messages = await this.getMessages(threadId, userId);
    return { messages, scamWarning };
  }

  async purchaseRequest(
    threadId: number,
    buyerId: number,
    shippingAddress: string,
    paymentMethod = 'BANK_TRANSFER',
    deliveryMethod = 'SHIP',
  ) {
    const thread = await this.requireThread(threadId, buyerId);
    if (Number(thread.buyerId) !== buyerId) {
      throw new ForbiddenException('Chỉ người mua gửi yêu cầu mua');
    }
    if (!thread.productId) {
      throw new BadRequestException('Hội thoại không gắn sản phẩm');
    }

    const order = await this.ordersService.createOrder(buyerId, {
      productId: Number(thread.productId),
      shippingAddress,
      paymentMethod,
      deliveryMethod,
    });

    thread.orderId = order.orderId as number;
    await this.threadRepo.save(thread);

    await this.messageRepo.save({
      threadId,
      senderId: buyerId,
      body: 'Đã gửi yêu cầu mua hàng',
      messageType: 'PURCHASE_REQUEST',
      meta: JSON.stringify({ status: 'pending', orderId: order.orderId }),
    });

    return this.getMessages(threadId, buyerId);
  }

  async confirmSale(threadId: number, sellerId: number, messageId: number) {
    const thread = await this.requireThread(threadId, sellerId);
    if (Number(thread.sellerId) !== sellerId) {
      throw new ForbiddenException('Chỉ người bán xác nhận');
    }

    const msg = await this.messageRepo.findOne({ where: { messageId } });
    if (!msg || Number(msg.threadId) !== threadId) {
      throw new NotFoundException('Tin nhắn không tồn tại');
    }

    msg.meta = JSON.stringify({ status: 'confirmed' });
    msg.messageType = 'SALE_CONFIRMED';
    await this.messageRepo.save(msg);

    if (thread.orderId) {
      await this.ordersService.confirmSaleFromChat(
        Number(thread.orderId),
        sellerId,
      );
    }

    return this.getMessages(threadId, sellerId);
  }

  private async requireThread(threadId: number, userId: number): Promise<ChatThread> {
    const thread = await this.threadRepo.findOne({
      where: { threadId },
      relations: ['buyer', 'seller', 'product'],
    });
    if (!thread) throw new NotFoundException('Hội thoại không tồn tại');
    if (Number(thread.buyerId) !== userId && Number(thread.sellerId) !== userId) {
      throw new ForbiddenException('Bạn không thuộc hội thoại này');
    }
    return thread;
  }

  private toMessageJson(m: ChatMessage, viewerId: number): Record<string, unknown> {
    let meta: Record<string, unknown> | null = null;
    if (m.meta) {
      try {
        meta = JSON.parse(m.meta) as Record<string, unknown>;
      } catch {
        meta = null;
      }
    }
    return {
      messageId: Number(m.messageId),
      threadId: Number(m.threadId),
      senderId: Number(m.senderId),
      senderName: m.sender?.displayName ?? m.sender?.email ?? '',
      body: m.body,
      messageType: m.messageType,
      meta,
      createdAt: m.createdAt.toISOString(),
      mine: Number(m.senderId) === viewerId,
    };
  }
}
