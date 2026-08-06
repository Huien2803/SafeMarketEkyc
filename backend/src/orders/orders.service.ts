import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, Repository } from 'typeorm';
import { Order } from '../entities/order.entity';
import { Payment } from '../entities/payment.entity';
import { Product } from '../entities/product.entity';
import { Review } from '../entities/review.entity';
import { User } from '../entities/user.entity';
import {
  DELIVERY_LABELS,
  formatVnd,
  PAYMENT_LABELS,
} from '../common/utils/format.util';
import {
  CancelOrderDto,
  ChangePaymentMethodDto,
  CreateOrderDto,
  DisputeOrderDto,
} from './dto/order.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import { WalletService } from '../wallet/wallet.service';
import { ReputationService } from '../reputation/reputation.service';

/** Điểm thưởng khi hoàn tất giao dịch thành công (mỗi bên). */
const COMPLETE_ORDER_BONUS = 20;

@Injectable()
export class OrdersService {
  constructor(
    @InjectRepository(Order) private readonly orderRepo: Repository<Order>,
    @InjectRepository(Payment) private readonly paymentRepo: Repository<Payment>,
    @InjectRepository(Product) private readonly productRepo: Repository<Product>,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(Review) private readonly reviewRepo: Repository<Review>,
    private readonly dataSource: DataSource,
    private readonly notificationsService: NotificationsService,
    private readonly paymentsService: PaymentsService,
    private readonly walletService: WalletService,
    private readonly reputationService: ReputationService,
  ) {}

  /**
   * Tạo đơn: mỗi sản phẩm chỉ 1 đơn đang hiệu lực.
   * Khóa dòng sản phẩm trong transaction để tránh 2 người đặt cùng lúc.
   */
  async createOrder(buyerId: number, dto: CreateOrderDto): Promise<Record<string, unknown>> {
    const buyer = await this.userRepo.findOne({ where: { userId: buyerId } });
    if (!buyer) {
      throw new NotFoundException('Người dùng không tồn tại');
    }
    if (buyer.isAdmin) {
      throw new ForbiddenException(
        'Tài khoản quản trị không được mua sản phẩm. Hãy dùng tài khoản người mua thường.',
      );
    }
    if (buyer.kycStatus !== 'Verified') {
      throw new ForbiddenException(
        'Bạn cần xác thực danh tính (eKYC) trước khi mua hàng',
      );
    }

    const paymentMethod = dto.paymentMethod ?? 'BANK_TRANSFER';
    const deliveryMethod = dto.deliveryMethod ?? 'SHIP';

    const savedOrderId = await this.dataSource.transaction(async (manager) => {
      const product = await manager.findOne(Product, {
        where: { productId: dto.productId },
        relations: ['seller'],
        lock: { mode: 'pessimistic_write' },
      });
      if (!product) throw new NotFoundException('Sản phẩm không tồn tại');
      if (Number(product.sellerId) === buyerId) {
        throw new BadRequestException('Bạn không thể mua sản phẩm của chính mình');
      }
      if (product.status === 'Sold') {
        throw new BadRequestException('Sản phẩm đã được bán');
      }
      if (product.status === 'Hidden') {
        throw new BadRequestException('Sản phẩm không còn khả dụng');
      }
      if (product.status === 'Reserved') {
        throw new ConflictException(
          'Sản phẩm đã có người đặt hàng. Bạn không thể đặt lại.',
        );
      }
      if (product.status !== 'Available') {
        throw new BadRequestException('Sản phẩm không còn khả dụng');
      }

      const existing = await manager.findOne(Order, {
        where: { productId: dto.productId },
        lock: { mode: 'pessimistic_write' },
      });
      if (existing && existing.orderStatus !== 'Cancelled') {
        // Đồng bộ trạng thái nếu order còn mà product vẫn Available (dữ liệu lệch).
        if (product.status === 'Available') {
          product.status = 'Reserved';
          await manager.save(product);
        }
        throw new ConflictException(
          'Sản phẩm đã có người đặt hàng. Bạn không thể đặt lại.',
        );
      }

      let saved: Order;
      if (existing?.orderStatus === 'Cancelled') {
        // UNIQUE(product_id): tái dùng dòng đơn đã hủy khi sản phẩm Available lại.
        existing.buyerId = buyerId;
        existing.shippingAddress = dto.shippingAddress;
        existing.paymentMethod = paymentMethod;
        existing.deliveryMethod = deliveryMethod;
        existing.orderStatus = 'Pending';
        existing.cancelReason = null;
        existing.disputeType = null;
        existing.disputeNote = null;
        existing.completedAt = null;
        saved = await manager.save(existing);
      } else {
        saved = await manager.save(
          manager.create(Order, {
            buyerId,
            productId: dto.productId,
            shippingAddress: dto.shippingAddress,
            paymentMethod,
            deliveryMethod,
            orderStatus: 'Pending',
          }),
        );
      }

      // Chỉ Reserved khi vẫn còn Available (chặn race với người khác).
      const reserved = await manager.update(
        Product,
        { productId: dto.productId, status: 'Available' },
        { status: 'Reserved' },
      );
      if (!reserved.affected) {
        throw new ConflictException(
          'Sản phẩm đã có người đặt hàng. Bạn không thể đặt lại.',
        );
      }

      if (paymentMethod === 'BANK_TRANSFER') {
        const payment = await manager.findOne(Payment, {
          where: { orderId: saved.orderId },
        });
        if (payment) {
          payment.amount = product.price;
          payment.paymentMethod = paymentMethod;
          payment.escrowStatus = 'Holding';
          payment.transactionRef = `ESC-${saved.orderId}-${Date.now()}`;
          await manager.save(payment);
        } else {
          await manager.save(
            manager.create(Payment, {
              orderId: saved.orderId,
              amount: product.price,
              paymentMethod,
              escrowStatus: 'Holding',
              transactionRef: `ESC-${saved.orderId}-${Date.now()}`,
            }),
          );
        }
      }

      return saved.orderId;
    });

    return this.toOrderJson(savedOrderId);
  }

