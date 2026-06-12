import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';
import { Product } from './product.entity';
import { Order } from './order.entity';
import { ChatMessage } from './chat-message.entity';

@Entity({ schema: 'Market', name: 'Chat_Threads' })
export class ChatThread {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'thread_id' })
  threadId: number;

  @Column({ name: 'buyer_id', type: 'bigint' })
  buyerId: number;

  @Column({ name: 'seller_id', type: 'bigint' })
  sellerId: number;

  @Column({ name: 'product_id', type: 'bigint', nullable: true })
  productId: number | null;

  @Column({ name: 'order_id', type: 'bigint', nullable: true })
  orderId: number | null;

  @CreateDateColumn({ name: 'created_at', type: 'datetime2' })
  createdAt: Date;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'buyer_id' })
  buyer?: User;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'seller_id' })
  seller?: User;

  @ManyToOne(() => Product)
  @JoinColumn({ name: 'product_id' })
  product?: Product;

  @ManyToOne(() => Order)
  @JoinColumn({ name: 'order_id' })
  order?: Order;

  @OneToMany(() => ChatMessage, (m) => m.thread)
  messages?: ChatMessage[];
}
