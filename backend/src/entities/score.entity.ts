import {
  Column,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from './user.entity';

export type RankLevel = 'Bronze' | 'Silver' | 'Gold' | 'Diamond';

@Entity({ schema: 'Reputation', name: 'Scores' })
export class Score {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'score_id' })
  scoreId: number;

  @Column({ name: 'current_point', type: 'int', default: 500 })
  currentPoint: number;

  @Column({
    name: 'rank_level',
    type: 'nvarchar',
    length: 20,
    default: 'Silver',
  })
  rankLevel: RankLevel;

  @UpdateDateColumn({ name: 'updated_at', type: 'datetime2' })
  updatedAt: Date;

  @Column({ name: 'user_id', type: 'bigint' })
  userId: number;

  @OneToOne(() => User, (user) => user.score, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;
}