  async getOrder(orderId: number, userId: number): Promise<Record<string, unknown>> {
    await this.requireParticipant(orderId, userId);
    return this.toOrderJson(orderId);
  }

  /**
   * Người mua đổi phương thức thanh toán / giao hàng khi đơn còn Pending
   * (chưa thanh toán, chưa giao). Reset lại bản ghi thanh toán tạm nếu có.
   */
  async changePaymentMethod(
    orderId: number,
    userId: number,
    dto: ChangePaymentMethodDto,
  ): Promise<Record<string, unknown>> {
    const order = await this.requireParticipant(orderId, userId);
    if (Number(order.buyerId) !== userId) {
      throw new ForbiddenException('Chỉ người mua mới đổi phương thức thanh toán');
    }
    if (order.orderStatus !== 'Pending') {
      throw new BadRequestException(
        'Chỉ đổi được khi đơn chưa thanh toán / chưa giao',
      );
    }

    const newPay = dto.paymentMethod ?? order.paymentMethod;
    const newDel = dto.deliveryMethod ?? order.deliveryMethod;
    order.paymentMethod = newPay;
    order.deliveryMethod = newDel;
    if (dto.shippingAddress && dto.shippingAddress.trim()) {
      order.shippingAddress = dto.shippingAddress.trim();
    }
    await this.orderRepo.save(order);

    // Đơn còn Pending nghĩa là chưa có tiền thực nào được ghi nhận → xoá bản
    // ghi thanh toán tạm (nếu có) và tạo lại theo phương thức mới.
    const existingPayment = await this.paymentRepo.findOne({
      where: { orderId },
    });
    if (existingPayment) {
      await this.paymentRepo.remove(existingPayment);
    }
    if (newPay === 'BANK_TRANSFER') {
      const product = await this.productRepo.findOne({
        where: { productId: order.productId },
      });
      if (product) {
        await this.paymentRepo.save({
          orderId,
          amount: product.price,
          paymentMethod: newPay,
          escrowStatus: 'Holding',
          transactionRef: `ESC-${orderId}-${Date.now()}`,
        });
      }
    }

    return this.toOrderJson(orderId);
  }

  async getMyOrders(userId: number): Promise<Record<string, unknown>[]> {
    const asBuyer = await this.orderRepo.find({
      where: { buyerId: userId },
      select: ['orderId'],
    });
    const asSeller = await this.orderRepo
      .createQueryBuilder('o')
      .innerJoin('o.product', 'p')
      .where('p.seller_id = :userId', { userId })
      .select('o.order_id', 'orderId')
      .getRawMany<{ orderId: string }>();

    const ids = [
      ...new Set([
        ...asBuyer.map((o) => Number(o.orderId)),
        ...asSeller.map((r) => Number(r.orderId)),
      ]),
    ];
    if (ids.length === 0) return [];

    const rows = await this.orderRepo.find({
      where: { orderId: In(ids) },
      order: { createdAt: 'DESC' },
    });
    return Promise.all(rows.map((o) => this.toOrderJson(Number(o.orderId))));
  }

