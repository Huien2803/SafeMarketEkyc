import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { User } from './user.entity';

@Entity({ schema: 'Identity', name: 'User_Follows' })
@Unique('UQ_UserFollows', ['followerId', 'followeeId'])
@Index('IX_UserFollows_Followee', ['followeeId'])
export class UserFollow {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'follow_id' })
  followId: number;

  @Column({ name: 'follower_id', type: 'bigint' })
  followerId: number;

  @Column({ name: 'followee_id', type: 'bigint' })
  followeeId: number;

  @CreateDateColumn({ name: 'created_at', type: 'datetime2' })
  createdAt: Date;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'follower_id' })
  follower?: User;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'followee_id' })
  followee?: User;
}
