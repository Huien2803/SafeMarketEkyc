import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';
import { Product } from './product.entity';

@Entity({ schema: 'Moderation', name: 'Reports' })
export class Report {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'report_id' })
  reportId: number;

  @Column({ name: 'reporter_id', type: 'bigint' })
  reporterId: number;

  @Column({ name: 'reported_id', type: 'bigint' })
  reportedId: number;

  @Column({ name: 'product_id', type: 'bigint', nullable: true })
  productId: number | null;

  @Column({ name: 'reason', type: 'nvarchar', length: 500 })
  reason: string;

  @Column({ name: 'severity', type: 'varchar', length: 20, default: 'medium' })
  severity: string;

  @Column({ name: 'status', type: 'varchar', length: 20, default: 'Open' })
  status: string;

  @CreateDateColumn({ name: 'created_at', type: 'datetime2' })
  createdAt: Date;

  @Column({ name: 'resolved_at', type: 'datetime2', nullable: true })
  resolvedAt: Date | null;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'reporter_id' })
  reporter?: User;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'reported_id' })
  reported?: User;

  @ManyToOne(() => Product)
  @JoinColumn({ name: 'product_id' })
  product?: Product;
}
