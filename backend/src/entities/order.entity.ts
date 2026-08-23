import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';
import { Product } from './product.entity';
import { Payment } from './payment.entity';

export type OrderStatus =
  | 'Pending'
  | 'Paid'
  | 'Shipped'
  | 'Completed'
  | 'Cancelled'
  | 'Disputed';

@Entity({ schema: 'Finance', name: 'Orders' })
@Index('IX_Orders_Buyer', ['buyerId'])
export class Order {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'order_id' })
  orderId: number;

  @Column({ name: 'order_status', type: 'varchar', length: 30, default: 'Pending' })
  orderStatus: OrderStatus;

  @Column({ name: 'shipping_address', type: 'nvarchar', length: 500 })
  shippingAddress: string;

  @Column({ name: 'payment_method', type: 'varchar', length: 50, default: 'BANK_TRANSFER' })
  paymentMethod: string;

  @Column({ name: 'delivery_method', type: 'varchar', length: 50, default: 'SHIP' })
  deliveryMethod: string;

  @Column({ name: 'dispute_type', type: 'varchar', length: 50, nullable: true })
  disputeType: string | null;

  @Column({ name: 'dispute_note', type: 'nvarchar', length: 500, nullable: true })
  disputeNote: string | null;

  @Column({ name: 'cancel_reason', type: 'nvarchar', length: 255, nullable: true })
  cancelReason: string | null;

  @Column({ name: 'receipt_proof_url', type: 'varchar', length: 500, nullable: true })
  receiptProofUrl: string | null;

  @Column({ name: 'received_at', type: 'datetime2', nullable: true })
  receivedAt: Date | null;

  /** Thời điểm người bán xác nhận đã giao — mốc tính hạn khiếu nại (3 ngày). */
  @Column({ name: 'shipped_at', type: 'datetime2', nullable: true })
  shippedAt: Date | null;

  @Column({ name: 'buyer_id', type: 'bigint' })
  buyerId: number;

  @Column({ name: 'product_id', type: 'bigint', unique: true })
  productId: number;

  @CreateDateColumn({ name: 'created_at', type: 'datetime2' })
  createdAt: Date;

  @Column({ name: 'completed_at', type: 'datetime2', nullable: true })
  completedAt: Date | null;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'buyer_id' })
  buyer?: User;

  @ManyToOne(() => Product)
  @JoinColumn({ name: 'product_id' })
  product?: Product;

  @OneToOne(() => Payment, (p) => p.order)
  payment?: Payment;
}
