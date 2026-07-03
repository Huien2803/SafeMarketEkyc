import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { Order } from '../entities/order.entity';
import { Payment } from '../entities/payment.entity';
import { Product } from '../entities/product.entity';
import { VnpayService } from './vnpay.service';

/** txnRef đang chờ callback VNPay (orderId → txnRef). */
interface PendingCheckout {
  orderId: number;
  buyerId: number;
  amount: number;
  txnRef: string;
}

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);
  private readonly pendingCheckouts = new Map<string, PendingCheckout>();

  constructor(
    @InjectRepository(Order) private readonly orderRepo: Repository<Order>,
    @InjectRepository(Payment) private readonly paymentRepo: Repository<Payment>,
    @InjectRepository(Product) private readonly productRepo: Repository<Product>,
    private readonly vnpay: VnpayService,
    private readonly config: ConfigService,
  ) {}

  /**
   * Tạo link thanh toán online — tiền vào escrow SafeMarket (Holding).
   * Chỉ buyer, đơn Pending, paymentMethod = ONLINE_ESCROW.
   */
  async createCheckout(
    orderId: number,
    buyerId: number,
    ipAddr: string,
  ): Promise<{
    paymentUrl: string | null;
    devMode: boolean;
    txnRef: string;
    message: string;
  }> {
    const order = await this.requireOnlineEscrowOrder(orderId, buyerId);
    const product = await this.productRepo.findOne({
      where: { productId: order.productId },
    });
    if (!product) throw new NotFoundException('Sản phẩm không tồn tại');

    const amount = Number(product.price);
    const orderInfo = `Thanh toan don #${orderId} - ${product.title}`.slice(
      0,
      200,
    );

    if (this.vnpay.isConfigured()) {
      const { paymentUrl, txnRef } = this.vnpay.createPaymentUrl({
        amount,
        orderId,
        orderInfo,
        ipAddr,
      });
      this.pendingCheckouts.set(txnRef, {
        orderId,
        buyerId,
        amount,
        txnRef,
      });
      return {
        paymentUrl,
        devMode: false,
        txnRef,
        message: 'Mở cổng VNPay để thanh toán. Tiền sẽ tạm giữ tại SafeMarket.',
      };
    }

    const isDev =
      this.config.get<string>('NODE_ENV', 'development') !== 'production';
    if (!isDev) {
      throw new BadRequestException(
        'Chưa cấu hình VNPay. Liên hệ quản trị viên.',
      );
    }

    const txnRef = `DEV-SM${orderId}-${Date.now()}`;
    this.pendingCheckouts.set(txnRef, {
      orderId,
      buyerId,
      amount,
      txnRef,
    });
    return {
      paymentUrl: null,
      devMode: true,
      txnRef,
      message:
        'Chế độ dev — dùng API simulate-pay hoặc nút "Thanh toán demo" trên app.',
    };
  }

  /** Dev: giả lập thanh toán thành công → escrow Holding. */
  async simulatePayment(orderId: number, buyerId: number) {
    const order = await this.requireOnlineEscrowOrder(orderId, buyerId);
    const product = await this.productRepo.findOne({
      where: { productId: order.productId },
    });
    if (!product) throw new NotFoundException('Sản phẩm không tồn tại');

    const txnRef = `DEV-SM${orderId}-${Date.now()}`;
    await this.captureEscrow(orderId, Number(product.price), txnRef);
    return {
      success: true,
      orderId,
      escrowStatus: 'Holding',
      message: 'Đã thanh toán demo — tiền đang tạm giữ tại SafeMarket.',
    };
  }

  async handleVnpayIpn(query: Record<string, string>) {
    const result = this.vnpay.verifyCallback(query);
    if (!result.valid) {
      return { RspCode: '97', Message: 'Invalid signature' };
    }

    const pending = this.pendingCheckouts.get(result.txnRef);
    const orderId = pending?.orderId ?? this.parseOrderIdFromTxnRef(result.txnRef);

    if (!orderId) {
      return { RspCode: '01', Message: 'Order not found' };
    }

    if (result.success) {
      await this.captureEscrow(orderId, result.amount, result.txnRef);
      this.pendingCheckouts.delete(result.txnRef);
      return { RspCode: '00', Message: 'Confirm Success' };
    }

    return { RspCode: '00', Message: 'Confirm Success' };
  }

  handleVnpayReturn(query: Record<string, string>): string {
    const result = this.vnpay.verifyCallback(query);
    const orderId =
      this.pendingCheckouts.get(result.txnRef)?.orderId ??
      this.parseOrderIdFromTxnRef(result.txnRef);

    if (result.success && orderId) {
      this.captureEscrow(orderId, result.amount, result.txnRef).catch((e) =>
        this.logger.error(`VNPay return capture failed: ${e.message}`),
      );
      this.pendingCheckouts.delete(result.txnRef);
      return this.renderReturnPage(
        true,
        'Thanh toán thành công! Tiền đang được SafeMarket tạm giữ. Quay lại app để theo dõi đơn hàng.',
        orderId,
      );
    }

    return this.renderReturnPage(
      false,
      result.valid
        ? 'Thanh toán không thành công hoặc đã bị hủy.'
        : 'Xác thực chữ ký VNPay thất bại.',
      orderId,
    );
  }

  /** Ghi nhận tiền vào escrow và chuyển đơn sang Paid. */
  async captureEscrow(
    orderId: number,
    amount: number,
    txnRef: string,
  ): Promise<void> {
    const order = await this.orderRepo.findOne({ where: { orderId } });
    if (!order) throw new NotFoundException('Đơn hàng không tồn tại');
    if (order.paymentMethod !== 'ONLINE_ESCROW') return;
    if (order.orderStatus !== 'Pending') return;

    let payment = await this.paymentRepo.findOne({ where: { orderId } });
    if (payment) {
      payment.amount = amount;
      payment.paymentMethod = 'ONLINE_ESCROW';
      payment.escrowStatus = 'Holding';
      payment.transactionRef = txnRef;
    } else {
      payment = this.paymentRepo.create({
        orderId,
        amount,
        paymentMethod: 'ONLINE_ESCROW',
        escrowStatus: 'Holding',
        transactionRef: txnRef,
      });
    }
    await this.paymentRepo.save(payment);

    order.orderStatus = 'Paid';
    await this.orderRepo.save(order);
    this.logger.log(`Escrow Holding: order #${orderId}, ref ${txnRef}`);
  }

  async releaseEscrow(orderId: number): Promise<void> {
    const payment = await this.paymentRepo.findOne({ where: { orderId } });
    if (payment && payment.escrowStatus === 'Holding') {
      payment.escrowStatus = 'Released';
      await this.paymentRepo.save(payment);
      this.logger.log(`Escrow Released: order #${orderId}`);
    }
  }

  async refundEscrow(orderId: number): Promise<void> {
    const payment = await this.paymentRepo.findOne({ where: { orderId } });
    if (payment && payment.escrowStatus === 'Holding') {
      payment.escrowStatus = 'Refunded';
      await this.paymentRepo.save(payment);
      this.logger.log(`Escrow Refunded: order #${orderId}`);
    }
  }

  private async requireOnlineEscrowOrder(
    orderId: number,
    buyerId: number,
  ): Promise<Order> {
    const order = await this.orderRepo.findOne({ where: { orderId } });
    if (!order) throw new NotFoundException('Đơn hàng không tồn tại');
    if (Number(order.buyerId) !== buyerId) {
      throw new ForbiddenException('Chỉ người mua mới thanh toán đơn này');
    }
    if (order.paymentMethod !== 'ONLINE_ESCROW') {
      throw new BadRequestException('Đơn không dùng thanh toán online escrow');
    }
    if (order.orderStatus !== 'Pending') {
      throw new BadRequestException('Đơn đã thanh toán hoặc không còn chờ thanh toán');
    }
    return order;
  }

  private parseOrderIdFromTxnRef(txnRef: string): number | null {
    const m = /^SM(\d+)/.exec(txnRef);
    if (m) return parseInt(m[1], 10);
    const dev = /^DEV-SM(\d+)/.exec(txnRef);
    if (dev) return parseInt(dev[1], 10);
    return null;
  }

  private renderReturnPage(
    success: boolean,
    message: string,
    orderId: number | null,
  ): string {
    const color = success ? '#16a34a' : '#dc2626';
    return `<!DOCTYPE html><html lang="vi"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>SafeMarket — Thanh toán</title></head>
<body style="font-family:system-ui,sans-serif;max-width:480px;margin:40px auto;padding:24px;text-align:center">
<h2 style="color:${color}">${success ? '✓ Thành công' : '✗ Thất bại'}</h2>
<p>${message}</p>
${orderId ? `<p>Mã đơn: <strong>#${orderId}</strong></p>` : ''}
<p style="color:#64748b;font-size:14px">Bạn có thể đóng trang này và quay lại ứng dụng SafeMarket.</p>
</body></html>`;
  }
}