  async getSoldProducts(sellerId: number): Promise<Record<string, unknown>[]> {
    const products = await this.productRepo.find({
      where: { sellerId },
      order: { productId: 'DESC' },
    });

    const result: Record<string, unknown>[] = [];
    for (const p of products) {
      const order = await this.orderRepo.findOne({
        where: { productId: p.productId },
        relations: ['buyer'],
      });
      const price = Number(p.price);
      result.push({
        productId: Number(p.productId),
        title: p.title,
        price,
        priceFormatted: formatVnd(price),
        productStatus: p.status,
        thumbnailUrl: p.thumbnailUrl,
        conditionPct: p.conditionPct,
        orderId: order ? Number(order.orderId) : null,
        orderStatus: order?.orderStatus ?? null,
        buyerName: order?.buyer?.displayName ?? order?.buyer?.email ?? null,
        hasBuyer: !!order && order.orderStatus !== 'Cancelled',
      });
    }
    return result;
  }

  async markShipped(orderId: number, userId: number) {
    const order = await this.requireSeller(orderId, userId);
    if (order.deliveryMethod !== 'SHIP') {
      throw new BadRequestException('Đơn giao trực tiếp không có bước ship');
    }
    if (order.orderStatus !== 'Paid') {
      throw new BadRequestException('Chỉ ship khi đơn đã thanh toán');
    }
    order.orderStatus = 'Shipped';
    await this.orderRepo.save(order);
    return this.toOrderJson(orderId);
  }

  /**
   * Người bán xác nhận bán từ chat:
   * - DIRECT → confirmHandover (Shipped) — sau đó buyer mới được nhận hàng
   * - BANK_TRANSFER + SHIP → confirmPayment (Paid)
   * - ONLINE_ESCROW: chỉ khi đã Paid (buyer đã thanh toán escrow)
   */
  async confirmSaleFromChat(orderId: number, sellerId: number) {
    const order = await this.requireSeller(orderId, sellerId);
    if (order.paymentMethod === 'ONLINE_ESCROW') {
      if (order.orderStatus === 'Pending') {
        throw new BadRequestException(
          'Chờ người mua thanh toán online (escrow) trước khi xác nhận bán.',
        );
      }
      if (order.deliveryMethod === 'DIRECT') {
        return this.confirmHandover(orderId, sellerId);
      }
      // SHIP: đã Paid — chờ ship riêng; bước chat chỉ đánh dấu đã xác nhận.
      return this.toOrderJson(orderId);
    }
    if (order.deliveryMethod === 'DIRECT') {
      return this.confirmHandover(orderId, sellerId);
    }
    return this.confirmPayment(orderId, sellerId);
  }

  async confirmPayment(orderId: number, userId: number) {
    const order = await this.requireSeller(orderId, userId);
    if (!['Pending', 'Paid'].includes(order.orderStatus)) {
      throw new BadRequestException('Không thể xác nhận thanh toán');
    }
    order.orderStatus = 'Paid';
    await this.orderRepo.save(order);
    return this.toOrderJson(orderId);
  }

  async confirmHandover(orderId: number, userId: number) {
    // Chỉ người bán được xác nhận đã giao — tránh người mua tự nhảy bước.
    const order = await this.requireSeller(orderId, userId);
    if (order.deliveryMethod !== 'DIRECT') {
      throw new BadRequestException('Chỉ áp dụng cho giao trực tiếp');
    }
    if (order.paymentMethod === 'ONLINE_ESCROW') {
      if (order.orderStatus !== 'Paid') {
        throw new BadRequestException(
          'Chờ người mua thanh toán online trước khi xác nhận giao hàng',
        );
      }
      order.orderStatus = 'Shipped';
      await this.orderRepo.save(order);
      return this.toOrderJson(orderId);
    }
    if (order.orderStatus !== 'Pending') {
      throw new BadRequestException('Không thể xác nhận giao');
    }
    // Tiền mặt + gặp trực tiếp: người bán xác nhận đã giao & nhận tiền
    // → Shipped (chờ người mua chụp ảnh xác nhận nhận hàng).
    order.orderStatus = 'Shipped';
    await this.orderRepo.save(order);
    return this.toOrderJson(orderId);
  }

