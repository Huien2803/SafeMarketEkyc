import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Order } from './order.entity';

export type EscrowStatus = 'Holding' | 'Released' | 'Refunded';

@Entity({ schema: 'Finance', name: 'Payments' })
export class Payment {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'payment_id' })
  paymentId: number;

  @Column({ name: 'amount', type: 'bigint' })
  amount: number;

  @Column({ name: 'payment_method', type: 'varchar', length: 50 })
  paymentMethod: string;

  @Column({ name: 'escrow_status', type: 'varchar', length: 20, default: 'Holding' })
  escrowStatus: EscrowStatus;

  @Column({ name: 'transaction_ref', type: 'varchar', length: 100 })
  transactionRef: string;

  @Column({ name: 'order_id', type: 'bigint', unique: true })
  orderId: number;

  @CreateDateColumn({ name: 'paid_at', type: 'datetime2' })
  paidAt: Date;

  @OneToOne(() => Order)
  @JoinColumn({ name: 'order_id' })
  order?: Order;
}
