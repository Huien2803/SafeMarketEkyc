import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { User } from './user.entity';
import { Order } from './order.entity';

@Entity({ schema: 'Reputation', name: 'Reviews' })
@Unique('UQ_Reviews_Order_Reviewer', ['orderId', 'reviewerId'])
export class Review {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'review_id' })
  reviewId: number;

  @Column({ name: 'rating', type: 'tinyint' })
  rating: number;

  @Column({ name: 'comment', type: 'nvarchar', length: 'MAX', nullable: true })
  comment: string | null;

  @Column({ name: 'order_id', type: 'bigint' })
  orderId: number;

  @Column({ name: 'reviewer_id', type: 'bigint' })
  reviewerId: number;

  @Column({ name: 'reviewee_id', type: 'bigint' })
  revieweeId: number;

  @CreateDateColumn({ name: 'created_at', type: 'datetime2' })
  createdAt: Date;

  @ManyToOne(() => Order)
  @JoinColumn({ name: 'order_id' })
  order?: Order;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'reviewer_id' })
  reviewer?: User;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'reviewee_id' })
  reviewee?: User;
}
