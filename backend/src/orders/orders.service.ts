import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
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
  CreateOrderDto,
  DisputeOrderDto,
} from './dto/order.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';

@Injectable()
export class OrdersService {
  constructor(
    @InjectRepository(Order) private readonly orderRepo: Repository<Order>,
    @InjectRepository(Payment) private readonly paymentRepo: Repository<Payment>,
    @InjectRepository(Product) private readonly productRepo: Repository<Product>,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(Review) private readonly reviewRepo: Repository<Review>,
    private readonly notificationsService: NotificationsService,
    private readonly paymentsService: PaymentsService,
  ) {}

  async createOrder(buyerId: number, dto: CreateOrderDto): Promise<Record<string, unknown>> {
    const product = await this.productRepo.findOne({
      where: { productId: dto.productId },
      relations: ['seller'],
    });
    if (!product) throw new NotFoundException('Sản phẩm không tồn tại');
    if (product.status !== 'Available') {
      throw new BadRequestException('Sản phẩm không còn khả dụng');
    }
    if (Number(product.sellerId) === buyerId) {
      throw new BadRequestException('Bạn không thể mua sản phẩm của chính mình');
    }

    const existing = await this.orderRepo.findOne({
      where: { productId: dto.productId },
    });
    if (existing && existing.orderStatus !== 'Cancelled') {
      throw new ConflictException('Sản phẩm đã có đơn hàng');
    }

    const paymentMethod = dto.paymentMethod ?? 'BANK_TRANSFER';
    const deliveryMethod = dto.deliveryMethod ?? 'SHIP';

    let saved: Order;
    if (existing?.orderStatus === 'Cancelled') {
      // Một sản phẩm chỉ có 1 dòng Orders (UNIQUE product_id) — tái kích hoạt đơn đã hủy.
      existing.buyerId = buyerId;
      existing.shippingAddress = dto.shippingAddress;
      existing.paymentMethod = paymentMethod;
      existing.deliveryMethod = deliveryMethod;
      existing.orderStatus = 'Pending';
      existing.cancelReason = null;
      existing.disputeType = null;
      existing.disputeNote = null;
      existing.completedAt = null;
      saved = await this.orderRepo.save(existing);
    } else {
      const order = this.orderRepo.create({
        buyerId,
        productId: dto.productId,
        shippingAddress: dto.shippingAddress,
        paymentMethod,
        deliveryMethod,
        orderStatus: 'Pending',
      });
      saved = await this.orderRepo.save(order);
    }

    product.status = 'Reserved';
    await this.productRepo.save(product);

    if (paymentMethod === 'BANK_TRANSFER') {
      const payment = await this.paymentRepo.findOne({
        where: { orderId: saved.orderId },
      });
      if (payment) {
        payment.amount = product.price;
        payment.paymentMethod = paymentMethod;
        payment.escrowStatus = 'Holding';
        payment.transactionRef = `ESC-${saved.orderId}-${Date.now()}`;
        await this.paymentRepo.save(payment);
      } else {
        await this.paymentRepo.save({
          orderId: saved.orderId,
          amount: product.price,
          paymentMethod,
          escrowStatus: 'Holding',
          transactionRef: `ESC-${saved.orderId}-${Date.now()}`,
        });
      }
    }
    // ONLINE_ESCROW: thanh toán qua VNPay → tạo payment khi capture thành công

    return this.toOrderJson(saved.orderId);
  }

  async getOrder(orderId: number, userId: number): Promise<Record<string, unknown>> {
    await this.requireParticipant(orderId, userId);
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
    const order = await this.requireParticipant(orderId, userId);
    if (order.deliveryMethod !== 'DIRECT') {
      throw new BadRequestException('Chỉ áp dụng cho giao trực tiếp');
    }
    if (order.paymentMethod === 'ONLINE_ESCROW') {
      if (order.orderStatus !== 'Paid') {
        throw new BadRequestException(
          'Chờ người mua thanh toán online trước khi xác nhận giao hàng',
        );
      }
      return this.toOrderJson(orderId);
    }
    if (order.orderStatus !== 'Pending') {
      throw new BadRequestException('Không thể xác nhận giao');
    }
    order.orderStatus = 'Paid';
    await this.orderRepo.save(order);
    return this.toOrderJson(orderId);
  }

  async complete(orderId: number, userId: number, proofUrl?: string | null) {
    const order = await this.requireParticipant(orderId, userId);
    if (!['Paid', 'Shipped'].includes(order.orderStatus)) {
      throw new BadRequestException('Đơn chưa sẵn sàng hoàn tất');
    }

    const isBuyer = Number(order.buyerId) === userId;
    if (isBuyer && !proofUrl) {
      throw new BadRequestException(
        'Vui lòng chụp ảnh xác nhận đã nhận hàng trước khi hoàn tất',
      );
    }

    order.orderStatus = 'Completed';
    order.completedAt = new Date();
    if (proofUrl) {
      order.receiptProofUrl = proofUrl;
      order.receivedAt = new Date();
    }
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
      if (isBuyer) {
        const buyer = await this.userRepo.findOne({
          where: { userId: order.buyerId },
        });
        const buyerName =
          buyer?.displayName ?? buyer?.email ?? 'Người mua';
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
    }

    const payment = await this.paymentRepo.findOne({ where: { orderId } });
    if (payment?.paymentMethod === 'ONLINE_ESCROW') {
      await this.paymentsService.releaseEscrow(orderId);
    } else if (payment) {
      payment.escrowStatus = 'Released';
      await this.paymentRepo.save(payment);
    }

    return this.toOrderJson(orderId);
  }

  async cancel(orderId: number, userId: number, dto: CancelOrderDto) {
    const order = await this.requireParticipant(orderId, userId);
    if (['Completed', 'Cancelled'].includes(order.orderStatus)) {
      throw new BadRequestException('Không thể hủy đơn này');
    }
    order.orderStatus = 'Cancelled';
    order.cancelReason = dto.reason ?? 'Hủy đơn';
    await this.orderRepo.save(order);

    const product = await this.productRepo.findOne({
      where: { productId: order.productId },
    });
    if (product && product.status !== 'Sold') {
      product.status = 'Available';
      await this.productRepo.save(product);
    }

    const payment = await this.paymentRepo.findOne({ where: { orderId } });
    if (payment?.paymentMethod === 'ONLINE_ESCROW') {
      await this.paymentsService.refundEscrow(orderId);
    } else if (payment) {
      payment.escrowStatus = 'Refunded';
      await this.paymentRepo.save(payment);
    }

    return this.toOrderJson(orderId);
  }

  async dispute(orderId: number, userId: number, dto: DisputeOrderDto) {
    const order = await this.requireParticipant(orderId, userId);
    if (['Completed', 'Cancelled', 'Disputed'].includes(order.orderStatus)) {
      throw new BadRequestException('Không thể khiếu nại đơn này');
    }
    order.orderStatus = 'Disputed';
    order.disputeType = dto.type;
    order.disputeNote = dto.note ?? '';
    await this.orderRepo.save(order);
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
