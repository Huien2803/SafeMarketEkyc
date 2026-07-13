import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  OneToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Score } from './score.entity';
import { EkycProfile } from './ekyc-profile.entity';

export type KycStatus = 'Unverified' | 'Pending' | 'Verified' | 'Rejected';
export type AccountStatus = 'Active' | 'Locked' | 'Banned' | 'Deleted';

@Entity({ schema: 'Identity', name: 'Users' })
@Index('IX_Users_KycStatus', ['kycStatus'])
@Index('IX_Users_AccountStatus', ['accountStatus'])
export class User {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'user_id' })
  userId: number;

  @Column({ name: 'phone_number', type: 'varchar', length: 15, unique: true })
  phoneNumber: string;

  @Column({ name: 'email', type: 'varchar', length: 255, unique: true })
  email: string;

  @Column({ name: 'password_hash', type: 'varchar', length: 255 })
  passwordHash: string;

  @Column({ name: 'display_name', type: 'nvarchar', length: 100, nullable: true })
  displayName: string | null;

  @Column({ name: 'avatar_url', type: 'varchar', length: 500, nullable: true })
  avatarUrl: string | null;

  @Column({ name: 'location', type: 'nvarchar', length: 100, nullable: true })
  location: string | null;

  @Column({
    name: 'kyc_status',
    type: 'varchar',
    length: 30,
    default: 'Unverified',
  })
  kycStatus: KycStatus;

  @Column({
    name: 'account_status',
    type: 'varchar',
    length: 20,
    default: 'Active',
  })
  accountStatus: AccountStatus;

  @Column({ name: 'is_admin', type: 'bit', default: false })
  isAdmin: boolean;

  @Column({ name: 'locked_at', type: 'datetime2', nullable: true })
  lockedAt: Date | null;

  /** Thời điểm hết hạn đình chỉ tạm thời. NULL = khóa/cấm vô thời hạn. */
  @Column({ name: 'locked_until', type: 'datetime2', nullable: true })
  lockedUntil: Date | null;

  @Column({
    name: 'lock_reason',
    type: 'nvarchar',
    length: 255,
    nullable: true,
  })
  lockReason: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'datetime2' })
  createdAt: Date;

  @OneToOne(() => Score, (score) => score.user)
  score?: Score;

  @OneToOne(() => EkycProfile, (kyc) => kyc.user)
  ekycProfile?: EkycProfile;
}
