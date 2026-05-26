import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';

@Entity({ schema: 'Reputation', name: 'Point_Logs' })
export class PointLog {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'log_id' })
  logId: number;

  @Column({ name: 'delta', type: 'int' })
  delta: number;

  @Column({ name: 'reason_code', type: 'varchar', length: 50 })
  reasonCode: string;

  @Column({ name: 'note', type: 'nvarchar', length: 255, nullable: true })
  note: string | null;

  @Column({ name: 'user_id', type: 'bigint' })
  userId: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @CreateDateColumn({ name: 'created_at', type: 'datetime2' })
  createdAt: Date;
}
