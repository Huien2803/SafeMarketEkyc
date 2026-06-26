import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';

export type NotificationType =
  | 'NEW_PRODUCT'
  | 'PRODUCT_SOLD'
  | 'ORDER_RECEIVED'
  | 'INFO';

@Entity({ schema: 'Market', name: 'Notifications' })
@Index('IX_Notifications_User', ['userId', 'createdAt'])
export class Notification {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'notification_id' })
  notificationId: number;

  @Column({ name: 'user_id', type: 'bigint' })
  userId: number;

  @Column({ name: 'type', type: 'varchar', length: 50 })
  type: NotificationType;

  @Column({ name: 'title', type: 'nvarchar', length: 200 })
  title: string;

  @Column({ name: 'body', type: 'nvarchar', length: 500 })
  body: string;

  @Column({ name: 'payload_json', type: 'nvarchar', length: 'MAX', nullable: true })
  payloadJson: string | null;

  @Column({ name: 'read_at', type: 'datetime2', nullable: true })
  readAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'datetime2' })
  createdAt: Date;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user?: User;
}