  async complete(orderId: number, userId: number, proofUrl?: string | null) {
    const order = await this.requireParticipant(orderId, userId);
    const isBuyer = Number(order.buyerId) === userId;
    if (!isBuyer) {
      throw new ForbiddenException(
        'Chỉ người mua được xác nhận đã nhận hàng',
      );
    }
    if (!proofUrl || !String(proofUrl).trim()) {
      throw new BadRequestException(
        'Bắt buộc có ảnh xác nhận đã nhận hàng — đây là bước bắt buộc khi nhận hàng',
      );
    }

    // Bắt buộc người bán đã xác nhận giao (Shipped).
    // Paid + CASH + DIRECT: đơn cũ (handover từng ghi Paid).
    const sellerDelivered =
      order.orderStatus === 'Shipped' ||
      (order.orderStatus === 'Paid' &&
        order.deliveryMethod === 'DIRECT' &&
        order.paymentMethod === 'CASH');
    if (!sellerDelivered) {
      throw new BadRequestException(
        'Chờ người bán xác nhận đã bán/giao hàng trước khi bạn xác nhận nhận hàng',
      );
    }

    order.orderStatus = 'Completed';
    order.completedAt = new Date();
    order.receiptProofUrl = proofUrl;
    order.receivedAt = new Date();
    await this.orderRepo.save(order);

    const product = await this.productRepo.findOne({
      where: { productId: order.productId },
    });
    if (product) {
      product.status = 'Sold';
      await this.productRepo.save(product);
      await this.notificationsService.notifyProductSold(
        Number(product.sellerId),
        product,
      );

      // Báo trực tiếp cho người bán: người mua đã xác nhận nhận hàng (kèm ảnh).
      const buyer = await this.userRepo.findOne({
        where: { userId: order.buyerId },
      });
      const buyerName = buyer?.displayName ?? buyer?.email ?? 'Người mua';
      await this.notificationsService.notifyOrderReceived(
        Number(product.sellerId),
        {
          orderId: Number(order.orderId),
          productId: Number(product.productId),
          productTitle: product.title,
          buyerName,
          proofUrl: proofUrl ?? null,
        },
      );
    }

    const payment = await this.paymentRepo.findOne({ where: { orderId } });
    if (payment?.paymentMethod === 'ONLINE_ESCROW') {
      await this.paymentsService.releaseEscrow(orderId);
      // Escrow giải ngân → cộng tiền vào ví người bán để rút về ngân hàng.
      if (product) {
        await this.walletService.creditSale(
          Number(product.sellerId),
          Number(payment.amount),
          `ORDER-${orderId}`,
          `Bán "${product.title}" (đơn #${orderId})`,
        );
      }
    } else if (payment) {
      payment.escrowStatus = 'Released';
      await this.paymentRepo.save(payment);
    }

    // Cộng điểm tín nhiệm cho cả hai bên khi giao dịch thành công.
    if (product) {
      const sellerId = Number(product.sellerId);
      const buyerId = Number(order.buyerId);
      const key = `ORDER-${orderId}`;
      await this.reputationService.adjustPoints(
        buyerId,
        COMPLETE_ORDER_BONUS,
        'ORDER_COMPLETE',
        `Hoàn tất đơn #${orderId} (người mua) [${key}]`,
        { idempotentKey: key },
      );
      await this.reputationService.adjustPoints(
        sellerId,
        COMPLETE_ORDER_BONUS,
        'ORDER_COMPLETE',
        `Hoàn tất đơn #${orderId} (người bán) [${key}]`,
        { idempotentKey: key },
      );
    }

    return this.toOrderJson(orderId);
  }

  async cancel(orderId: number, userId: number, dto: CancelOrderDto) {
    const order = await this.requireParticipant(orderId, userId);
    if (['Completed', 'Cancelled', 'Disputed'].includes(order.orderStatus)) {
      throw new BadRequestException(
        order.orderStatus === 'Disputed'
          ? 'Đơn đang khiếu nại — chờ quản trị viên xử lý, không tự hủy được'
          : 'Không thể hủy đơn này',
      );
    }

    const rawReason = (dto?.reason ?? 'Hủy đơn').trim() || 'Hủy đơn';
    order.orderStatus = 'Cancelled';
    order.cancelReason = rawReason.slice(0, 255);
    await this.orderRepo.save(order);

    const product = await this.productRepo.findOne({
      where: { productId: order.productId },
    });
    if (product && product.status !== 'Sold') {
      product.status = 'Available';
      await this.productRepo.save(product);
    }

    try {
      const payment = await this.paymentRepo.findOne({ where: { orderId } });
      if (payment?.paymentMethod === 'ONLINE_ESCROW') {
        await this.paymentsService.refundEscrow(orderId);
      } else if (payment) {
        payment.escrowStatus = 'Refunded';
        await this.paymentRepo.save(payment);
      }
    } catch (err) {
      // Đơn đã Cancelled — không fail cả request vì hoàn tiền/ghi payment lỗi.
      // eslint-disable-next-line no-console
      console.error(`Cancel order #${orderId} payment cleanup failed`, err);
    }

    return this.toOrderJson(orderId);
  }

