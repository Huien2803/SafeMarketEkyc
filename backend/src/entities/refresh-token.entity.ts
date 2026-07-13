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

@Entity({ schema: 'Identity', name: 'RefreshTokens' })
@Index('IX_RefreshTokens_user_id', ['userId'])
@Index('IX_RefreshTokens_expires_at', ['expiresAt'])
export class RefreshToken {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'token_id' })
  tokenId: number;

  @Column({ name: 'user_id', type: 'bigint' })
  userId: number;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  /** SHA-256 hex của refresh token plaintext. */
  @Column({ name: 'token_hash', type: 'varchar', length: 64, unique: true })
  tokenHash: string;

  @Column({ name: 'expires_at', type: 'datetime2' })
  expiresAt: Date;

  @Column({ name: 'revoked_at', type: 'datetime2', nullable: true })
  revokedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'datetime2' })
  createdAt: Date;

  /** token_id của refresh mới sau khi rotate. */
  @Column({ name: 'replaced_by', type: 'bigint', nullable: true })
  replacedBy: number | null;
}