  async dispute(orderId: number, userId: number, dto: DisputeOrderDto) {
    const order = await this.requireParticipant(orderId, userId);
    if (['Completed', 'Cancelled', 'Disputed'].includes(order.orderStatus)) {
      throw new BadRequestException('Không thể khiếu nại đơn này');
    }
    if (!['Paid', 'Shipped'].includes(order.orderStatus)) {
      throw new BadRequestException(
        'Chỉ khiếu nại khi đơn đã thanh toán / đang giao',
      );
    }
    order.orderStatus = 'Disputed';
    order.disputeType = dto.type;
    order.disputeNote = dto.note ?? '';
    await this.orderRepo.save(order);

    const product = await this.productRepo.findOne({
      where: { productId: order.productId },
    });
    const sellerId = product ? Number(product.sellerId) : null;
    const buyerId = Number(order.buyerId);
    const otherId = userId === buyerId ? sellerId : buyerId;
    const opener =
      (await this.userRepo.findOne({ where: { userId } }))?.displayName ??
      'Đối phương';
    if (otherId) {
      try {
        await this.notificationsService.notifyAdminAction(otherId, {
          title: 'Đơn hàng bị khiếu nại',
          body: `${opener} đã mở khiếu nại cho đơn #${orderId}. Quản trị viên sẽ xem xét.`,
          payload: {
            action: 'DISPUTE_OPENED',
            orderId,
            type: dto.type,
          },
        });
      } catch {
        /* ignore */
      }
    }

    return this.toOrderJson(orderId);
  }

  private async requireParticipant(orderId: number, userId: number): Promise<Order> {
    const order = await this.orderRepo.findOne({
      where: { orderId },
      relations: ['product'],
    });
    if (!order) throw new NotFoundException('Đơn hàng không tồn tại');
    const sellerId = Number(order.product?.sellerId);
    if (Number(order.buyerId) !== userId && sellerId !== userId) {
      throw new ForbiddenException('Bạn không thuộc đơn hàng này');
    }
    return order;
  }

  private async requireSeller(orderId: number, userId: number): Promise<Order> {
    const order = await this.requireParticipant(orderId, userId);
    const sellerId = Number(order.product?.sellerId);
    if (sellerId !== userId) {
      throw new ForbiddenException('Chỉ người bán mới thực hiện được');
    }
    return order;
  }

  private async toOrderJson(orderId: number): Promise<Record<string, unknown>> {
    const order = await this.orderRepo.findOne({
      where: { orderId },
      relations: ['buyer', 'product', 'product.seller'],
    });
    if (!order) throw new NotFoundException('Đơn hàng không tồn tại');

    const product = order.product!;
    const seller = product.seller!;
    const payment = await this.paymentRepo.findOne({ where: { orderId } });
    const reviews = await this.reviewRepo.find({ where: { orderId } });

    const buyerReviewed = reviews.some((r) => Number(r.reviewerId) === Number(order.buyerId));
    const sellerReviewed = reviews.some((r) => Number(r.reviewerId) === Number(seller.userId));
    const price = Number(product.price);

    return {
      orderId: Number(order.orderId),
      orderStatus: order.orderStatus,
      shippingAddress: order.shippingAddress,
      paymentMethod: order.paymentMethod,
      deliveryMethod: order.deliveryMethod,
      paymentMethodLabel: PAYMENT_LABELS[order.paymentMethod] ?? order.paymentMethod,
      deliveryMethodLabel: DELIVERY_LABELS[order.deliveryMethod] ?? order.deliveryMethod,
      buyerId: Number(order.buyerId),
      buyerName: order.buyer?.displayName ?? order.buyer?.email ?? '',
      sellerId: Number(seller.userId),
      sellerName: seller.displayName ?? seller.email,
      productId: Number(product.productId),
      productTitle: product.title,
      productPrice: price,
      productPriceFormatted: formatVnd(price),
      disputeType: order.disputeType,
      disputeNote: order.disputeNote,
      createdAt: order.createdAt.toISOString(),
      completedAt: order.completedAt?.toISOString() ?? null,
      receiptProofUrl: order.receiptProofUrl ?? null,
      receivedAt: order.receivedAt?.toISOString() ?? null,
      escrowStatus: payment?.escrowStatus ?? null,
      escrowAmount: payment ? Number(payment.amount) : 0,
      buyerReviewed,
      sellerReviewed,
    };
  }
}
